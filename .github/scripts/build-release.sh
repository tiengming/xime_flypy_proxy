#!/usr/bin/env bash
set -euo pipefail

GLOBAL_TAG="${RELEASE_TAG:-manual-build-$(date +%s)}"

# 从 GLOBAL_TAG 中提取版本号，例如 v1.0.0 -> v1.0.0
VERSION_TAG="${GLOBAL_TAG}"

# 获取所有远程分支（去掉 origin/ 前缀，排除 HEAD）
branches=$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin/ | grep -v '^HEAD$' || true)

if [ -z "$branches" ]; then
  echo "No remote branches found. Exiting."
  exit 1
fi

echo "检测到以下远程分支："
echo "$branches"
echo "----------------------------------------"

# 配置 git 用户（打 tag 需要）
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

SUMMARY_FILE="release_summary.md"
cat > "$SUMMARY_FILE" << EOF
### 📦 各功能模块与独立版本校验

触发构建的全局发布版：\`$GLOBAL_TAG\`

| 模块 / 分支说明 | 分支 tag | 文件名 | SHA256 校验码 | 大小 |
| :--- | :--- | :--- | :--- | :--- |
EOF

upload_files=()

for branch in $branches; do
  safe_branch=$(echo "$branch" | tr '/' '_')

  # 尝试读取分支的 VERSION 文件，没有就用全局 tag
  branch_version=$(git show "origin/$branch:VERSION" 2>/dev/null | tr -d '[:space:]' || true)
  [ -z "$branch_version" ] && branch_version="$GLOBAL_TAG"

  # 根据分支确定模块描述、输出文件名、tag 前缀
  case "$branch" in
    "main"|"master")
      module_desc="小鹤双拼多功能配置"
      out_filename="xime_flypy_proxy.custom.yaml"
      tag_prefix="xime_flypy_proxy"
      ;;
    "ximenet")
      module_desc="扩展商店资源加速"
      out_filename="xime_index_net.custom.yaml"
      tag_prefix="xime_index_net"
      ;;
    *)
      module_desc="扩展模块 ($branch)"
      out_filename="xime_flypy_proxy-${safe_branch}.custom.yaml"
      tag_prefix="xime_flypy_proxy-${safe_branch}"
      ;;
  esac

  # 分支 tag 名：<前缀>-<版本>
  branch_tag="${tag_prefix}-${VERSION_TAG}"

  echo "正在处理 [$module_desc] | 分支: $branch | 版本: $branch_version | tag: $branch_tag"

  # 提取 xime.custom.yaml
  if ! git show "origin/$branch:xime.custom.yaml" > "$out_filename" 2>/dev/null; then
    echo "警告：分支 $branch 中没有 xime.custom.yaml，跳过。"
    rm -f "$out_filename"
    continue
  fi

  # 计算 sha256 和文件大小
  sha256_val=$(openssl sha256 "$out_filename" | awk '{print $2}')
  size_bytes=$(stat -c %s "$out_filename" 2>/dev/null || stat -f %z "$out_filename")
  size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes} B")

  # 为分支最新 commit 打 tag（如果已存在则跳过）
  branch_commit=$(git rev-parse "origin/$branch")
  if git ls-remote --tags origin "$branch_tag" | grep -q "$branch_tag"; then
    echo "  tag $branch_tag 已存在，跳过打 tag。"
  else
    echo "  为 $branch ($branch_commit) 创建 tag: $branch_tag"
    git tag -a "$branch_tag" "$branch_commit" -m "Release $branch_tag for $module_desc"
    git push origin "refs/tags/$branch_tag"
  fi

  upload_files+=("$out_filename")

  echo "| **$module_desc**<br>(\`$branch\`) | \`$branch_tag\` | \`$out_filename\` | \`$sha256_val\` | \`$size_human\` |" >> "$SUMMARY_FILE"
done

echo "----------------------------------------"
echo "本次将上传以下文件："
printf '  %s\n' "${upload_files[@]}"

if [ ${#upload_files[@]} -eq 0 ]; then
  echo "没有可上传的文件，退出。"
  exit 0
fi

echo "正在上传资产到 Release: $GLOBAL_TAG"
gh release upload "$GLOBAL_TAG" "${upload_files[@]}" --clobber

current_body=$(gh release view "$GLOBAL_TAG" --json body -q .body 2>/dev/null || echo "")
new_body=$(printf "%s\n\n%s" "$current_body" "$(cat "$SUMMARY_FILE")")
gh release edit "$GLOBAL_TAG" --notes "$new_body"

echo "Release 页面更新成功！"