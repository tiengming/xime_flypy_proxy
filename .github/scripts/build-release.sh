#!/usr/bin/env bash
set -euo pipefail

GLOBAL_TAG="${RELEASE_TAG:-manual-build-$(date +%s)}"
GLOBAL_VERSION="${GLOBAL_TAG#v}"

branches=$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin/ | grep -v '^HEAD$' || true)

if [ -z "$branches" ]; then
  echo "No remote branches found. Exiting."
  exit 1
fi

echo "检测到以下远程分支："
echo "$branches"
echo "----------------------------------------"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

SUMMARY_FILE="release_summary.md"
{
  echo ""
  echo "触发构建的全局发布版：\`$GLOBAL_TAG\`"
  echo ""
  echo "| 模块 / 分支说明 | 分支 tag | 文件名 | SHA256 校验码 | 大小 | 状态 |"
  echo "| :--- | :--- | :--- | :--- | :--- | :--- |"
} > "$SUMMARY_FILE"

for branch in $branches; do
  safe_branch=$(echo "$branch" | tr '/' '_')

  # 优先使用分支内 VERSION 文件
  branch_version_raw=$(git show "origin/$branch:VERSION" 2>/dev/null | tr -d '[:space:]' || true)
  branch_version="${branch_version_raw#v}"
  if [ -z "$branch_version" ]; then
    branch_version="$GLOBAL_VERSION"
    echo "⚠️ 分支 $branch 没有 VERSION 文件，使用全局版本 $branch_version"
  fi

  case "$branch" in
    "main"|"master") module_desc="小鹤双拼多功能配置"; tag_prefix="xime_flypy_proxy" ;;
    "ximenet")       module_desc="扩展商店资源加速"; tag_prefix="xime_index_net" ;;
    "xime_theme")    module_desc="xime 多主题"; tag_prefix="xime_theme" ;;
    *)               module_desc="扩展模块 ($branch)"; tag_prefix="xime_flypy_proxy-${safe_branch}" ;;
  esac

  branch_tag="${tag_prefix}-${branch_version}"
  out_filename="xime.custom.yaml"

  echo "正在处理 [$module_desc] | 分支: $branch | 版本: $branch_version | tag: $branch_tag"

  branch_commit=$(git rev-parse "origin/$branch")

  # 检查 tag 是否已存在
  tag_exists=false
  tag_commit=""
  if git ls-remote --tags origin "refs/tags/$branch_tag" 2>/dev/null | grep -q "refs/tags/$branch_tag$"; then
    tag_exists=true
    tag_commit=$(git rev-list -n 1 "$branch_tag" 2>/dev/null || echo "")
  fi

  # 场景 1：tag 存在且 commit 相同 → 跳过打包
  if [ "$tag_exists" = true ] && [ "$tag_commit" = "$branch_commit" ]; then
    echo "  ⏭️ tag 已存在且 commit 相同，内容无变化。"
    if gh release view "$branch_tag" >/dev/null 2>&1; then
      asset_line=$(gh release view "$branch_tag" --json assets \
        -q '.assets[] | select(.name=="xime.custom.yaml") | "\(.digest)|\(.size)"' 2>/dev/null || echo "")
      if [ -n "$asset_line" ]; then
        sha256_full="${asset_line%%|*}"
        size_bytes="${asset_line##*|}"
        sha256_val="${sha256_full#sha256:}"
        size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")
      else
        sha256_val="N/A"; size_human="N/A"
      fi
      echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` | ⏭️ 跳过（无变化） |" >> "$SUMMARY_FILE"
    else
      # tag 存在但 Release 被删 → 重建 Release，不重打 tag
      echo "  ⚠️ Release 不存在但 tag 存在，重建 Release。"
      if git show "origin/$branch:xime.custom.yaml" > "$out_filename" 2>/dev/null; then
        sha256_val=$(openssl sha256 "$out_filename" | awk '{print $2}')
        size_bytes=$(stat -c %s "$out_filename" 2>/dev/null || stat -f %z "$out_filename")
        size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")
        gh release create "$branch_tag" \
          --title "$module_desc $branch_version" \
          --notes "自动发布：$module_desc（分支 $branch）" \
          --latest=false \
          "$out_filename" 2>/dev/null || \
        gh release create "$branch_tag" \
          --title "$module_desc $branch_version" \
          --notes "自动发布：$module_desc（分支 $branch）" \
          "$out_filename"
        rm -f "$out_filename"
        echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` | 🔧 重建 Release |" >> "$SUMMARY_FILE"
      else
        echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | - | - | - | ❌ 缺 xime.custom.yaml |" >> "$SUMMARY_FILE"
      fi
    fi
    continue
  fi

  # 场景 2：tag 存在但 commit 不同 → 版本未递增，跳过
  if [ "$tag_exists" = true ] && [ "$tag_commit" != "$branch_commit" ]; then
    echo "  ⚠️ tag $branch_tag 已存在但指向 commit $tag_commit（分支最新为 $branch_commit）。"
    echo "     分支有改动但 VERSION 未递增（仍为 $branch_version）。"
    echo "     请更新分支内 VERSION 文件后再发布。"
    echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | - | - | - | ⚠️ 版本未递增，跳过 |" >> "$SUMMARY_FILE"
    continue
  fi

  # 场景 3：tag 不存在 → 正常发布
  if ! git show "origin/$branch:xime.custom.yaml" > "$out_filename" 2>/dev/null; then
    echo "  ❌ 分支 $branch 中没有 xime.custom.yaml，跳过。"
    echo "| **$module_desc**<br>(\`$branch\`) | - | - | - | - | ❌ 缺 xime.custom.yaml |" >> "$SUMMARY_FILE"
    rm -f "$out_filename"
    continue
  fi

  sha256_val=$(openssl sha256 "$out_filename" | awk '{print $2}')
  size_bytes=$(stat -c %s "$out_filename" 2>/dev/null || stat -f %z "$out_filename")
  size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")

  echo "  为 $branch ($branch_commit) 创建 tag: $branch_tag"
  git tag -a "$branch_tag" "$branch_commit" -m "Release $branch_tag for $module_desc"
  git push origin "refs/tags/$branch_tag"

  if gh release view "$branch_tag" >/dev/null 2>&1; then
    echo "  Release 已存在，覆盖资产。"
    gh release upload "$branch_tag" "$out_filename" --clobber
  else
    echo "  创建 Release: $branch_tag"
    gh release create "$branch_tag" \
      --title "$module_desc $branch_version" \
      --notes "自动发布：$module_desc（分支 $branch）" \
      --latest=false \
      "$out_filename" 2>/dev/null || \
    gh release create "$branch_tag" \
      --title "$module_desc $branch_version" \
      --notes "自动发布：$module_desc（分支 $branch）" \
      "$out_filename"
  fi

  rm -f "$out_filename"

  echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` | ✅ 新发布 |" >> "$SUMMARY_FILE"
done

echo "----------------------------------------"

# 更新主 Release 说明，标记包裹避免重复追加
current_body=$(gh release view "$GLOBAL_TAG" --json body -q .body 2>/dev/null || echo "")

cleaned_body=$(echo "$current_body" | awk '
  /<!-- AUTO_SUMMARY_START -->/ { skip=1; next }
  /<!-- AUTO_SUMMARY_END -->/ { skip=0; next }
  !skip { print }
')

new_body=$(printf "%s\n\n<!-- AUTO_SUMMARY_START -->\n%s\n<!-- AUTO_SUMMARY_END -->\n" "$cleaned_body" "$(cat "$SUMMARY_FILE")")
gh release edit "$GLOBAL_TAG" --notes "$new_body"

echo "Release 页面更新成功！"