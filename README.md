# xime 主题包（xime_theme_pack 分支）

Xime 输入法**主题大礼包**：11 套配色 + 霞鹜文楷自定义字体 + 3 张原创背景图，
**合并写在同一份 `xime.custom.yaml` 里**——扩展商店一次安装，应用内随意切换，互不顶替。

> 为什么合并成一份？扩展商店应用布局时会整体覆盖 `xime.custom.yaml`（不保留备份），
> 拆成多个布局包会互相覆盖；且 `keyboard.fonts` 是全局配置不随配色切换，合并是唯一顺滑的形态。

## 主题一览（v1.0.0，11 套）

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
| 图片背景 | 银河漫游 | `image_galaxy` | 星穹夜色图（亮暗双用） |
| 图片背景 | 晨雾云海 | `image_mist` | 晨光云海（暗色自动切黄昏图） |

- Material You 家族按 M3 色调结构设计：浅色 primary≈L48 / 深色 primary≈L80，表面色阶随模式成对出现。
- 渐变家族使用 3 断点渐变 + 半透明玻璃按键（`0x99FFFFFF` 系），圆角 14。
- 图片家族背景图为**原创程序化生成**（星穹夜色 / 晨雾云海 / 暮色流光三张，1080×2400）。
- 全部配色均通过 WCAG 对比度校验：键面文字 ≥ 4.5:1、候选选中色 ≥ 3:1（亮暗两种模式）。

## 自定义字体

| 槽位 | 字体 |
|------|------|
| `key_font` 键面主字 | 霞鹜文楷 Medium（略重、辨识度高） |
| `candidate_font` 候选词 | 霞鹜文楷 Regular |
| `comment_font` 候选注释 | 霞鹜文楷 Regular |
| `key_label_font` 字根/标签 | 保留内置 ChaiPUA（兼容五笔字根 / CJK 扩展区） |

字体版权：霞鹜文楷，SIL OFL 1.1，全文见 [NOTICE.md](NOTICE.md)。
注意：因内嵌两款全量中文字体，zip 包体约 46 MB，介意流量的用户请在 Wi-Fi 下下载。

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
xime.custom.yaml        # 11 套配色 + 键盘外观 + 字体槽位（根级，必需）
themes/                 # 背景图 jpg（部署到 rime/themes/）
fonts/                  # 霞鹜文楷 ttf ×2（部署到 rime/fonts/）
NOTICE.md               # 字体/图片版权说明（不随安装部署）
README.md               # 本文件（不随安装部署）
```

## 截图（待补）

安装后自测截图建议：竖屏键盘区（裁掉状态栏 / 导航栏），宽 ≥ 720px，比例 9:16，
单张 ≤ 500KB，命名 `imgN.jpg` 放入 `images/`（建议覆盖三家族各至少一张，亮暗各一）。
索引中的截图 URL 需固定到 tag（如 `xime_theme_pack-1.0.0`），**不要用分支名**。

## 发版流程

1. 修改后更新 `VERSION`（必须递增，否则 CI 检测到内容变化会跳过打包）。
2. 推送分支后发布任一 Release 触发 auto-archive 工作流：自动打 tag `xime_theme_pack-<版本>`，
   上传 `xime.custom.yaml` 与 `xime_theme_pack.zip`（含字体/图片），并在 Release 页生成 sha256 汇总表。
3. 到 xime-index 仓库 `src/layouts/xime_theme_pack.yaml` 顶部新增版本记录
   （downloadUrl 指向 Release 附件 zip），推送后 CI 自动补全 `sha256` / `size`。
