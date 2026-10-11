#!/usr/bin/env bash
set -euo pipefail

GLOBAL_TAG="${RELEASE_TAG:-manual-build-$(date +%s)}"
VERSION_TAG="${GLOBAL_TAG}"

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
cat > "$SUMMARY_FILE" << EOF
### 📦 各功能模块与独立版本校验

触发构建的全局发布版：\`$GLOBAL_TAG\`

| 模块 / 分支说明 | 分支 tag | 文件名 | SHA256 校验码 | 大小 |
| :--- | :--- | :--- | :--- | :--- |
EOF

for branch in $branches; do
  safe_branch=$(echo "$branch" | tr '/' '_')

  branch_version=$(git show "origin/$branch:VERSION" 2>/dev/null | tr -d '[:space:]' || true)
  [ -z "$branch_version" ] && branch_version="$GLOBAL_TAG"

  case "$branch" in
    "main"|"master")
      module_desc="小鹤双拼多功能配置"
      tag_prefix="xime_flypy_proxy"
      ;;
    "ximenet")
      module_desc="扩展商店资源加速"
      tag_prefix="xime_index_net"
      ;;
    *)
      module_desc="扩展模块 ($branch)"
      tag_prefix="xime_flypy_proxy-${safe_branch}"
      ;;
  esac

  branch_tag="${tag_prefix}-${VERSION_TAG}"
  out_filename="xime.custom.yaml"

  echo "正在处理 [$module_desc] | 分支: $branch | 版本: $branch_version | tag: $branch_tag"

  # 提取 xime.custom.yaml
  if ! git show "origin/$branch:xime.custom.yaml" > "$out_filename" 2>/dev/null; then
    echo "警告：分支 $branch 中没有 xime.custom.yaml，跳过。"
    rm -f "$out_filename"
    continue
  fi

  sha256_val=$(openssl sha256 "$out_filename" | awk '{print $2}')
  size_bytes=$(stat -c %s "$out_filename" 2>/dev/null || stat -f %z "$out_filename")
  size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")

  # 打分支 tag
  branch_commit=$(git rev-parse "origin/$branch")
  if git ls-remote --tags origin "$branch_tag" | grep -q "$branch_tag"; then
    echo "  tag $branch_tag 已存在，跳过打 tag。"
  else
    echo "  为 $branch ($branch_commit) 创建 tag: $branch_tag"
    git tag -a "$branch_tag" "$branch_commit" -m "Release $branch_tag for $module_desc"
    git push origin "refs/tags/$branch_tag"
  fi

  # 创建或更新分支 Release
  if gh release view "$branch_tag" >/dev/null 2>&1; then
    echo "  Release $branch_tag 已存在，覆盖资产。"
    gh release upload "$branch_tag" "$out_filename" --clobber
  else
    echo "  创建 Release: $branch_tag"
    gh release create "$branch_tag" \
      --title "$module_desc $branch_version" \
      --notes "自动发布：$module_desc（分支 $branch）" \
      -latest=false \
      "$out_filename"
  fi

  rm -f "$out_filename"

  echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`xime.custom.yaml\` | \`$sha256_val\` | \`$size_human\` |" >> "$SUMMARY_FILE"
done

echo "----------------------------------------"

# 更新主 Release 的说明（保留汇总表）
current_body=$(gh release view "$GLOBAL_TAG" --json body -q .body 2>/dev/null || echo "")
new_body=$(printf "%s\n\n%s" "$current_body" "$(cat "$SUMMARY_FILE")")
gh release edit "$GLOBAL_TAG" --notes "$new_body"

echo "Release 页面更新成功！"