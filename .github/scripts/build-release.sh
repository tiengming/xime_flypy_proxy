#!/usr/bin/env bash
set -euo pipefail

GLOBAL_TAG="${RELEASE_TAG:-manual-build-$(date +%s)}"
GLOBAL_VERSION="${GLOBAL_TAG#v}"

# ── 资源打包辅助（分支含 themes/ 或 fonts/ 时，按索引 LAYOUT_SPEC 打根级 zip） ──

has_resources() {  # $1=branch：分支是否携带 themes/ 或 fonts/ 资源
  git ls-tree -r --name-only "origin/$1" 2>/dev/null | grep -qE '^(themes|fonts)/'
}

build_zip() {  # $1=branch $2=zip 输出文件名：根级 xime.custom.yaml + themes/ + fonts/ + 文档
  local branch="$1" out="$2" f doc out_abs
  out_abs=$(realpath -m "$out")
  rm -f "$out_abs"   # zip 对已存在的包是合并更新，先删保证干净重建
  rm -rf _zip_stage && mkdir -p _zip_stage
  git show "origin/$branch:xime.custom.yaml" > "_zip_stage/xime.custom.yaml"
  for f in $(git ls-tree -r --name-only "origin/$branch" | grep -E '^(themes|fonts)/'); do
    mkdir -p "_zip_stage/$(dirname "$f")"
    git show "origin/$branch:$f" > "_zip_stage/$f"
  done
  for doc in NOTICE.md README.md; do
    git show "origin/$branch:$doc" > "_zip_stage/$doc" 2>/dev/null || rm -f "_zip_stage/$doc"
  done
  (cd _zip_stage && zip -q -r -X "$out_abs" .)
  rm -rf _zip_stage
}

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
    "xime_theme_pack") module_desc="xime 主题包（配色+字体+背景图）"; tag_prefix="xime_theme_pack" ;;
    *)               module_desc="扩展模块 ($branch)"; tag_prefix="xime_flypy_proxy-${safe_branch}" ;;
  esac

  branch_tag="${tag_prefix}-${branch_version}"
  out_filename="xime.custom.yaml"
  zip_filename="${safe_branch}.zip"
  has_res=false
  has_resources "$branch" && has_res=true || true

  echo "正在处理 [$module_desc] | 分支: $branch | 版本: $branch_version | tag: $branch_tag | 资源zip: $has_res"

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
        size_bytes="${asset_line##|*}"
        sha256_val="${sha256_full#sha256:}"
        size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")
      else
        sha256_val="N/A"; size_human="N/A"
      fi
      echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` | ⏭️ 跳过（无变化） |" >> "$SUMMARY_FILE"
      # 资源 zip：附件已存在则记录 digest；缺失则本地重建补传（yaml 未变但 zip 逻辑后补的场景）
      if [ "$has_res" = true ]; then
        zip_line=$(gh release view "$branch_tag" --json assets \
          -q ".assets[] | select(.name==\"$zip_filename\") | \"\\(.digest)|\\(.size)\"" 2>/dev/null || echo "")
        if [ -n "$zip_line" ]; then
          zsha_full="${zip_line%%|*}"; zsize_bytes="${zip_line##|*}"
          echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`$zip_filename\` | \`${zsha_full#sha256:}\` | \`$(numfmt --to=iec --suffix=B "$zsize_bytes" 2>/dev/null || echo "${zsize_bytes} B")\` | ⏭️ 跳过（无变化） |" >> "$SUMMARY_FILE"
        else
          build_zip "$branch" "$zip_filename"
          zsha_val=$(openssl sha256 "$zip_filename" | awk '{print $2}')
          zsize_bytes=$(stat -c %s "$zip_filename" 2>/dev/null || stat -f %z "$zip_filename")
          gh release upload "$branch_tag" "$zip_filename" --clobber
          echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`$zip_filename\` | \`$zsha_val\` | \`$(numfmt --to=iec --suffix=B "$zsize_bytes" 2>/dev/null || echo "${zsize_bytes} B")\` | 🔧 补传 zip |" >> "$SUMMARY_FILE"
          rm -f "$zip_filename"
        fi
      fi
    else
      # tag 存在但 Release 被删 → 重建 Release，不重打 tag
      echo "  ⚠️ Release 不存在但 tag 存在，重建 Release。"
      if git show "origin/$branch:xime.custom.yaml" > "$out_filename" 2>/dev/null; then
        sha256_val=$(openssl sha256 "$out_filename" | awk '{print $2}')
        size_bytes=$(stat -c %s "$out_filename" 2>/dev/null || stat -f %z "$out_filename")
        size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")
        release_assets=("$out_filename")
        if [ "$has_res" = true ] && build_zip "$branch" "$zip_filename"; then
          release_assets+=("$zip_filename")
        fi
        gh release create "$branch_tag" \
          --title "$module_desc $branch_version" \
          --notes "自动发布：$module_desc（分支 $branch）" \
          --latest=false \
          "${release_assets[@]}" 2>/dev/null || \
        gh release create "$branch_tag" \
          --title "$module_desc $branch_version" \
          --notes "自动发布：$module_desc（分支 $branch）" \
          "${release_assets[@]}"
        echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` | 🔧 重建 Release |" >> "$SUMMARY_FILE"
        if [ "$has_res" = true ] && [ -f "$zip_filename" ]; then
          zsha_val=$(openssl sha256 "$zip_filename" | awk '{print $2}')
          zsize_bytes=$(stat -c %s "$zip_filename" 2>/dev/null || stat -f %z "$zip_filename")
          echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`$zip_filename\` | \`$zsha_val\` | \`$(numfmt --to=iec --suffix=B "$zsize_bytes" 2>/dev/null || echo "${zsize_bytes} B")\` | 🔧 重建 Release |" >> "$SUMMARY_FILE"
        fi
        rm -f "${release_assets[@]}"
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

  release_assets=("$out_filename")
  if [ "$has_res" = true ] && build_zip "$branch" "$zip_filename"; then
    echo "  已打包资源 zip: $zip_filename"
    release_assets+=("$zip_filename")
  fi

  echo "  为 $branch ($branch_commit) 创建 tag: $branch_tag"
  git tag -a "$branch_tag" "$branch_commit" -m "Release $branch_tag for $module_desc"
  git push origin "refs/tags/$branch_tag"

  if gh release view "$branch_tag" >/dev/null 2>&1; then
    echo "  Release 已存在，覆盖资产。"
    gh release upload "$branch_tag" "${release_assets[@]}" --clobber
  else
    echo "  创建 Release: $branch_tag"
    gh release create "$branch_tag" \
      --title "$module_desc $branch_version" \
      --notes "自动发布：$module_desc（分支 $branch）" \
      --latest=false \
      "${release_assets[@]}" 2>/dev/null || \
    gh release create "$branch_tag" \
      --title "$module_desc $branch_version" \
      --notes "自动发布：$module_desc（分支 $branch）" \
      "${release_assets[@]}"
  fi

  echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` | ✅ 新发布 |" >> "$SUMMARY_FILE"
  if [ "$has_res" = true ] && [ -f "$zip_filename" ]; then
    zsha_val=$(openssl sha256 "$zip_filename" | awk '{print $2}')
    zsize_bytes=$(stat -c %s "$zip_filename" 2>/dev/null || stat -f %z "$zip_filename")
    echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`$zip_filename\` | \`$zsha_val\` | \`$(numfmt --to=iec --suffix=B "$zsize_bytes" 2>/dev/null || echo "${zsize_bytes} B")\` | ✅ 新发布 |" >> "$SUMMARY_FILE"
  fi
  rm -f "${release_assets[@]}"

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
