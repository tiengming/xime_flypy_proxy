#!/usr/bin/env python3
"""生成 xime-index 版本条目（sha256 / size 实测填写，不依赖 CI 补全）

xime-index 的 `src/**/<id>.yaml` 里记录的 `sha256` 是「可信指纹」：
`scripts/ci-update.py` 只用它校验远端文件，**不会**把 `src/` 里的空值补上；
留空 = 无法校验（`--check` 会告警），填错 = 被当成「上游内容被替换」而整版不进索引。
所以提 PR 前必须用**真实产物**算好 sha256 与 size。

三种取数方式：

1. 发布后从 Release 资产取（推荐，GitHub 已算好 digest）：
       python tools/index_entry.py --tag xime_theme_pack-1.2.0 --asset xime_theme_pack.zip \
           --version 1.2.0 --changelog "修复……"
2. 已从 Release 页面读到 digest（离线/无网）：
       python tools/index_entry.py --tag ... --asset ... --version 1.2.0 \
           --changelog "……" --sha256 <64位> --size "20.2 MB"
3. 本地文件预演（zip 内含 mtime，本地重打的 sha 与 CI 产物可能不同，不要直接上架）：
       python tools/index_entry.py --file .\\xime_theme_pack.zip --tag ... --asset ... ...

只依赖 Python 标准库。国际网络请先设 HTTPS_PROXY/HTTP_PROXY。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date
from urllib.parse import urlsplit

DEFAULT_REPO = "tiengming/xime_flypy_proxy"
USER_AGENT = "xime-index-entry/1.0"
COMMIT_SHA = re.compile(r"^[0-9a-f]{40}$", re.IGNORECASE)
ANY_SHA256 = re.compile(r"^[0-9a-f]{64}$", re.IGNORECASE)


def human_size(size: int) -> str:
    """与 xime-index scripts/lib.py 的 human_size 保持一致。"""
    if size < 1024:
        return f"{size} B"
    if size < 1024 * 1024:
        return f"{size / 1024:.1f} KB"
    if size < 1024 ** 3:
        return f"{size / (1024 * 1024):.1f} MB"
    return f"{size / (1024 ** 3):.2f} GB"


def _get(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read(), response.geturl()


def sha256_of_file(path: str) -> tuple[str, int]:
    digest = hashlib.sha256()
    total = 0
    with open(path, "rb") as handle:
        while True:
            chunk = handle.read(1 << 20)
            if not chunk:
                break
            digest.update(chunk)
            total += len(chunk)
    return digest.hexdigest(), total


def from_release_asset(repo: str, tag: str, asset: str) -> tuple[str, int, str]:
    """读取 Release 资产的官方 digest/size；无 digest 字段时下载后本地计算。"""
    api = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
    try:
        payload, _ = _get(api)
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"读取 Release 失败（HTTP {exc.code}）：{api}\n"
                         f"确认 tag 已存在、仓库可访问（国际网络需代理）。") from exc
    release = json.loads(payload.decode("utf-8"))
    for item in release.get("assets", []):
        if item.get("name") != asset:
            continue
        url = item.get("browser_download_url", "")
        size = int(item.get("size") or 0)
        digest = (item.get("digest") or "").removeprefix("sha256:")
        if digest:
            return digest, size, url
        blob, _ = _get(url)
        return hashlib.sha256(blob).hexdigest(), len(blob), url
    names = ", ".join(a.get("name", "?") for a in release.get("assets", [])) or "（无资产）"
    raise SystemExit(f"Release {tag} 中找不到资产 {asset}；现有资产：{names}")


def check_immutable(url: str, allow_tag: bool) -> list[str]:
    """下载地址必须是不可变引用：Release 资产，或固定 commit 的 raw/jsDelivr。"""
    parts = urlsplit(url)
    host = (parts.hostname or "").lower()
    path = parts.path

    if "/releases/download/" in path:
        return []
    for marker in ("/tree/", "/blob/", "/refs/heads/"):
        if marker in path:
            return [f"URL 指向分支引用（含 {marker}）：内容会变，sha256 立即失效"]

    if host == "raw.githubusercontent.com":
        segments = [s for s in path.split("/") if s]
        if len(segments) < 4:
            return ["raw 地址格式应为 raw.githubusercontent.com/<owner>/<repo>/<ref>/<file>"]
        ref = segments[2]
    elif host in ("cdn.jsdelivr.net", "fastly.jsdelivr.net"):
        segments = [s for s in path.split("/") if s]
        if len(segments) < 4 or segments[0] != "gh":
            return ["jsDelivr 地址格式应为 cdn.jsdelivr.net/gh/<owner>/<repo>@<ref>/<file>"]
        repo_part = segments[2]
        ref = repo_part.split("@", 1)[1] if "@" in repo_part else ""
    else:
        # 自建镜像/图床：无法判断，交由人工确认
        return []

    if COMMIT_SHA.fullmatch(ref):
        return []
    lowered = ref.lower()
    if lowered in ("main", "master", "head") or re.fullmatch(r"xime_(theme|theme_pack|net|flypy_proxy)", lowered):
        return [f"URL 固定到了分支名 `{ref}`：必须改用 40 位 commit 或 Release 资产"]
    if allow_tag:
        print(f"⚠ 提示：`{ref}` 不是 40 位 commit，按 tag 处理（可移动，属次选）。", file=sys.stderr)
        return []
    return [f"`{ref}` 不是 40 位 commit：改用 Release 资产或 commit 固定；"
            f"确属 tag 时加 --allow-tag"]


def main() -> int:
    try:  # Windows 控制台默认 GBK
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

    parser = argparse.ArgumentParser(description="生成 xime-index 版本条目（含实测 sha256/size）")
    parser.add_argument("--version", required=True, help="版本号，如 1.2.0")
    parser.add_argument("--changelog", required=True, help="版本说明（单行，写进索引）")
    parser.add_argument("--date", default=date.today().isoformat(), help="发布日期，默认今天")
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"产物仓库，默认 {DEFAULT_REPO}")
    parser.add_argument("--tag", help="Release tag，如 xime_theme_pack-1.2.0")
    parser.add_argument("--asset", help="Release 资产名，如 xime_theme_pack.zip")
    parser.add_argument("--file", help="本地产物（预演用；与 Release 取数二选一）")
    parser.add_argument("--sha256", help="已知 sha256（离线填写，跳过网络）")
    parser.add_argument("--size", help="已知大小（如 20.2 MB，配合 --sha256）")
    parser.add_argument("--url", help="下载地址；缺省按 Release 资产地址拼")
    parser.add_argument("--allow-tag", action="store_true", help="允许 tag 固定的 raw/jsDelivr（次选）")
    args = parser.parse_args()

    if not args.url and not (args.tag and args.asset):
        raise SystemExit("需要 --url，或同时给 --tag 与 --asset")

    default_url = (f"https://github.com/{args.repo}/releases/download/"
                   f"{args.tag}/{args.asset}") if (args.tag and args.asset) else ""
    url = args.url or default_url

    # 先校验 URL，避免网络失败掩盖「地址不可变」这种更严重的问题
    problems = check_immutable(url, args.allow_tag)
    if problems:
        print("✗ 下载地址不合规：", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    if args.sha256:
        if not ANY_SHA256.fullmatch(args.sha256):
            raise SystemExit("--sha256 需要 64 位十六进制")
        sha, size_text = args.sha256.lower(), args.size or ""
        if not size_text:
            print("⚠ 只给了 --sha256，size 留空会触发 ci-update --check 告警。", file=sys.stderr)
    elif args.file:
        if not os.path.isfile(args.file):
            raise SystemExit(f"文件不存在：{args.file}")
        sha, size_bytes = sha256_of_file(args.file)
        size_text = human_size(size_bytes)
        print("⚠ 本地文件模式：zip 内含时间戳，本地重打的 sha 与 CI 产物可能不同；"
              "正式上架请以 Release 资产为准。", file=sys.stderr)
    else:
        sha, size_bytes, asset_url = from_release_asset(args.repo, args.tag, args.asset)
        size_text = human_size(size_bytes)
        url = args.url or asset_url

    block = f"""currentVersion: "{args.version}"

  - version: "{args.version}"
    date: "{args.date}"
    changelog: {args.changelog}
    downloadUrl:
      - url: {url}
        sha256: "{sha}"
        size: "{size_text}"
"""
    print(block)
    print("# sha256/size 取自实际产物，PR 时直接粘贴，不要留空或手改。", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
