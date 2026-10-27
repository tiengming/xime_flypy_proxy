# PROGRESS — 工作进度

> 会话开始读本文件，从「下一步」继续；会话结束前更新它。细节与理由见 `DECISIONS.md`。

## 当前状态（2026-10-27）

| 分支 | 状态 | 说明 |
|------|------|------|
| `main` | 本地已提交（未推送） | `AGENTS.md` / `PROGRESS.md` / `DECISIONS.md` / `tools/check_colors.py` / `tools/index_entry.py` |
| `xime_theme_pack` | 本地已提交 `04009ef`（未推送、未发 Release） | **v1.2.0** 候选页白屏 + 暗色对比度修复 |

### 本轮完成

1. 调研三个仓库规则：本仓库分支/发版工作流、`xime-index` 上架规范、`xime-docs` 配置语义；
   并核对 `ximeiorg/Xime` 客户端取色逻辑（证据见 `DECISIONS.md` D1~D3）。
2. 定位「候选页」bug 根因：图片主题的**展开候选页**用 `keyboard_bg_color` 纯色兜底，
   银河漫游 / 星月童话候选文字近白 + 未配底色 → 亮色模式白底白字（1.12:1）。
3. 写出对比度校验脚本 `tools/check_colors.py`，并据此审计 15 套配色。
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

### 验证结果（可复跑）

```text
# xime_theme_pack v1.2.0（工作区）
python tools/check_colors.py <branch-file>   → ✓ 15 套 / 30 组合全部达标
# 修复前（56350ab / v1.1.0）                 → ✗ 23 处不达标
# main 当前布局（5 套配色）                   → ✗ 7 处不达标（未修，见下一步 4）
# tools/index_entry.py 对 1.1.0 资产回归      → sha256 bebe0c23…fee2 / 20.2 MB（= 线上索引）
```

详细数值：v1.1.0 中最严重的是 `image_galaxy`/`image_moonlit` 展开页 1.12/1.13:1、
`image_moonlit` 暗色特殊键 1.87:1、`gradient_ocean` 亮色选中 1.74:1。

## 下一步

1. **等用户确认 v1.2.0 的配色改动**（尤其：暗色特殊键压暗、选中色变深是否符合预期）。
2. 用户同意后：push `xime_theme_pack` → 发布任一 Release 触发 auto-archive
   → 核对 `xime_theme_pack-1.2.0` 的 `xime.custom.yaml` + `xime_theme_pack.zip` + sha256。
3. 在 `xime-index` 的 `src/layouts/xime_theme_pack.yaml` 顶部加 1.2.0 条目：
   `python tools/index_entry.py --tag xime_theme_pack-1.2.0 --asset xime_theme_pack.zip \
   --version 1.2.0 --changelog "…"` 生成**含实测 sha256/size** 的块（**不留空、不等 CI 补**），
   截图 URL 可保持 1.1.0 tag；**PR 需用户明确同意**。
4. 修 `main` 布局的 7 处对比度（apple/claude/notion 选中色、claude/notion/apple/starry 暗色特殊键），
   单独发版并更新 `layouts/xime_flypy_proxy.yaml`。
5. 截图重拍：v1.2.0 改了暗色特殊键与选中色，`images/img1~5` 仍是 v1.1.0；重拍后把索引截图
   URL 换到新 tag。
6. 可选：把 `tools/check_colors.py` 接进 GitHub Actions（PR 时对改动分支跑一遍）。

## 备注

- 本仓库无构建产物/单元测试框架；「一致性检查」= `git status` 干净 + 校验脚本通过 + YAML 可解析。
- 只改 `main` 文档会让 `main` 在下次发版时显示「版本未递增，跳过」，属预期。

### 待确认的历史不一致
- `main` 的既有 Release tag 是 `xime_flypy_proxy-v1.0.1`（带 `v`），但当前工作流生成
  `xime_flypy_proxy-<VERSION>`（不带 `v`），且 `main` 的 `VERSION` 仍是 `1.0.0`、
  索引里却写着 `1.0.1`。下次发 `main` 前先统一三者（VERSION / tag 前缀 / 索引条目），
  否则新 tag 与索引 downloadUrl 对不上。
