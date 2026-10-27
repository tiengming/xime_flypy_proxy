#!/usr/bin/env python3
"""xime 配色对比度检查（xime_flypy_proxy 仓库通用校验脚本）

按 Xime 3.x Android 客户端的实际取色逻辑，复算每个 color_scheme 在亮/暗两种
模式下的关键对比度，低于阈值即失败退出（供 CI/提交前自检）。

已对齐的客户端行为（ximeiorg/Xime main，2026-10 校对）：
  * `color_schemes.<id>.keyboard_background` 为图片时，`keyboardBgLight/Dark`
    取 `keyboard_bg_color`（暗色自动 ×0.7，无 `keyboard_bg_color_dark` 字段）；
    未配置时亮色回退纯白、暗色回退 #1C1B1F。
  * 「展开候选页」用上述纯色兜底画不透明背景（图片/渐变背景均不参与该页），
    候选文字取 `candidate_text_color(_dark)`；因此二者必须成对可读。
  * 普通候选栏背景是**透明**的，露出键盘背景（图片/渐变），文字取候选色；
    `candidate_bar_bg_color` / `candidate_bar_background` 虽能解析但客户端从未
    渲染（死配置），不要依赖。
  * 选中候选胶囊底色 = 强调色 20% 叠在候选栏背景上；强调色亮色用 primary_color，
    暗色自动 lighten(primary, 0.45)。
  * 特殊键（shift/backspace/?123/确定…）暗色底色默认取 primary_color；文字按
    「底色亮度 > 0.5 → 用按键文字色，否则 #E8EAED」选取。
  * 键面色带 alpha（如 0x99FFFFFF）时按 alpha 叠加在键盘背景上再算对比度。

用法：
    python tools/check_colors.py [xime.custom.yaml] [--min-text 4.5] [--min-selected 3.0]

依赖：pyyaml（必需）、Pillow（可选；缺省时图片主题退化为整页兜底色近似）。
退出码：0 全部通过；1 存在不达标项；2 输入文件/依赖错误。
"""
from __future__ import annotations

import argparse
import os
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    print("缺少依赖 pyyaml：pip install pyyaml", file=sys.stderr)
    raise SystemExit(2)

try:  # 图片采样可选
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None


# ── 颜色工具（与客户端一致：0xAARRGGBB / 0xRRGGBB） ──────────────────────────

def parse_color(value) -> tuple[int, int, int, int]:
    if isinstance(value, str):
        value = int(value, 16)
    value = int(value)
    if value <= 0xFFFFFF:
        return 255, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF
    return (value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF


def rgb(value) -> tuple[int, int, int]:
    _, r, g, b = parse_color(value)
    return r, g, b


def _linear(channel: int) -> float:
    c = channel / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(color: tuple[int, int, int]) -> float:
    r, g, b = color[:3]
    return 0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b)


def contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def composite(fg: tuple[int, int, int, int], bg: tuple[int, int, int]) -> tuple[int, int, int]:
    alpha = fg[0] / 255.0
    return tuple(round(alpha * fg[i + 1] + (1 - alpha) * bg[i]) for i in range(3))


def lighten(color: tuple[int, int, int], factor: float = 0.45) -> tuple[int, int, int]:
    return tuple(round(c + (255 - c) * factor) for c in color)


def darken(color: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(round(c * factor) for c in color)


def hex_color(color: tuple[int, int, int]) -> str:
    return "0x%02X%02X%02X" % tuple(color[:3])


def overlay(color: tuple[int, int, int], alpha: float) -> tuple[int, int, int]:
    if not alpha:
        return color
    return tuple(round(c * (1 - alpha)) for c in color)


# ── 图片采样：把键盘区域 fit=cover 映射回图片，取分位数亮度代表值 ─────────────

def image_band(
    path: str,
    band: tuple[int, int, int, int],
    keyboard: tuple[int, int] = (1080, 950),
) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    """返回 band 区域的平均色（近似该区域整体观感）。

    用平均色而不是极值：图片主题的亮斑/暗斑是像素级噪声，配置层无法逐像素修正，
    平均值能反映文字整体压在这张图上的可读性（与人工看截图一致）。
    """
    if Image is None or not os.path.isfile(path):
        return None
    im = Image.open(path).convert("RGB")
    width, height = im.size
    kb_w, kb_h = keyboard
    scale = max(kb_w / width, kb_h / height)
    offset_x = (kb_w - width * scale) / 2.0
    offset_y = (kb_h - height * scale) / 2.0
    x0, y0, x1, y1 = band
    total = [0, 0, 0]
    count = 0
    step = max(1, min(x1 - x0, y1 - y0) // 24)
    for y in range(y0, y1, step):
        iy = min(max(int((y - offset_y) / scale), 0), height - 1)
        for x in range(x0, x1, step):
            ix = min(max(int((x - offset_x) / scale), 0), width - 1)
            pixel = im.getpixel((ix, iy))
            total[0] += pixel[0]
            total[1] += pixel[1]
            total[2] += pixel[2]
            count += 1
    if not count:
        return None
    mean = tuple(round(value / count) for value in total)
    return mean, mean


# ── 单个配色的取色复算 ───────────────────────────────────────────────────────

class Scheme:
    def __init__(self, sid: str, data: dict, globals_: dict, base_dir: str):
        self.id = sid
        self.data = data or {}
        self.globals = globals_ or {}
        self.base_dir = base_dir
        d = self.data
        self.primary = rgb(d.get("primary_color", 0x6750A4))
        self.background = d.get("keyboard_background") or {}
        self.keyboard_bg_flat = d.get("keyboard_bg_color")
        self.key_bg = d.get("key_bg_color")
        self.key_bg_dark = d.get("key_bg_color_dark")
        self.key_text = d.get("key_text_color")
        self.key_text_dark = d.get("key_text_color_dark")
        self.candidate_text = d.get("candidate_text_color")
        self.candidate_text_dark = d.get("candidate_text_color_dark")
        self.selected = d.get("candidate_selected_text_color")
        self.selected_dark = d.get("candidate_selected_text_color_dark")
        self.special = d.get("special_key_bg_color")
        self.special_dark = d.get("special_key_bg_color_dark")

    # 强调色：暗色自动 lighten(primary, 0.45)
    def accent(self, dark: bool) -> tuple[int, int, int]:
        return lighten(self.primary) if dark else self.primary

    # 展开候选页/窗口兜底纯色
    def page_bg(self, dark: bool) -> tuple[int, int, int]:
        kind = self.background.get("type", "solid")
        if kind == "solid":
            value = self.background.get("color_dark") if dark else self.background.get("color")
            value = value if value is not None else self.background.get("color")
            if value is not None:
                return rgb(value)
        elif kind == "gradient":
            colors = self.background.get("colors_dark") if dark else self.background.get("colors")
            colors = colors or self.background.get("colors") or []
            if colors:
                return rgb(colors[0])
        if self.keyboard_bg_flat is not None:
            flat = rgb(self.keyboard_bg_flat)
            return darken(flat, 0.7) if dark else flat
        return (28, 27, 31) if dark else (255, 255, 255)

    # 候选栏可见的背景候选色（渐变各断点 / 图片采样）
    def bar_grid(self, dark: bool) -> list[tuple[int, int, int]]:
        kind = self.background.get("type", "solid")
        if kind == "solid":
            value = self.background.get("color_dark") if dark else self.background.get("color")
            value = value if value is not None else self.background.get("color")
            if value is not None:
                return [rgb(value)]
            return [self.page_bg(dark)]
        if kind == "gradient":
            colors = self.background.get("colors_dark") if dark else self.background.get("colors")
            colors = colors or self.background.get("colors") or []
            return [rgb(c) for c in colors] or [self.page_bg(dark)]

        # image：候选栏区域 = 键盘顶部 0~150px，键面区域 = 其余
        src = (self.background.get("src_dark") or self.background.get("src")) if dark else self.background.get("src")
        alpha = self.background.get("overlay_alpha_dark") if dark else self.background.get("overlay_alpha")
        alpha = alpha or 0.0
        path = os.path.join(self.base_dir, str(src)) if src else ""
        sample = image_band(path, (0, 0, 1080, 150))
        if sample is None:  # 图片缺失：客户端回退纯色兜底
            return [self.page_bg(dark)]
        dark_c, light_c = sample
        return [overlay(dark_c, alpha), overlay(light_c, alpha)]

    def key_grid(self, dark: bool) -> list[tuple[int, int, int]]:
        """键面实际底色：键色（可带 alpha）叠加在键盘背景上。"""
        raw = self.key_bg_dark if dark else self.key_bg
        if raw is None:
            raw = self.globals.get("key_bg_color_dark" if dark else "key_bg_color", 0xFFFFFF)
        fg = parse_color(raw)
        return [composite(fg, bg) for bg in self.background_grid(dark)]

    def background_grid(self, dark: bool) -> list[tuple[int, int, int]]:
        """整块键盘背景：图片按键盘区域采样，渐变取各断点，纯色取该色。"""
        kind = self.background.get("type", "solid")
        if kind == "image":
            src = (self.background.get("src_dark") or self.background.get("src")) if dark else self.background.get("src")
            alpha = self.background.get("overlay_alpha_dark") if dark else self.background.get("overlay_alpha")
            alpha = alpha or 0.0
            path = os.path.join(self.base_dir, str(src)) if src else ""
            sample = image_band(path, (0, 150, 1080, 950))
            if sample is None:
                return [self.page_bg(dark)]
            dark_c, light_c = sample
            return [overlay(dark_c, alpha), overlay(light_c, alpha)]
        if kind == "gradient":
            colors = self.background.get("colors_dark") if dark else self.background.get("colors")
            colors = colors or self.background.get("colors") or []
            return [rgb(c) for c in colors] or [self.page_bg(dark)]
        return [self.page_bg(dark)]

    def candidate(self, dark: bool) -> tuple[int, int, int]:
        value = self.candidate_text_dark if dark else self.candidate_text
        if value is None:
            value = self.globals.get("candidate_text_color_dark" if dark else "candidate_text_color", 0x202124)
        return rgb(value)

    def key_text_color(self, dark: bool) -> tuple[int, int, int]:
        value = self.key_text_dark if dark else self.key_text
        if value is None:
            value = self.globals.get("key_text_color_dark" if dark else "key_text_color", 0x202124)
        return rgb(value)

    def selected_text(self, dark: bool) -> tuple[int, int, int]:
        value = self.selected_dark if dark else self.selected
        if value is not None:
            return rgb(value)
        return self.accent(dark)

    def special_bg(self, dark: bool) -> tuple[int, int, int]:
        if dark:
            if self.special_dark is not None:
                return rgb(self.special_dark)
            return self.primary
        if self.special is not None:
            return rgb(self.special)
        return lighten(self.primary, 0.8)

    def special_text(self, dark: bool) -> tuple[int, int, int]:
        background = self.special_bg(dark)
        if luminance(background) > 0.5:
            return self.key_text_color(dark)
        return (0xE8, 0xEA, 0xED)


def check_scheme(scheme: Scheme, min_text: float, min_selected: float) -> list[tuple[str, str, float, str]]:
    failures: list[tuple[str, str, float, str]] = []
    for dark in (False, True):
        mode = "dark" if dark else "light"
        cand = scheme.candidate(dark)
        page = scheme.page_bg(dark)
        ratio = contrast(cand, page)
        if ratio < min_text:
            failures.append((scheme.id, f"{mode} 展开候选页", ratio,
                             f"文字 {hex_color(cand)} / 底色 {hex_color(page)}"))
        bar = min(contrast(cand, bg) for bg in scheme.bar_grid(dark))
        if bar < min_text:
            failures.append((scheme.id, f"{mode} 候选栏", bar,
                             f"文字 {hex_color(cand)}"))
        key_text = scheme.key_text_color(dark)
        keys = min(contrast(key_text, bg) for bg in scheme.key_grid(dark))
        if keys < min_text:
            failures.append((scheme.id, f"{mode} 键面", keys, f"文字 {hex_color(key_text)}"))
        accent = scheme.accent(dark)
        selected = scheme.selected_text(dark)
        chip = min(
            contrast(selected, tuple(round(0.2 * accent[i] + 0.8 * bg[i]) for i in range(3)))
            for bg in scheme.bar_grid(dark)
        )
        if chip < min_selected:
            failures.append((scheme.id, f"{mode} 候选选中", chip,
                             f"文字 {hex_color(selected)}"))
        special_bg = scheme.special_bg(dark)
        special_text = scheme.special_text(dark)
        special = contrast(special_text, special_bg)
        if special < min_text:
            failures.append((scheme.id, f"{mode} 特殊键", special,
                             f"文字 {hex_color(special_text)} / 底色 {hex_color(special_bg)}"))
    return failures


def main() -> int:
    try:  # Windows 控制台默认 GBK，统一按 UTF-8 输出
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):  # pragma: no cover
        pass
    parser = argparse.ArgumentParser(description="检查 xime.custom.yaml 配色对比度")
    parser.add_argument("yaml", nargs="?", default="xime.custom.yaml", help="配置文件路径")
    parser.add_argument("--min-text", type=float, default=4.5, help="普通文字最低对比度（默认 4.5）")
    parser.add_argument("--min-selected", type=float, default=3.0, help="选中文字最低对比度（默认 3.0）")
    args = parser.parse_args()

    if not os.path.isfile(args.yaml):
        print(f"文件不存在：{args.yaml}", file=sys.stderr)
        return 2
    with open(args.yaml, "r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle) or {}

    schemes = config.get("color_schemes") or {}
    if not schemes:
        print("未找到 color_schemes", file=sys.stderr)
        return 2
    globals_ = ((config.get("keyboard") or {}).get("colors")) or {}
    base_dir = os.path.dirname(os.path.abspath(args.yaml))

    failures: list[tuple[str, str, float, str]] = []
    for sid, data in schemes.items():
        failures.extend(check_scheme(Scheme(sid, data, globals_, base_dir), args.min_text, args.min_selected))

    if Image is None:
        print("提示：未安装 Pillow，图片主题仅按坐标兜底色近似（pip install pillow 可精确采样）",
              file=sys.stderr)

    total = len(schemes) * 2
    if failures:
        print(f"✗ {len(schemes)} 套配色 / {total} 个明暗组合中发现 {len(failures)} 处低于阈值：")
        for sid, where, ratio, detail in sorted(failures, key=lambda item: item[2]):
            print(f"  {sid:20s} {where:14s} {ratio:5.2f}:1   {detail}")
        return 1

    print(f"✓ {len(schemes)} 套配色 / {total} 个明暗组合全部达标"
          f"（文字 ≥{args.min_text}:1，选中 ≥{args.min_selected}:1）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

