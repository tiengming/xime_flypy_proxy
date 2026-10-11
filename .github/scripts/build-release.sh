#!/usr/bin/env bash
set -euo pipefail

GLOBAL_TAG="${RELEASE_TAG:-manual-build-$(date +%s)}"

# 获取所有远程分支（去掉 origin/ 前缀，排除 HEAD）
branches=$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin/ | grep -v '^HEAD$' || true)

if [ -z "$branches" ]; then
  echo "No remote branches found. Exiting."
  exit 1
fi

echo "检测到以下远程分支："
echo "$branches"
echo "----------------------------------------"

SUMMARY_FILE="release_summary.md"
cat > "$SUMMARY_FILE" << EOF
### 📦 各功能模块与独立版本校验

触发构建的全局发布版：\`$GLOBAL_TAG\`

| 模块 / 分支说明 | 独立版本号 | 文件名 | MD5 校验码 | SHA256 校验码 |
| :--- | :--- | :--- | :--- | :--- |
EOF

upload_files=()

for branch in $branches; do
  safe_branch=$(echo "$branch" | tr '/' '_')

  # 尝试读取分支的 VERSION 文件，没有就用全局 tag
  branch_version=$(git show "origin/$branch:VERSION" 2>/dev/null | tr -d '[:space:]' || true)
  [ -z "$branch_version" ] && branch_version="$GLOBAL_TAG"

  case "$branch" in
    "main"|"master")
      module_desc="小鹤双拼多功能配置"
      file_prefix="xime_flypy_proxy-core"
      ;;
    "ximenet")
      module_desc="扩展商店资源加速"
      file_prefix="xime_flypy_proxy-ximenet"
      ;;
    *)
      module_desc="扩展模块 ($branch)"
      file_prefix="xime_flypy_proxy-${safe_branch}"
      ;;
  esac

  filename="${file_prefix}-${branch_version}.zip"

  echo "正在打包 [$module_desc] | 分支: $branch | 版本: $branch_version -> $filename"

  git archive --format=zip "origin/$branch" -o "$filename"

  md5_val=$(openssl md5 "$filename" | awk '{print $2}')
  sha256_val=$(openssl sha256 "$filename" | awk '{print $2}')

  echo "$md5_val" > "${filename}.md5"
  echo "$sha256_val" > "${filename}.sha256"

  upload_files+=("$filename" "${filename}.md5" "${filename}.sha256")

  echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_version\` | \`$filename\` | \`$md5_val\` | \`$sha256_val\` |" >> "$SUMMARY_FILE"
done

echo "----------------------------------------"
echo "本次将上传以下文件："
printf '  %s\n' "${upload_files[@]}"

echo "正在上传资产到 Release: $GLOBAL_TAG"
gh release upload "$GLOBAL_TAG" "${upload_files[@]}" --clobber

current_body=$(gh release view "$GLOBAL_TAG" --json body -q .body 2>/dev/null || echo "")
new_body=$(printf "%s\n\n%s" "$current_body" "$(cat "$SUMMARY_FILE")")
gh release edit "$GLOBAL_TAG" --notes "$new_body"

echo "Release 页面更新成功！"