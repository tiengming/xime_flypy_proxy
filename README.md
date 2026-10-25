# xime 多主题（xime_theme 分支）

Xime 输入法键盘配色布局：五套主题配色，应用内一键切换。
纯 `xime.custom.yaml` 单文件交付（无字体 / 图片资源，不打包 zip）。

## 主题一览（v1.1.0）

| # | 名称 | scheme id | 风格 |
|---|------|-----------|------|
| 1 | 星野夜航 | `starry_night_voyage` | 紫罗兰渐变（默认启用） |
| 2 | Notion 极简 | `notion_style` | 暖白底 + Notion 蓝 |
| 3 | Claude 暖砂 | `claude_style` | 奶油底 + 赤陶强调 |
| 4 | Apple 原生 | `apple_style` | iOS 系统键盘质感 |
| 5 | Material You 动态 | `material_you` | M3 基准调色板，自动深浅色 |

## v1.1.0 更新内容

- 五套配色全部补齐 `candidate_selected_text_color(+_dark)`：候选栏选中词现在显示主题强调色
  （此前未设置时回退为键文字色，选中态没有强调反馈）。
- **Material You 动态**按 Material Design 3（2024 基准）校准表面色阶：
  - 亮色渐变 `#FEF7FF → #F3EDF7`（surface → surfaceContainer），原为 `#F3EDF7 → #E8DEF8`；
  - 暗色渐变 `#141218 → #211F26`（surface → surfaceContainer），原为 `#1C1B1F → #211F26`；
  - 选中色取 M3 亮色 primary `#6750A4` / 暗色模式 primary `#D0BCFF`。
- 其余四套配色保持原样，星野夜航仍为默认启用主题（`style.color_scheme` 未变）。
- 全部文字 / 背景组合已通过 WCAG 对比度校验（键面文字 ≥ 4.5:1，选中色 ≥ 3:1）。

## 使用方法

1. 获取本分支的 `xime.custom.yaml`（或扩展商店 → 布局，安装本布局一键应用）。
2. 手动导入：xime App → 输入方案 → 已导入 → 右上角 **+** → **浏览器导入** → 上传 → **部署**。
3. 在主题设置中选择任意一套配色。**切换主题后需重启输入法生效**（切到其他输入法再切回，或重启设备）。

## 兼容性

- Xime ≥ 3.0.0（扩展商店布局功能）；`keyboard_background` 渐变需 v2.6.0+，
  `candidate_selected_text_color` 需 v2.6.0-beta3+。
- 本文件只含配色与键盘外观（`color_schemes` / `keyboard.colors|key|shadow`），
  不含 `xime_index` 与键位改动，不会覆盖你的索引地址与键位习惯。

## 截图（待补）

安装后自测截图建议：竖屏键盘区（裁掉状态栏 / 导航栏），宽 ≥ 720px，比例 9:16，
单张 ≤ 500KB，命名 `imgN.jpg` 放入 `images/`。
索引中的截图 URL 需固定到 tag（如 `xime_theme-1.1.0`）或 commit，**不要用分支名**。

## 发版流程

1. 修改内容后更新 `VERSION`（必须递增，否则 CI 检测到内容变化会跳过打包）。
2. 推送分支后发布任一 Release 触发 auto-archive 工作流：自动打 tag `xime_theme-<版本>`、
   上传 `xime.custom.yaml` 附件，并在 Release 页生成各分支文件的 sha256 汇总表。
3. 到 xime-index 仓库 `src/layouts/xime_custom_themes.yaml` 顶部新增版本记录
   （downloadUrl 指向 Release 附件地址），推送后 CI 自动补全 `sha256` / `size` 并重新生成索引。
