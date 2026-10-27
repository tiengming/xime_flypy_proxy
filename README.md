# xime 主题包（xime_theme_pack 分支）

Xime 输入法**主题大礼包**：15 套配色 + 双字体 + 10 张原创背景图，
**合并写在同一份 `xime.custom.yaml` 里**——扩展商店一次安装，应用内随意切换，互不顶替。

> 为什么合并成一份？扩展商店应用布局时会整体覆盖 `xime.custom.yaml`（不保留备份），
> 拆成多个布局包会互相覆盖；且 `keyboard.fonts` 是全局配置不随配色切换，合并是唯一顺滑的形态。

## 主题一览（v1.2.0，15 套）

| 家族 | 名称 | scheme id | 说明 |
|------|------|-----------|------|
| Material You | 紫罗兰 | `material_violet` | M3 基准调色板（默认启用） |
| Material You | 暖玫瑰 | `material_rose` | M3 粉色调性 |
| Material You | 海蓝 | `material_ocean` | M3 蓝色调性 |
| Material You | 松绿 | `material_forest` | M3 绿色调性 |
| 渐变 | 极光梦境 | `gradient_aurora` | 青紫极光三断点 + 玻璃按键 |
| 渐变 | 暮霞 | `gradient_sunset` | 琥珀→珊瑚→玫瑰 |
| 渐变 | 青提薄荷 | `gradient_mint` | 清凉薄荷绿 |
| 渐变 | 樱粉雪 | `gradient_sakura` | 樱粉→淡蓝 |
| 渐变 | 深海 | `gradient_ocean` | 深海蓝经典渐变 |
| 图片背景 | 银河漫游 | `image_galaxy` | 银河带 + 星云 + 流星（亮暗双用） |
| 图片背景 | 晨雾云海 | `image_mist` | 晨光透镜云 + 远山淡影（暗色切暮色流光） |
| 图片背景 | 远山拾光 | `image_mountains` | 四层山脊剪影 + 飞鸟（暗色切月下远山） |
| 图片背景 | 樱吹雪 | `image_sakura` | 花枝 + 满屏落樱（暗色切夜樱） |
| 图片背景 | 星月童话 | `image_moonlit` | 大月亮环形山 + 月海带 + 山丘 |
| 图片背景 | 落日海平线 | `image_sea` | 半沉日 + 海面粼光 + 远岛（暗色切月光海） |

- Material You 家族按 M3 色调结构设计：浅色 primary≈L48 / 深色 primary≈L80，表面色阶随模式成对出现。
- 渐变家族使用 3 断点渐变 + 半透明玻璃按键（`0x99FFFFFF` 系），圆角 14。
- 图片家族为**有画面内容的场景图**（与渐变家族一眼可区分）：10 张 1080×2400 原创程序化生成。
- 全部配色按 Xime 实际取色逻辑复核对比度：键面文字 / 候选文字 ≥ 4.5:1、候选选中色 ≥ 3:1
  （亮暗两种模式）。复核脚本见仓库 `main` 分支 `tools/check_colors.py`。

## v1.2.0 更新（候选页与暗色对比度修复）

> 这一版不新增主题、不改键位与字体，只修可读性问题。

- **修复「展开候选页」白屏**：候选展开页用 `keyboard_bg_color` 的**纯色兜底**作底色
  （背景图不参与该页渲染）。银河漫游 / 星月童话的候选文字是近白色，此前没有纯色兜底，
  亮色模式下整页变成「白底白字」。现为这两套补上取自背景图的深空色：
  `image_galaxy` `0x1E1E3E`、`image_moonlit` `0x161D34`（暗色由应用自动调暗）。
- **修复暗色特殊键白字发虚**：`shift / 退格 / ?123 / 确定` 等特殊键的暗色底色默认取
  `primary_color`，应用按「底色亮度 > 0.5 用按键文字色，否则浅灰」选字。星月的亮金
  （1.87:1）、落日的橙（2.51:1）、樱粉（2.96:1）、银河紫（3.51:1）都被判成「暗底」，
  浅灰字压在亮键面上。现为这些主题补 `special_key_bg_color_dark`（同色相压暗，≥ 4.5:1）。
  同一处理也覆盖了暮霞 / 青提 / 樱粉雪 / 深海渐变的暗色特殊键（2.81~4.45:1）。
- **候选选中色统一 ≥ 3:1**：选中胶囊是「20% 强调色叠在候选栏背景」上，浅色主题原有
  1.7~2.7:1。全部同色相压暗到 ≥ 3:1（如暮霞 `0xB03A6E→0x882D55`、深海 `0x0C647C→0x073D4C`）。
- **深海亮色候选文字**：主渐变首断点 `0x2193B0` 上 `0x0E2A3A` 仅 4.16:1，压暗为 `0x0B2230`（4.56:1）。
- **极光梦境暗色键面字**：暗色渐变底部青绿段上玻璃键面偏亮，`0xE6F2FF` 仅 4.45:1，改纯白 5.05:1。
- **文档修正**：背景图数量 11→10（`themes/` 实际 10 个文件，晨雾云海的暗色变体是 `dusk_glow.jpg`）；
  截图对应关系按实际画面更正。

已知限制：银河漫游 / 星月童话的展开候选页「左栏符号」底色来自半透明键色（浅灰），文字跟随
候选色（白），约 2.4:1。配置层没有分栏取色的字段，属应用侧限制；后续若客户端支持
`candidate_page` 独立配色可直接消除。

## 自定义字体

| 槽位 | 字体 | 说明 |
|------|------|------|
| `key_font` 键面主字 | Maple Mono NL CN Regular | 圆角等宽字形，配玻璃键面；含 CJK |
| `candidate_font` 候选词 | 霞鹜文楷 Regular | 楷体气质，候选识别度 |
| `comment_font` 候选注释 | 霞鹜文楷 Regular | 同上 |
| `key_label_font` 字根/标签 | 保留内置 ChaiPUA | 兼容五笔字根 / CJK 扩展区 |

两款字体均为 SIL OFL 1.1，全文见 [NOTICE.md](NOTICE.md)。
注意：zip 内嵌两款全量中文字体，包体约 44 MB，介意流量的用户请在 Wi-Fi 下下载。

## 使用方法

- **扩展商店**：设置 → 扩展 → 扩展商店 → 布局 → 「xime 主题包」→ 应用（自动下载 zip 并部署）。
- **手动导入**：下载本分支 zip，解压后将 `xime.custom.yaml`、`themes/`、`fonts/` 原样放入手机 `rime/` 目录
  （或通过 xime App → 输入方案 → 已导入 → 右上角 + → 浏览器导入 逐个上传），然后**重新部署**。
- 在主题设置里切换任意一套配色。**切换主题后需重启输入法生效**（切到其他输入法再切回，或重启设备）。

## 兼容性

- Xime ≥ 3.0.0（扩展商店布局功能）；图片背景需 v2.6.0+、自定义字体需 v2.8.0+。
- 只含配色 / 外观 / 字体配置，不含 `xime_index` 与键位改动，不改变打字习惯。
- 字体文件缺失或加载失败时自动回退系统字体，不影响输入。

## 包结构（zip 交付形态）

```
xime.custom.yaml        # 15 套配色 + 键盘外观 + 字体槽位（根级，必需）
themes/                 # 10 张场景背景图 jpg（部署到 rime/themes/）
fonts/                  # Maple Mono NL CN + 霞鹜文楷 ttf ×2（部署到 rime/fonts/）
NOTICE.md               # 字体/图片版权说明（不随安装部署）
README.md               # 本文件（不随安装部署）
```

## 截图（v1.1.0 实机，v1.2.0 未重拍）

`images/` 内为真机截图（1440×3200 裁掉状态栏/导航栏后缩至 1080 宽，单张 ≤170KB）：

| 文件 | 主题 | 模式 |
|------|------|------|
| `img1.jpg` | 落日海平线 | 亮色 |
| `img2.jpg` | 暮霞 | 暗色 |
| `img3.jpg` | 星月童话 | 暗色 |
| `img4.jpg` | 落日海平线 | 暗色 |
| `img5.jpg` | 银河漫游 | 暗色 |

> v1.2.0 只调整了候选选中色与暗色特殊键底色，布局、字体与背景图未变；截图仍可代表整体观感。
> 索引中的截图 URL 已固定到 tag `xime_theme_pack-1.1.0`。发 v1.2.0 后可改为新 tag，**不要用分支名**。

## 发版流程

1. 修改后更新 `VERSION`（必须递增，否则 CI 检测到内容变化会跳过打包）。
2. 推送分支后发布任一 Release 触发 auto-archive 工作流：自动打 tag `xime_theme_pack-<版本>`，
   上传 `xime.custom.yaml` 与 `xime_theme_pack.zip`（含字体/图片），并在 Release 页生成 sha256 汇总表。
3. 到 xime-index 仓库 `src/layouts/xime_theme_pack.yaml` 顶部新增版本记录，
   **`sha256` / `size` 必须用实际产物填满，不能留空等 CI**（`src/` 里的 sha256 是校验指纹，
   CI 不回写空值；填错会被判为内容被替换而整版不进索引）。取数用 main 分支的工具：
   ```bash
   git show main:tools/index_entry.py > /tmp/index_entry.py
   python /tmp/index_entry.py --tag xime_theme_pack-1.2.0 --asset xime_theme_pack.zip \
       --version 1.2.0 --changelog "…"
   ```
   输出可直接粘贴（含 sha256、size 与 downloadUrl）；再跑 `python scripts/ci-update.py` 生成索引并提 PR。
   注意：Release 资产若被重建（删了重传），zip 内含 mtime 会导致 sha256 变化，索引要同步改。
4. 提交前自检：`python tools/check_colors.py xime.custom.yaml`（脚本在 `main` 分支，
   见 `main:tools/check_colors.py`），确认对比度全部达标。
