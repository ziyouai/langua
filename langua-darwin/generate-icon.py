#!/usr/bin/env python3
"""
langua 统一图标生成器（与浏览器插件保持完全一致的视觉风格）
产物：
  build/AppIcon.icns          ← macOS App 图标
  build/icons/icon{16,48,128}.png ← Chrome 扩展图标（覆盖 langua-plugin/icons）
"""
import os, subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT   = os.path.dirname(os.path.abspath(__file__))
BUILD  = os.path.join(ROOT, "build")
ICONSET = os.path.join(BUILD, "langua.iconset")
CHROME  = os.path.join(BUILD, "icons")
os.makedirs(ICONSET, exist_ok=True)
os.makedirs(CHROME,  exist_ok=True)

# ── 调色板（与插件 CSS 一致）───────────────────────────────────────────
ACCENT = (126, 232, 250, 255)   # #7ee8fa
WHITE  = (255, 255, 255, 255)

# ── 寻找可用字体（支持中文 + 拉丁附加字符）──────────────────────────
FONT_CANDIDATES = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
    "/System/Library/Fonts/Geneva.ttf",        # 无中文，fallback
]

def load_font(size, bold=False):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                # .ttc 文件有多个字体，index=0 通常是 Regular，1 是 Bold
                idx = 1 if (bold and path.endswith(".ttc")) else 0
                return ImageFont.truetype(path, size, index=idx)
            except Exception:
                continue
    return ImageFont.load_default()

# ── 绘制单张图标 ────────────────────────────────────────────────────────
def make_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # 1) 深蓝渐变背景
    bg = Image.new("RGBA", (size, size))
    draw_bg = ImageDraw.Draw(bg)
    top = (10,  15,  30)    # 接近黑的深蓝
    bot = (18,  38,  75)    # 深蓝
    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        draw_bg.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))

    # 2) 圆角蒙版（半径 ≈ 22.5% → Big Sur squircle 视感）
    radius = max(3, int(size * 0.225))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    img.paste(bg, (0, 0), mask)

    # 3) 文字
    draw = ImageDraw.Draw(img)
    _draw_labels(draw, size)
    return img


def _draw_labels(draw: ImageDraw.ImageDraw, size: int):
    """渲染 pīn（上，青色）和 文（下，白色）"""
    # 字号按尺寸等比缩放（基准 128px）
    pin_size = max(6,  int(size * 0.175))  # ~22px @128
    wen_size = max(10, int(size * 0.430))  # ~55px @128

    pin_font = load_font(pin_size, bold=False)
    wen_font = load_font(wen_size, bold=False)

    cx = size / 2

    # ── "文" 居中，垂直位置约 55% ──────────────────────────────────────
    wen_text = "文"
    wb = draw.textbbox((0, 0), wen_text, font=wen_font)
    ww, wh = wb[2] - wb[0], wb[3] - wb[1]
    wen_x = cx - ww / 2 - wb[0]
    wen_y = size * 0.54 - wh / 2 - wb[1]
    draw.text((wen_x, wen_y), wen_text, font=wen_font, fill=WHITE)

    # ── "pīn" 居中，垂直位置约 24% ──────────────────────────────────────
    pin_text = "pīn"
    pb = draw.textbbox((0, 0), pin_text, font=pin_font)
    pw, ph = pb[2] - pb[0], pb[3] - pb[1]
    pin_x = cx - pw / 2 - pb[0]
    pin_y = size * 0.24 - ph / 2 - pb[1]
    draw.text((pin_x, pin_y), pin_text, font=pin_font, fill=ACCENT)


# ── macOS iconset（所有必须尺寸）───────────────────────────────────────
ICNS_SIZES = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

print("生成 macOS iconset …")
cache: dict[int, Image.Image] = {}
for px, fname in ICNS_SIZES:
    if px not in cache:
        cache[px] = make_icon(px)
    cache[px].save(os.path.join(ICONSET, fname))
print(f"  {len(ICNS_SIZES)} 张写入 {ICONSET}")

icns_path = os.path.join(BUILD, "AppIcon.icns")
r = subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", icns_path],
                   capture_output=True, text=True)
if r.returncode == 0:
    print(f"✅ AppIcon.icns → {icns_path}")
else:
    print(f"❌ iconutil 失败: {r.stderr}")

# ── Chrome 扩展图标 ─────────────────────────────────────────────────────
print("\n生成 Chrome 扩展图标 …")
for px in [16, 48, 128]:
    path = os.path.join(CHROME, f"icon{px}.png")
    if px not in cache:
        cache[px] = make_icon(px)
    cache[px].save(path)
    print(f"  icon{px}.png")

# 直接覆盖插件目录
plugin_icons = os.path.join(ROOT, "../langua-plugin/icons")
if os.path.isdir(plugin_icons):
    for px in [16, 48, 128]:
        dst = os.path.join(plugin_icons, f"icon{px}.png")
        cache[px].save(dst)
    print(f"✅ 已同步到 langua-plugin/icons/")

print("\n完成！")
