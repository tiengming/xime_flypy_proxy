# PROGRESS — 工作进度

> 会话开始读本文件，从「下一步」继续；会话结束前更新它。细节与理由见 `DECISIONS.md`。

## 当前状态（2026-10-27）

| 分支 | 状态 | 说明 |
|------|------|------|
| `main` | 已推送，**已发 Release `xime_flypy_proxy-1.0.2`** | 规则/工具 + **v1.0.2** 五套配色对比度修复 |
| `xime_theme_pack` | 已推送，**已发 Release `xime_theme_pack-1.2.0`** | **v1.2.0** 候选页白屏 + 暗色对比度修复 |
| `xime-index` | **PR #16 已提交**（`fix/layouts-v120-v102`） | <https://github.com/ximeiorg/xime-index/pull/16>（xime_flypy_proxy 1.0.2 + xime_theme_pack 1.2.0） |

### 本轮完成

1. 调研三个仓库规则：本仓库分支/发版工作流、`xime-index` 上架规范、`xime-docs` 配置语义；
   并核对 `ximeiorg/Xime` 客户端取色逻辑（证据见 `DECISIONS.md` D1~D3）。
2. 定位「候选页」bug 根因：图片主题的**展开候选页**用 `keyboard_bg_color` 纯色兜底，
   银河漫游 / 星月童话候选文字近白 + 未配底色 → 亮色模式白底白字（1.12:1）。
3. 写出对比度校验脚本 `tools/check_colors.py`，并据此审计全部配色。
4. `xime_theme_pack` v1.2.0：
   - 银河漫游 `keyboard_bg_color: 0x1E1E3E`、星月童话 `0x161D34`（修展开页）；
   - 10 套主题补 `special_key_bg_color_dark`（暗色特殊键 ≥4.5:1）；
   - 8 套主题压暗 `candidate_selected_text_color`（≥3:1）；
   - 深海亮色候选文字、极光暗色键面字修正；
   - 文档：背景图 11→10、截图对应关系更正、新增 v1.2.0 说明与已知限制。
5. 分支内加 `AGENTS.md` 指针（规则以 `main` 为准）。
6. 索引取数规则改为「**PR 时实测填满**」：新增 `tools/index_entry.py`（读 Release 资产
   digest 或本地文件算 sha256/size，生成可粘贴条目，拒绝分支名 URL）；已用 1.1.0 资产回归，
   digest 与线上索引完全一致（`bebe0c23…fee2` / 20.2 MB）。
7. `main` v1.0.2（用户授权）：7 处对比度修复——apple/claude/notion 亮色选中色压暗到 ≥3:1，
   starry/notion/claude/apple 暗色特殊键补 `special_key_bg_color_dark` 到 ≥4.5:1；
   material_you 原本达标未动。截图沿用（变化小）。

### 验证结果（可复跑）

```text
# xime_theme_pack v1.2.0（工作区）             → ✓ 15 套 / 30 组合全部达标
# xime_theme_pack v1.1.0（56350ab）            → ✗ 23 处不达标
# main 布局 v1.0.2（工作区）                    → ✓ 5 套 / 10 组合全部达标
# main 布局 v1.0.1 前（7e46bdf）                → ✗ 7 处不达标
# tools/index_entry.py 对 1.1.0 资产回归        → sha256 bebe0c23…fee2 / 20.2 MB（= 线上索引）
```

最严重的修复前数值：`image_galaxy`/`image_moonlit` 展开页 1.12/1.13:1、
`image_moonlit` 暗色特殊键 1.87:1、`gradient_ocean` 亮色选中 1.74:1、
`main` 的 apple 亮色选中 2.01:1 / claude 暗色特殊键 2.59:1。

## 下一步

1. ~~确认配色 / push / 发 Release / 取数 / 改索引~~ → **全部完成**：
   - Release：`xime_theme_pack-1.2.0`（yaml + zip 20.2 MB）、`xime_flypy_proxy-1.0.2`（yaml 17.3 KB）；
   - 索引条目已按实测 sha256/size 填满，分支 `fix/layouts-v120-v102` 已推 fork；
   - **PR #16**：<https://github.com/ximeiorg/xime-index/pull/16>。
2. **等维护者 review / merge**。若 CI 报错或要求改字段，修 fork 分支后推同一分支即可自动更新 PR。
3. 合并后核对线上 `layouts/index.yaml` 是否出现 1.2.0 / 1.0.2，并抽查 `sha256` 一致。
4. 截图重拍（可选）：两版都只动了选中色/暗色特殊键，`images/img1~5` 观感变化小；
   若后补可把索引截图 URL 换到新 tag。
5. 可选：把 `tools/check_colors.py` 接进 GitHub Actions（PR 时对改动分支跑一遍）。

## 备注

- 本仓库无构建产物/单元测试框架；「一致性检查」= `git status` 干净 + 校验脚本通过 + YAML 可解析。
- 只改 `main` 文档会让 `main` 在下次发版时显示「版本未递增，跳过」，属预期。
- `main` 的 tag 前缀（历史 `xime_flypy_proxy-v1.0.1` 带 `v`，工作流生成不带 `v`）用户已确认
  **忽略**；本次 `VERSION=1.0.2` 会生成 `xime_flypy_proxy-1.0.2`，索引按实际 tag 填。
