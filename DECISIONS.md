# DECISIONS — 重要决策与理由

> 记录「为什么这样做」，避免下次会话推翻重来或重复踩坑。新决策追加在末尾。

## D1. 用 `keyboard_bg_color` 修「展开候选页白屏」，而不是改候选文字色

**症状**：银河漫游 / 星月童话在亮色模式下打开候选展开页，整页白底白字。

**证据**（`ximeiorg/Xime` main，2026-10）：

- `ui/keyboard/KeyboardView.kt`：`CandidatePageState(backgroundColor = keyboardBgColor, textColor = candidateTextColor, ...)`；
- `ui/theme/KeyboardTheme.kt` `buildSchemeFromConfig`：图片背景时 `keyboardBgLight = resolveBgColor(...) ?: Color.White`，
  `resolveBgColor` 对 `type: image` 返回 `null`（只处理 solid/gradient），再回退 `keyboard_bg_color`；
- `ui/keyboard/CandidatePage.kt`：页面 `Modifier.background(state.backgroundColor)` 是**不透明纯色**，
  图片背景不会画到这一页。

**备选方案与否决理由**：

| 方案 | 否决理由 |
|------|----------|
| 候选文字改深色 | 普通候选栏是透明的、直接压在深色星空图上，深色字在栏上又不可读 |
| 配 `candidate_bar_bg_color` | `KeysConfigHelper` 能解析，但全仓库无渲染调用（死配置） |
| 给图片配浅色 `keyboard_bg_color` | 暗色值 = 亮色值 ×0.7（无 `_dark` 字段），浅色底在暗色模式下变中灰，白字仍不可读 |
| 亮色模式换浅色背景图 | 要新画一张「白天的银河」，属重新设计，超出本次 bugfix |

**结论**：配一个与背景图同调的深色 `keyboard_bg_color`，亮暗两模式都得到深色展开页（白字可读）。
暗色模式原本回退 `#1C1B1F` 也可读，配置后变为 `0x16152B`/`0x0F1424`，视觉更统一。

**已知残留**：展开页左栏符号的底色来自半透明键色（55% 白 → 浅灰），文字跟随候选色（白），
约 2.4:1。配置层没有「展开页专用配色」字段，属客户端限制；若官方后续开放独立配色可去掉 workaround。

## D2. 顺手修了「选中色 / 特殊键暗色」两组对比度

**理由**：仓库 README 与索引描述都声明「候选选中色 ≥3:1、键面文字 ≥4.5:1」。实际复算 v1.1.0：

- 选中胶囊 = 20% 强调色叠在候选栏背景上，8 套浅色主题只有 1.7~2.7:1；
- 特殊键暗色底色默认取 `primary_color`，而文字按「底色亮度 >0.5 用按键文字色，否则 `#E8EAED`」选：
  亮金 `#D9A441`(1.87:1)、橙 `#E07840`(2.51:1)、樱粉 `#E0568C`(2.96:1)、紫 `#7C6BD9`(3.51:1) 都被判成「暗底」。

不修就等于把不实声明留在 README/商店里。修法统一为**同色相压暗/加深**（不改色相、不换配色家族），
每项都在 yaml 注释里标了修复前后数值，便于回退。

**取舍**：暗色特殊键会比 v1.1.0 深一档（星月由亮金变暗金），与 v1.1.0 截图不再完全一致；
截图尚未重拍，已在 README 注明。

## D3. 校验脚本用「区域平均色」而不是像素极值

图片主题的键盘背景是照片式场景图，逐像素取最暗/最亮处必然出现局部极低对比度（星点、云边），
但那是像素级噪声，配置层无法修，也无法代表「整块候选栏压在图上」的观感。用键盘区域的**平均色**
（fit=cover 映射回图片）近似，与人工看截图结论一致，也能稳定区分「真白屏」和「局部噪点」。
阈值：普通文字 4.5:1、选中文字 3.0:1（与 README 声明一致），可通过参数调整。

## D4. `AGENTS.md`/`PROGRESS.md`/`DECISIONS.md`/`tools/` 放 `main`，产物分支只放指针

分支各自是独立产物（商店按分支打包），规则若复制到每个分支必然漂移。`main` 是默认分支、
所有会话的入口；产物分支放几行指针（`git show main:AGENTS.md`）即可。工作流脚本本来也只在
`main` 执行（auto-archive 强制 checkout main），职责一致。

## D5. 主题包保留 `style.color_scheme`（与 LAYOUT_SPEC 的字面要求不同）

`LAYOUT_SPEC.md` 要求布局不要带 `style.color_scheme`，避免覆盖用户当前主题。主题包的场景不同：
用户装主题包的目的就是换主题，若不指定默认配色，应用后界面毫无变化（15 套要手动逐个点）。
因此保留 `style.color_scheme: material_violet` 作为「应用即生效」的默认值，属有意取舍。
但 `xime_index` 仍然**不放入**主题包（避免改用户的索引镜像）。

## D6. 不主动推送 / 不开 PR / 不发 Release

用户明确要求。本轮所有改动都是**本地 commit**：`xime_theme_pack` 的 `04009ef`、`main` 的规则与工具。
发 Release 与提交 xime-index PR 由用户确认后再做（README 与 `PROGRESS.md` 已写好步骤）。

## D7. 截图不重拍，只更正对应关系

v1.1.0 的 `images/img1~5` 实际内容与旧 README 的表格不符（旧表把 img1 写成「银河漫游 暗色」，
实际是「落日海平线 亮色」）。数字、日期与画面都能对上，说明只是文档写错，不是图片错。
没有真机无法重拍，故更正表格并注明「v1.2.0 未重拍」；索引截图 URL 保持 1.1.0 tag。

## D8. `sha256` / `size` 在提 PR 时实测填满，不依赖 CI 补全

**背景**：`xime-index` 的 `scripts/ci-update.py` 会把 `src/` 里的 sha256 当作「可信指纹」去
校验远端文件；缺失时只告警（`--check`），并在生成 `layouts/index.yaml` 时才用实际下载结果
补生成物——**不会回写 `src/`**。若留空，评审时无法判断产物是否被替换；若填错，脚本判定
「上游内容已替换」，该版本**整版不进索引**。

**结论**：`src/layouts/<id>.yaml` 的每个版本条目必须带实测 `sha256` + `size`。取数工具
`tools/index_entry.py`：优先读 GitHub Release 资产的官方 `digest/size`，其次下载计算；
离线可 `--sha256/--size`，本地可 `--file` 预演。工具同时拦截分支名 / `tree` / `blob`
等可变 URL（tag 固定需 `--allow-tag`）。

**副作用**：zip 内含 mtime，**构建不可复现**——重建资产 → sha 变化 → 索引必须同步改。
若以后想「发布前预知 sha」，需要把 `build-release.sh` 的 zip 改成固定 mtime 的可复现构建，
那是另一个功能点（已记入 `PROGRESS.md` 待办）。
