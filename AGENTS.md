# AGENTS.md — xime_flypy_proxy 工作区规则

> 读者：接手本仓库的 AI 或人。**动手前先读完本文件**，再读 `PROGRESS.md`（当前进度）
> 与 `DECISIONS.md`（重要决策与理由）。最后更新：2026-10-27。

## 0. 一句话

本仓库用「**一个 git 分支 = 一个可上架的 Xime 扩展产物**」的方式托管布局、配色与
资源；分支内容经 Release 工作流打包成不可变附件，再由 **xime-index** 仓库的 PR
登记上架。**本仓库只放产物与规则，不放应用源码。**

三个仓库各管一段，别搞混：

| 仓库 | 角色 | 你能改吗 |
|------|------|----------|
| `tiengming/xime_flypy_proxy`（本仓库） | 产物：每个分支一套 `xime.custom.yaml`（可选 `themes/`、`fonts/`） | ✅ 可以 |
| `ximeiorg/xime-index` | 上架索引：`src/layouts|rimes|plugins|models/<id>.yaml` | ⚠️ 只通过 PR；**不主动推送/开 PR** |
| `D:\project\xime-docs`（ximeiorg/xime-docs） | 官方文档站源码，规格以它为准 | ❌ **只读，不可修改** |

---

## 1. 分支模型

| 分支 | 产物 | Release tag 前缀 | 索引条目（xime-index） |
|------|------|------------------|------------------------|
| `main` | 小鹤双拼多功能布局（5 套配色 + 五排键位 + 自建索引加速） | `xime_flypy_proxy-` | `layouts/xime_flypy_proxy.yaml` |
| `xime_theme` | 五套配色（仅 `color_schemes`，无键位） | `xime_theme-` | `layouts/xime_custom_themes.yaml` |
| `xime_theme_pack` | 主题大礼包（15 套配色 + 双字体 + 10 张背景图，zip 交付） | `xime_theme_pack-` | `layouts/xime_theme_pack.yaml` |
| `ximenet` | 扩展商店索引加速（仅 `xime_index.base_urls`） | `xime_index_net-` | `layouts/xime_index_net.yaml` |

新增模块（方案 / 插件 / 模型 / 新布局）时的约定：

- **一个新分支只放一个可独立安装的产物**。分支名用 `[a-z0-9_]`，与索引条目 `id` 对齐更省事。
- 分支根目录必须含 `VERSION`（纯文本，如 `1.2.0`）与 `xime.custom.yaml`。
- 图标/截图放 `images/`，只用于索引与 README，不随安装部署。
- 未在 `build-release.sh` 里登记的**新分支**会落到兜底命名
  `xime_flypy_proxy-<分支名>-<版本>`；需要别的 tag 前缀时改
  `.github/scripts/build-release.sh` 的 `case` 映射（同时在 `PROGRESS.md` 记一笔）。
- 纯文档/工具类改动不要开新分支；放 `main`（见 §3）。

---

## 2. 工作规则（用户明确要求，逐条执行）

1. **每次只做一个功能点**。
2. 当前功能点**端到端验证通过**后，才能开始下一个。
3. **不要在实现功能 A 时「顺便」重构功能 B**。
4. 当觉得有必要时，就添加单元测试（本仓库对应 `tools/check_colors.py` 一类的校验脚本）。
5. **不主动 push、不主动开 PR**，必须经用户明确同意。
6. 发版前必须递增分支内 `VERSION`（否则 CI 判定「内容有变、版本未递增」直接跳过）。

### 2.1 每次会话开始（上班打卡）

1. 读 `PROGRESS.md` 了解当前状态；
2. 读 `DECISIONS.md` 了解重要决策；
3. 做一致性检查（本仓库没有构建产物，等价于「仓库处于一致状态」）：
   ```powershell
   git status --short          # 不应有意外改动
   git log --oneline -3        # 确认在预期分支/提交
   python tools/check_colors.py xime.custom.yaml   # 在配色/主题分支上必跑
   ```
4. 从 `PROGRESS.md` 的「下一步」继续。

### 2.2 每次会话结束前（下班打卡）

1. 更新 `PROGRESS.md`（做了什么、验证结果、下一步）；
2. 有新的取舍/踩坑，记入 `DECISIONS.md`；
3. 本地 commit（**不推送**）。

---

## 3. 文档与工具放哪

- 仓库级规则、工具 → `main` 分支（`AGENTS.md`、`PROGRESS.md`、`DECISIONS.md`、`tools/`）。
- 各产物分支只放产物 + 一段 `AGENTS.md` 指针（指向 `main:AGENTS.md`），避免规则多份漂移。
- 工作流脚本只在 `main`：`.github/workflows/auto-archive.yml` 与 `.github/scripts/build-release.sh`。
  任何分支的 Release 都由 `main` 的脚本执行，所以改脚本只改 `main`。

---

## 4. 发版工作流（`.github/workflows/auto-archive.yml`）

触发条件：**任意 Release 被 publish**。流程要点：

1. 强制 checkout `main`，`git fetch --all --tags`。
2. 遍历所有远端分支；读分支 `VERSION`（没有则用全局版本并告警）。
3. 组装 `tag = <前缀>-<版本>`：
   - tag 已存在且指向**同一 commit** → 跳过打包（无变化）；若资源 zip 缺失会补传。
   - tag 已存在但 commit **不同** → 判定 `VERSION` 未递增，跳过并告警。
   - tag 不存在 → 打 annotated tag + 建 Release。
4. 上传资产：
   - 始终上传分支根的 `xime.custom.yaml`；
   - 分支含 `themes/` 或 `fonts/` 时，额外打 **根级 zip**（`xime.custom.yaml` + `themes/` + `fonts/` +
     `NOTICE.md`/`README.md`），文件名 `<分支名>.zip`；
   - `gh release view --json assets` 读官方 digest 作为 sha256。
5. 在本轮触发 Release 的正文里追加汇总表（`<!-- AUTO_SUMMARY_START/END -->` 包裹）。

发版检查清单：

- [ ] 改了产物 → 递增该分支 `VERSION`；
- [ ] `git push` 分支（**需用户同意**）；
- [ ] 在 GitHub 发布任意 Release（标题随意，例如 `publish 2026-10-27`）触发工作流；
- [ ] 核对新 tag（如 `xime_theme_pack-1.2.0`）的资产、sha256、大小；
- [ ] 到 xime-index 新增版本条目（见 §5），**sha256/size 用 §7.2 的 `tools/index_entry.py`
      取实际产物填满**，PR 需用户同意后再提。

> 只改文档/工具也会让 `main` 的 commit 变化，下次发版时 `main` 会显示
> 「版本未递增，跳过」——这是预期行为，不影响其他分支。

---

## 5. xime-index 上架规范（PR 目标）

完整规范：`xime-index` 仓库 `CONTRIBUTING.md`、`LAYOUT_SPEC.md`。要点：

### 5.1 通用

- **PR 只改 `src/` 下的源文件**；`layouts/index.yaml`、`rimes/index.yaml`、`plugins/` 等
  子索引由 `python scripts/ci-update.py` 生成，绝不手改。
- 条目文件名 = 条目 `id`（`id` 限 `[a-z0-9_]`）。
- 提交 PR 前本地跑 `python scripts/ci-update.py`，CI 会复核结构与链接可达性。
- 旧版本记录**不能删**，索引要保留历史以便回滚。

### 5.2 布局 / 配色（本仓库的主战场，`src/layouts/<id>.yaml`）

```yaml
id: xime_theme_pack
name: "xime 主题包"
author: tiengming
description: 一句话说明（会显示在商店卡片）
tags: [配色]                 # 布局 | 配色 | 快捷键 | 输入法适配
repo: https://github.com/tiengming/xime_flypy_proxy
license: GPL-3.0             # 必填
appVersion: ">=3.0.0"        # 应用兼容范围
requiresSchemes: []          # 依赖的输入方案 id，缺依赖时商店置灰
screenshots:                 # 1~5 张，仅详情页
  - https://cdn.jsdelivr.net/gh/tiengming/xime_flypy_proxy@xime_theme_pack-1.1.0/images/img1.jpg
currentVersion: "1.2.0"
versions:
  - version: "1.2.0"
    date: "2026-10-27"
    changelog: ...
    downloadUrl:
      - url: https://github.com/.../releases/download/xime_theme_pack-1.2.0/xime_theme_pack.zip
        sha256: "bebe0c23…（64 位，实测）"
        size: "20.2 MB"       # 实测；两项都必须填满
```

硬性要求：

- **下载地址必须不可变**，可靠性排序：Release 附件 > 固定 commit 的 raw/jsDelivr > 固定 tag。
  **禁止指向分支名**（`main` / `xime_theme_pack`），否则 sha256 立刻失效。
- `sha256` 客户端强校验，不匹配直接丢弃。
- **`sha256` / `size` 必须在提 PR 前实测填满，不要留空等 CI**：`src/` 里记录的 sha256 是可信
  指纹，`scripts/ci-update.py` 只拿它校验远端文件、**不会**把 `src/` 的空值补上（只在生成
  `layouts/index.yaml` 时用实际下载结果补生成物）。留空 → `--check` 告警且无法校验；填错 →
  被判定「上游内容被替换」，该版本**整版不进索引**。取数用 §7.2 的 `tools/index_entry.py`。
- Release 资产一旦被重建（删了重新上传），zip 的 sha256 会变（zip 内含 mtime），索引必须同步改。
- 截图：1~5 张、宽 ≥720px、9:16、≤500KB、URL 固定到 tag/commit（**不要用分支名**）。
- 纯布局不要包含 `xime_index`、`style.color_scheme` 等与布局无关的样板，避免覆盖用户
  自己的索引地址/当前主题。**配色包是例外**：`color_schemes` 就是内容；`style.color_scheme`
  会覆盖用户当前主题，属「立即看到效果」的有意取舍（见 `DECISIONS.md`）。
- zip 交付：解压后**根目录**必须是 `xime.custom.yaml`（不能有 `my_layout/` 外壳），
  资源只能用 `themes/*.(png|jpg|webp|gif)` 与 `fonts/*.(ttf|otf)`，路径不得含 `..` 或绝对路径；
  安装逻辑会整体覆盖 `xime.custom.yaml`，**不保留备份**。
- 资源引用一律相对路径（`themes/x.jpg`、`fonts/x.ttf`），客户端解析到 `rime/themes`、`rime/fonts`。

### 5.3 方案 / 插件 / 模型（未来可能进本仓库的类型）

| 类型 | 包格式 | 索引源 | 关键校验 |
|------|--------|--------|----------|
| 输入方案 | `.zip`/`.tar.gz`，含 `.schema.yaml` + `.dict.yaml` | `src/rimes/<id>.yaml` | `id` 与 `schema_id` 一致；`dependencies` 声明 |
| 插件 v1（Lua/DEX） | `.xipk` | `src/plugins/v1/<id>.yaml` | 旧版 App 用，勿移除 |
| 插件 v2（TS/QuickJS） | `.xipk` = `manifest.json` + `main.js` + `resources/`（`xipm pack` 产物） | `src/plugins/v2/<id>.yaml` | 宿主 ≥3.0.0；`pluginType`/`minHostVersion`/`platforms`/`capabilities`/`network` 取自 manifest |
| 模型 | 文件列表型或 `tar.bz2` 归档型 | `src/models/<id>.yaml` | `category` ∈ prediction/asr/punctuation/stroke/other |

插件 v2 的真相在 `manifest.json`（`id/type/version/icon/platforms/minHostVersion/network/
toolbarButtons/capabilities`），索引 yaml 是它的投影；`activation`、`configSchema` 等旧字段宿主
**不再消费**。插件文档见 `D:\project\xime-docs\docs\plugins\PLUGIN_DEVELOPMENT_GUIDE.md`。

---

## 6. `xime.custom.yaml` 语义与坑（务必按客户端真实行为写）

规格来源：`D:\project\xime-docs\docs\features\keyboard-config-v2.md`。
下列「渲染事实」由 `ximeiorg/Xime`（main，2026-10 校对）源码核对得出，文件路径见 §8。

### 6.1 顶层结构

```yaml
metadata:      # 可选（app_name / app_version / platform / config_version / generator / modified_time）
xime_index:    # 可选。索引镜像列表，末位要带 `/`
style:         # 全局样式：color_scheme / font_size / candidate_count ...
color_schemes: # 配色定义
keyboard:      # colors / key / shadow / fonts / 各键盘段（layout.rows + keys）
```

### 6.2 配色字段与回退链

`color_schemes.<id>`：`name`、`primary_color`、`keyboard_background`、
`key_bg_color(_dark)`、`key_text_color(_dark)`、`candidate_text_color(_dark)`、
`candidate_selected_text_color(_dark)`、`special_key_bg_color(_dark)`、
`keyboard_bg_color`、`key_background`、`candidate_bar_bg_color`、`candidate_bar_background`、
`dynamic_color`。

- 文字色/键色未配置 → 回退 `keyboard.colors.*` 同名全局值。
- **强调色**：亮色 = `primary_color`；暗色 = `lighten(primary, 0.45)`（代码计算，不可配）。
- 选中文字未配置 → 回退强调色；特殊键未配置 → 亮色 `lighten(primary, 0.8)`、暗色 `primary`。

### 6.3 背景三态（`keyboard_background`）

| type | 字段 | 说明 |
|------|------|------|
| `solid` | `color`、`color_dark` | 暗色缺省自动暗化 |
| `gradient` | `colors`、`colors_dark`（≥2）、`angle` | 0=左→右，90=下→上 |
| `image` | `src`、`src_dark`、`fit`、`overlay_alpha`、`overlay_alpha_dark` | `src` 相对 `rime/`；`fit`: cover 默认 / contain / fill / fit_width / fit_height / none |

### 6.4 渲染事实（踩坑高发区）

1. **候选栏是透明的**：键盘背景（图片/渐变）会铺到候选栏后面，候选文字直接压在背景上。
   `candidate_bar_bg_color` / `candidate_bar_background` 虽能被解析，**客户端从未渲染**
   （死配置），别指望它们给候选栏加底色。
2. **「展开候选页」用纯色兜底**：背景 = 该配色的 `keyboard_bg` 纯色值（图片不参与渲染）：
   渐变取 `colors[0]`，图片取 `keyboard_bg_color`（没配则亮色白、暗色 `#1C1B1F`），
   纯色取 `color`。候选文字用 `candidate_text_color(_dark)`。
   → 图片主题若候选文字是浅色、又没配 `keyboard_bg_color`，展开页就是**白底白字**。
3. **`keyboard_bg_color` 没有 `_dark` 字段**：暗色值 = 亮色值 × 0.7（自动）。
4. **特殊键文字按底色亮度二选一**：底色 `luminance > 0.5` → 用按键文字色；否则固定
   `#E8EAED`。亮色 primary（金/橙/粉）会被判成「暗底」→ 浅灰字压在亮键面上。
   解法：给暗色模式单独配 `special_key_bg_color_dark`（同色相压暗）。
5. **选中候选胶囊** = 强调色 20% 叠在候选栏背景上，选中文字用 `candidate_selected_text_color`。
   浅色主题要按这个叠加结果算对比度，不能按纯背景算。
6. **键面色可以带 alpha**（如 `0x99FFFFFF` 玻璃键），实际颜色 = 键色叠加在键盘背景上。
7. 候选文字/选中色在**亮暗两套字段**下都要能读；`style.color_scheme` 支持字符串或 `{light, dark}`。

### 6.5 键盘布局（新版 schema）

- `layout.rows` 是键位的**唯一来源**（4 行标准 / 5 行含数字行；最多 5 行，缺行用内置补齐）。
- 功能键（`shift/delete/enter/space/mode_change/comma/earth`…）与字母键一视同仁，都在
  `keys.<id>` 配手势；`rows` 里没写就不出现。
- 合并键：行元素写子数组（`[q, w]`），`keys` 里的 id 为组内字母拼接（`qw`）。
- 手势槽位：`tap / double_tap(仅 shift) / long_press / swipe_up / swipe_down / swipe_left / swipe_right`。
- `long_press` 只有 `{ display?, values: [...] }` 一种写法（旧的数组简写已废弃）。
- `display` 只管静态提示位置；`bubble` 独立控制运行时气泡。
- 段级：`schemas` 追加绑定方案；`type`（full/t9/stroke/handwriting/columns）可显式声明段类型。
- 平板变体：`qwerty_tablet` / `qwerty_en_tablet` / `number_tablet` 等整段替换同名基础段。

### 6.6 字体

`keyboard.fonts`：`key_font`（键面）、`key_label_font`（字根/标签，缺省内置 ChaiPUA）、
`candidate_font`、`comment_font`。路径规则：绝对路径 → 应用数据根；`rime/...` → 应用根下
`rime/`；含 `/` 的相对路径 → `rime/`；仅文件名 → 与 `xime.custom.yaml` 同目录。
缺文件自动回退系统字体，不报错。

---

## 7. 校验工具

### 7.1 配色对比度：`tools/check_colors.py`

复算 Xime 客户端取色逻辑，检查每个配色在亮/暗两套
模式下的：展开候选页、候选栏、键面、候选选中、特殊键对比度。

```powershell
pip install pyyaml pillow          # 一次性依赖；无 Pillow 时图片主题退化为纯色近似

# 切到产物分支（themes/、fonts/ 都在），脚本从 main 取——图片路径按 yaml 所在目录解析：
git checkout xime_theme_pack
git show main:tools/check_colors.py > "$env:TEMP/check_colors.py"
python "$env:TEMP/check_colors.py" xime.custom.yaml     # 默认：文字 ≥4.5:1、选中 ≥3:1
```

- 图片主题按「键盘区域 fit=cover」把图片映射回键盘，取区域**平均色**作为背景近似；
  图片亮斑/暗斑属像素级噪声，不参与判定（见 `DECISIONS.md`）。
- 局限：无法模拟「展开候选页左栏符号」这类由半透明键色 + 候选色拼出的组合（配置层没有
  独立字段），这类问题需装机目测。
- 改了配色/新增主题后，**提交前必须让脚本全绿**。
- 图片必须与 yaml 在同一目录树内（否则脚本按「图片缺失」回退纯色，结果会偏保守）。

### 7.2 索引条目取数：`tools/index_entry.py`

发布后（Release 资产已生成）在 `main` 上跑一条命令，生成可直接粘贴进
`xime-index/src/layouts/<id>.yaml` 的版本块（sha256/size 均来自实际产物，不留空）：

```powershell
python tools/index_entry.py --tag xime_theme_pack-1.2.0 --asset xime_theme_pack.zip `
    --version 1.2.0 --changelog "修复图片主题展开候选页白底白字……"
```

- 走 GitHub Release API 读官方 `digest` / `size`（老资产无 digest 时下载后本地计算）；
  国际网络需 `HTTPS_PROXY`。
- 离线：`--sha256 <64位> --size "20.2 MB"`；本地预演：`--file x.zip`（zip 含 mtime，
  **不能直接上架**，仅用于格式自检）。
- 会拒绝分支名 / `tree` / `blob` 等可变 URL；tag 固定需显式 `--allow-tag`（次选）。
- 自检基准：`--tag xime_theme_pack-1.1.0 --asset xime_theme_pack.zip --version 1.1.0`
  应输出 `sha256: bebe0c23…fee2`、`size: 20.2 MB`（与线上索引一致）。

---

## 8. 规格与证据来源

- 文档（只读）：`D:\project\xime-docs\docs\features\keyboard-config-v2.md`（完整字段）、
  `features/extension-store.md`（商店与索引）、`plugins/PLUGIN_DEVELOPMENT_GUIDE.md`（插件）。
- 客户端源码（只读参考，勿在本仓库引入）：`ximeiorg/Xime` main：
  - `ui/theme/KeyboardTheme.kt`：配色解析、回退、强调色、图片取主色
  - `ui/theme/KeyboardBackground.kt`：solid/gradient/image 绘制与遮罩
  - `ui/keyboard/CandidateBar.kt`：候选栏透明、选中胶囊 20% 强调色
  - `ui/keyboard/CandidatePage.kt`：展开候选页不透明纯色背景
  - `ui/keyboard/KeyboardView.kt`：取色与特殊键文字规则
  - `settings/KeysConfigHelper.kt`：`color_schemes` 可解析字段全集（含死配置）
- 索引规范：`ximeiorg/xime-index` 的 `CONTRIBUTING.md` 与 `LAYOUT_SPEC.md`。

> 客户端行为随版本变化。改配色逻辑前先核对该版本源码；确认字段失效时更新本文件与
> `DECISIONS.md`，不要凭记忆写。

---

## 9. 已知问题 / 待办

- `main` 布局的 7 处对比度已在 v1.0.2 修复（亮色选中色 + 暗色特殊键），`tools/check_colors.py`
  对 5 套配色全部通过；截图沿用旧图（观感变化小）。
- 银河漫游 / 星月童话的展开候选页左栏符号≈2.4:1，属客户端限制（无分栏配色字段）；
  若后续客户端支持展开页独立配色，去掉 `keyboard_bg_color` 兜底 workaround。
- `themes/` 实际 10 张背景图（旧文档写 11 张，v1.2.0 已更正）。

## 10. 禁止事项

- 不主动 `git push`、不主动开 PR/Release（除非用户明确同意）。
- 不修改 `D:\project\xime-docs`（官方文档仓库，只读）。
- 不删除旧的 Release/资产/索引版本记录（索引要能回滚）。
- 索引与截图 URL 不使用分支名。
- 不在纯布局产物里塞 `xime_index` / `style.color_scheme` 等会覆盖用户配置的样板。
- 不手改 `xime-index` 生成的 `layouts/index.yaml` 等子索引。
