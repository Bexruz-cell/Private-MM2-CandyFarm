#!/usr/bin/env python3
"""
generate_prototypes.py
Generates 10 distinct, pixel-perfect mobile gaming UI prototypes as PNG images
for the Private MM2 Candy Farm project, plus a master comparison sheet.
Each mockup has a distinct layout, color palette, and styling with Russian typography.
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = Path(r"C:\Users\soul\Documents\Projects\Private-MM2-CandyFarm\design\prototypes")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

FONT_REGULAR = "C:/Windows/Fonts/segoeui.ttf"
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_SEMIBOLD = "C:/Windows/Fonts/seguisb.ttf"

def get_font(size: int, bold: bool = False):
    try:
        path = FONT_BOLD if bold else FONT_REGULAR
        return ImageFont.truetype(path, size)
    except:
        return ImageFont.load_default()

def draw_rounded_rect(draw: ImageDraw.ImageDraw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

def draw_chamfer_rect(draw: ImageDraw.ImageDraw, xy, cut, fill, outline=None, width=1):
    x0, y0, x1, y1 = xy
    points = [
        (x0 + cut, y0),
        (x1 - cut, y0),
        (x1, y0 + cut),
        (x1, y1 - cut),
        (x1 - cut, y1),
        (x0 + cut, y1),
        (x0, y1 - cut),
        (x0, y0 + cut)
    ]
    draw.polygon(points, fill=fill, outline=outline)
    if outline and width > 1:
        draw.line(points + [points[0]], fill=outline, width=width)

def draw_backdrop(img: Image.Image, theme_tint=(15, 12, 25)):
    # Render simulated dark mobile Roblox game screen (960 x 540)
    draw = ImageDraw.Draw(img)
    w, h = img.size
    
    # Gradient background
    for y in range(h):
        alpha = y / h
        r = int(theme_tint[0] * (1 - alpha * 0.4))
        g = int(theme_tint[1] * (1 - alpha * 0.4))
        b = int(theme_tint[2] * (1 - alpha * 0.4))
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    # Grid lines to simulate 3D game floor
    grid_color = (theme_tint[0] + 10, theme_tint[1] + 10, theme_tint[2] + 15)
    for x in range(0, w, 60):
        draw.line([(x, 320), (x - 80, h)], fill=grid_color, width=1)
    for y in range(320, h, 35):
        draw.line([(0, y), (w, y)], fill=grid_color, width=1)

    # Simulated Mobile Touch joystick hint on bottom left
    draw.ellipse([50, h - 130, 130, h - 50], outline=(60, 60, 80), width=2)
    draw.ellipse([75, h - 105, 105, h - 75], fill=(80, 80, 100))

    # Simulated Jump button hint on bottom right
    draw.ellipse([w - 130, h - 130, w - 50, h - 50], outline=(60, 60, 80), width=2)
    f_jump = get_font(12, bold=True)
    draw.text((w - 97, h - 97), "▲", font=f_jump, fill=(120, 120, 150))

# ==============================================================================
# PROTOTYPE 1: NEBULA PRO (Card-Grid Layout, Dark Purple, Futuristic)
# ==============================================================================
def render_01_nebula_pro():
    img = Image.new("RGBA", (960, 540), (12, 10, 20, 255))
    draw_backdrop(img, (20, 15, 35))
    draw = ImageDraw.Draw(img)

    # Floating HUD Capsule (top-left)
    draw_rounded_rect(draw, (30, 25, 190, 60), radius=18, fill=(28, 20, 48), outline=(147, 51, 234), width=1)
    draw.ellipse([42, 37, 50, 45], fill=(16, 185, 129)) # green live dot
    draw.text((60, 34), "ФАРМ: 28 / 40", font=get_font(13, True), fill=(240, 230, 255))

    # Main Window: 440 x 360 centered-right
    x0, y0, x1, y1 = 280, 70, 740, 470
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=16, fill=(22, 18, 34), outline=(139, 92, 246), width=2)

    # Window Header
    draw_rounded_rect(draw, (x0, y0, x1, y0 + 52), radius=16, fill=(35, 26, 60))
    draw.rectangle([x0, y0 + 35, x1, y0 + 52], fill=(35, 26, 60))
    draw.line([(x0, y0 + 52), (x1, y0 + 52)], fill=(124, 58, 237), width=1)
    draw.text((x0 + 20, y0 + 15), "NEBULA PRO", font=get_font(16, True), fill=(255, 255, 255))
    draw.text((x0 + 140, y0 + 18), "— Candy Farm MM2", font=get_font(12, False), fill=(196, 181, 253))
    
    # Header icons
    draw_rounded_rect(draw, (x1 - 70, y0 + 14, x1 - 46, y0 + 38), radius=6, fill=(48, 38, 78))
    draw.text((x1 - 62, y0 + 17), "—", font=get_font(14, True), fill=(216, 180, 254))
    draw_rounded_rect(draw, (x1 - 38, y0 + 14, x1 - 14, y0 + 38), radius=6, fill=(60, 25, 35))
    draw.text((x1 - 30, y0 + 18), "✕", font=get_font(12, True), fill=(248, 113, 113))

    # Status Pill inside card
    draw_rounded_rect(draw, (x0 + 20, y0 + 66, x1 - 20, y0 + 110), radius=10, fill=(30, 24, 46), outline=(91, 33, 182), width=1)
    draw.ellipse([x0 + 34, y0 + 82, x0 + 44, y0 + 92], fill=(16, 185, 129))
    draw.text((x0 + 52, y0 + 74), "Статус: Сбор конфет", font=get_font(13, True), fill=(255, 255, 255))
    draw.text((x0 + 52, y0 + 91), "Движение к цели • Скорость 32 ст/с", font=get_font(10, False), fill=(167, 139, 250))

    # 4 Metric Cards (2x2 Grid)
    # Card 1: Bag
    draw_rounded_rect(draw, (x0 + 20, y0 + 120, x0 + 220, y0 + 190), radius=10, fill=(28, 22, 44), outline=(76, 29, 149), width=1)
    draw.text((x0 + 32, y0 + 128), "В СУМКЕ", font=get_font(10, True), fill=(167, 139, 250))
    draw.text((x0 + 32, y0 + 144), "28 / 40", font=get_font(20, True), fill=(255, 255, 255))
    # progress mini bar
    draw_rounded_rect(draw, (x0 + 32, y0 + 174, x0 + 208, y0 + 180), radius=3, fill=(45, 35, 70))
    draw_rounded_rect(draw, (x0 + 32, y0 + 174, x0 + 155, y0 + 180), radius=3, fill=(168, 85, 247))

    # Card 2: Total Collected
    draw_rounded_rect(draw, (x0 + 240, y0 + 120, x1 - 20, y0 + 190), radius=10, fill=(28, 22, 44), outline=(76, 29, 149), width=1)
    draw.text((x0 + 252, y0 + 128), "ВСЕГО СОБРАНО", font=get_font(10, True), fill=(167, 139, 250))
    draw.text((x0 + 252, y0 + 144), "184 шт.", font=get_font(20, True), fill=(250, 204, 21))

    # Card 3: Round Status
    draw_rounded_rect(draw, (x0 + 20, y0 + 200, x0 + 220, y0 + 265), radius=10, fill=(28, 22, 44), outline=(76, 29, 149), width=1)
    draw.text((x0 + 32, y0 + 208), "РАУНД", font=get_font(10, True), fill=(167, 139, 250))
    draw.text((x0 + 32, y0 + 224), "Mansion (Идёт)", font=get_font(13, True), fill=(52, 211, 153))
    draw.text((x0 + 32, y0 + 242), "Осталось: 01:42", font=get_font(10, False), fill=(148, 163, 184))

    # Card 4: FPS & Engine
    draw_rounded_rect(draw, (x0 + 240, y0 + 200, x1 - 20, y0 + 265), radius=10, fill=(28, 22, 44), outline=(76, 29, 149), width=1)
    draw.text((x0 + 252, y0 + 208), "ПРОИЗВОДИТЕЛЬНОСТЬ", font=get_font(10, True), fill=(167, 139, 250))
    draw.text((x0 + 252, y0 + 224), "59.8 FPS", font=get_font(16, True), fill=(56, 189, 248))
    draw.text((x0 + 252, y0 + 242), "Высокий FPS: ВКЛ", font=get_font(10, True), fill=(74, 222, 128))

    # Settings Row: High FPS Toggle & Speed Segment
    draw_rounded_rect(draw, (x0 + 20, y0 + 275, x1 - 20, y0 + 325), radius=10, fill=(32, 26, 50))
    draw.text((x0 + 32, y0 + 291), "ВЫСОКИЙ FPS", font=get_font(12, True), fill=(240, 230, 255))
    # Toggle switch
    draw_rounded_rect(draw, (x0 + 150, y0 + 287, x0 + 195, y0 + 313), radius=13, fill=(16, 185, 129))
    draw.ellipse([x0 + 172, y0 + 289, x0 + 193, y0 + 311], fill=(255, 255, 255))
    draw.text((x0 + 220, y0 + 291), "Скорость: 32 ст/с", font=get_font(11, False), fill=(200, 190, 225))

    # Bottom Primary Action Button
    draw_rounded_rect(draw, (x0 + 20, y0 + 338, x1 - 20, y0 + 385), radius=12, fill=(220, 38, 38), outline=(248, 113, 113), width=1)
    draw.text((x0 + 180, y0 + 351), "■ ОСТАНОВИТЬ", font=get_font(15, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "01_nebula_pro.png")

# ==============================================================================
# PROTOTYPE 2: OBSIDIAN (Ultra-Minimal Monolithic Slab, Premium Black)
# ==============================================================================
def render_02_obsidian():
    img = Image.new("RGBA", (960, 540), (8, 8, 10, 255))
    draw_backdrop(img, (12, 12, 14))
    draw = ImageDraw.Draw(img)

    # Floating HUD Pill
    draw_rounded_rect(draw, (30, 25, 180, 62), radius=8, fill=(16, 16, 20), outline=(50, 50, 60), width=1)
    draw.ellipse([44, 38, 52, 46], fill=(255, 255, 255))
    draw.text((62, 35), "CANDY 28/40", font=get_font(12, True), fill=(240, 240, 240))

    # Main Window: 430 x 370
    x0, y0, x1, y1 = 280, 65, 730, 475
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=8, fill=(14, 14, 18), outline=(45, 45, 55), width=2)

    # Minimal Header
    draw.line([(x0, y0 + 48), (x1, y0 + 48)], fill=(35, 35, 45), width=1)
    draw.text((x0 + 24, y0 + 16), "OBSIDIAN", font=get_font(15, True), fill=(255, 255, 255))
    draw.text((x0 + 105, y0 + 18), "v2.0 • МИНИМАЛИЗМ", font=get_font(11, False), fill=(140, 140, 150))
    draw.text((x1 - 40, y0 + 15), "—", font=get_font(14, True), fill=(160, 160, 170))

    # Linear Status Bar
    draw.rectangle([x0 + 24, y0 + 64, x1 - 24, y0 + 94], fill=(20, 20, 26))
    draw.ellipse([x0 + 36, y0 + 75, x0 + 44, y0 + 83], fill=(16, 185, 129))
    draw.text((x0 + 52, y0 + 71), "АКТИВЕН • СБОР КОНФЕТ В МАРКЕТЕ", font=get_font(11, True), fill=(220, 220, 220))

    # Huge Centered Metric Bar
    draw.text((x0 + 24, y0 + 115), "ПРОГРЕСС СБОРА", font=get_font(11, True), fill=(120, 120, 130))
    draw.text((x0 + 24, y0 + 135), "28", font=get_font(38, True), fill=(255, 255, 255))
    draw.text((x0 + 75, y0 + 150), "/ 40 КОНФЕТ (70%)", font=get_font(14, False), fill=(150, 150, 160))

    # Ultra-sleek segmented Progress Bar
    bar_y = y0 + 195
    seg_w = (x1 - x0 - 48 - 38) // 40
    for i in range(40):
        bx = x0 + 24 + i * (seg_w + 1)
        fill = (240, 240, 250) if i < 28 else (35, 35, 42)
        draw.rectangle([bx, bar_y, bx + seg_w, bar_y + 12], fill=fill)

    # 3 Flat Data Columns
    col_y = y0 + 225
    draw.text((x0 + 24, col_y), "ВСЕГО", font=get_font(10, True), fill=(110, 110, 120))
    draw.text((x0 + 24, col_y + 16), "184 шт.", font=get_font(14, True), fill=(230, 230, 230))

    draw.text((x0 + 160, col_y), "КАРТА", font=get_font(10, True), fill=(110, 110, 120))
    draw.text((x0 + 160, col_y + 16), "Workplace", font=get_font(14, True), fill=(230, 230, 230))

    draw.text((x0 + 310, col_y), "FPS", font=get_font(10, True), fill=(110, 110, 120))
    draw.text((x0 + 310, col_y + 16), "60.0", font=get_font(14, True), fill=(230, 230, 230))

    # Minimal Toggle Row
    draw.line([(x0 + 24, y0 + 275), (x1 - 24, y0 + 275)], fill=(30, 30, 38), width=1)
    draw.text((x0 + 24, y0 + 290), "РЕЖИМ ВЫСОКОГО FPS", font=get_font(11, True), fill=(200, 200, 210))
    draw_rounded_rect(draw, (x1 - 80, y0 + 287, x1 - 35, y0 + 307), radius=10, fill=(240, 240, 240))
    draw.ellipse([x1 - 53, y0 + 289, x1 - 37, y0 + 305], fill=(15, 15, 18))

    draw.text((x0 + 24, y0 + 325), "СКОРОСТЬ ПЕРЕДВИЖЕНИЯ", font=get_font(11, True), fill=(200, 200, 210))
    draw.text((x1 - 95, y0 + 325), "32 STUDS/S", font=get_font(11, True), fill=(240, 240, 240))

    # Dual Action Buttons
    btn_y = y0 + 355
    draw.rectangle([x0 + 24, btn_y, x0 + 220, btn_y + 42], fill=(240, 240, 240))
    draw.text((x0 + 85, btn_y + 13), "СТОП", font=get_font(13, True), fill=(10, 10, 12))

    draw.rectangle([x0 + 235, btn_y, x1 - 24, btn_y + 42], fill=(22, 22, 28), outline=(60, 60, 75))
    draw.text((x0 + 285, btn_y + 13), "ПАРАМЕТРЫ", font=get_font(13, True), fill=(210, 210, 220))

    img.save(OUTPUT_DIR / "02_obsidian.png")

# ==============================================================================
# PROTOTYPE 3: CYBER VIOLET (Gaming HUD, Chamfered Edges, Glowing Accents)
# ==============================================================================
def render_03_cyber_violet():
    img = Image.new("RGBA", (960, 540), (10, 8, 18, 255))
    draw_backdrop(img, (22, 14, 38))
    draw = ImageDraw.Draw(img)

    # Angular HUD Pill
    draw_chamfer_rect(draw, (30, 25, 200, 65), cut=8, fill=(25, 15, 45), outline=(192, 132, 252), width=2)
    draw.text((45, 36), "HUD: FARM 28/40", font=get_font(12, True), fill=(230, 200, 255))
    draw.rectangle([170, 38, 185, 52], fill=(16, 185, 129))

    # Angular Main Window: 450 x 380
    x0, y0, x1, y1 = 260, 60, 740, 480
    draw_chamfer_rect(draw, (x0, y0, x1, y1), cut=14, fill=(16, 12, 28), outline=(168, 85, 247), width=2)

    # Top Cyber Header
    draw_chamfer_rect(draw, (x0, y0, x1, y0 + 48), cut=14, fill=(35, 20, 65), outline=(192, 132, 252), width=1)
    draw.text((x0 + 25, y0 + 14), "// CYBER VIOLET HUD", font=get_font(15, True), fill=(245, 230, 255))
    draw.text((x1 - 100, y0 + 16), "[60.2 FPS]", font=get_font(12, True), fill=(52, 211, 153))

    # Circular Dial Gauge simulation on Left Side (140x140)
    cx, cy, r = x0 + 85, y0 + 130, 52
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(45, 30, 75), width=10)
    # 70% arc
    draw.arc([cx - r, cy - r, cx + r, cy + r], start=-90, end=162, fill=(192, 132, 252), width=10)
    draw.text((cx - 24, cy - 18), "70%", font=get_font(18, True), fill=(255, 255, 255))
    draw.text((cx - 26, cy + 8), "28 / 40", font=get_font(10, True), fill=(196, 181, 253))

    # Right side metrics
    rx = x0 + 160
    draw_chamfer_rect(draw, (rx, y0 + 68, x1 - 25, y0 + 120), cut=8, fill=(28, 18, 50), outline=(124, 58, 237), width=1)
    draw.text((rx + 15, y0 + 76), "СТАТУС СИСТЕМЫ", font=get_font(9, True), fill=(167, 139, 250))
    draw.text((rx + 15, y0 + 92), "● СБОР КОНФЕТ [АКТИВЕН]", font=get_font(12, True), fill=(74, 222, 128))

    draw_chamfer_rect(draw, (rx, y0 + 130, x1 - 25, y0 + 182), cut=8, fill=(28, 18, 50), outline=(124, 58, 237), width=1)
    draw.text((rx + 15, y0 + 138), "ЛОКАЦИЯ И РАУНД", font=get_font(9, True), fill=(167, 139, 250))
    draw.text((rx + 15, y0 + 154), "Research Facility • Идёт раунд", font=get_font(12, True), fill=(245, 230, 255))

    # Middle Control Deck
    deck_y = y0 + 200
    draw_chamfer_rect(draw, (x0 + 25, deck_y, x1 - 25, deck_y + 110), cut=10, fill=(24, 16, 42), outline=(91, 33, 182), width=1)
    
    draw.text((x0 + 40, deck_y + 16), "ВЫСОКИЙ FPS (TURBO)", font=get_font(12, True), fill=(245, 230, 255))
    draw_chamfer_rect(draw, (x1 - 110, deck_y + 12, x1 - 40, deck_y + 36), cut=6, fill=(16, 185, 129))
    draw.text((x1 - 92, deck_y + 16), "ВКЛ", font=get_font(11, True), fill=(255, 255, 255))

    draw.text((x0 + 40, deck_y + 55), "СКОРОСТЬ ВСПЛЫТИЯ / TWEEN", font=get_font(12, True), fill=(245, 230, 255))
    # 3 segment buttons
    draw_chamfer_rect(draw, (x0 + 40, deck_y + 75, x0 + 130, deck_y + 98), cut=5, fill=(45, 30, 75))
    draw.text((x0 + 55, deck_y + 80), "28 ст/с", font=get_font(10, True), fill=(196, 181, 253))

    draw_chamfer_rect(draw, (x0 + 140, deck_y + 75, x0 + 230, deck_y + 98), cut=5, fill=(168, 85, 247))
    draw.text((x0 + 155, deck_y + 80), "32 ст/с (★)", font=get_font(10, True), fill=(255, 255, 255))

    draw_chamfer_rect(draw, (x0 + 240, deck_y + 75, x0 + 330, deck_y + 98), cut=5, fill=(45, 30, 75))
    draw.text((x0 + 255, deck_y + 80), "38 ст/с", font=get_font(10, True), fill=(196, 181, 253))

    # Bottom Cyber Action Pad
    pad_y = y0 + 325
    draw_chamfer_rect(draw, (x0 + 25, pad_y, x1 - 25, pad_y + 50), cut=10, fill=(220, 38, 38), outline=(248, 113, 113), width=2)
    draw.text((x0 + 175, pad_y + 16), "[ СТОП СИСТЕМЫ ]", font=get_font(14, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "03_cyber_violet.png")

# ==============================================================================
# PROTOTYPE 4: LIQUID GLASS (Translucent Layered Panels, Frosted Glass)
# ==============================================================================
def render_04_liquid_glass():
    img = Image.new("RGBA", (960, 540), (14, 18, 28, 255))
    draw_backdrop(img, (20, 25, 45))
    draw = ImageDraw.Draw(img)

    # Floating Glass Pill
    draw_rounded_rect(draw, (30, 25, 195, 62), radius=16, fill=(40, 55, 90, 190), outline=(147, 197, 253, 180), width=1)
    draw.text((50, 36), "🍬 28 / 40 • GLOW", font=get_font(12, True), fill=(240, 248, 255))

    # Translucent Main Glass Container
    x0, y0, x1, y1 = 270, 60, 730, 480
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=22, fill=(25, 35, 60), outline=(191, 219, 254), width=2)

    # Inner Glass Shine
    draw_rounded_rect(draw, (x0 + 4, y0 + 4, x1 - 4, y0 + 55), radius=20, fill=(45, 60, 100))
    draw.text((x0 + 25, y0 + 18), "LIQUID GLASS", font=get_font(16, True), fill=(255, 255, 255))
    draw.text((x0 + 155, y0 + 21), "— Прозрачный интерфейс", font=get_font(11, False), fill=(186, 230, 253))

    # Glass Card 1: Status Banner
    draw_rounded_rect(draw, (x0 + 20, y0 + 72, x1 - 20, y0 + 125), radius=14, fill=(35, 50, 85), outline=(125, 211, 252), width=1)
    draw.ellipse([x0 + 36, y0 + 94, x0 + 46, y0 + 104], fill=(52, 211, 153))
    draw.text((x0 + 56, y0 + 85), "СТАТУС: СБОР КОНФЕТ", font=get_font(13, True), fill=(255, 255, 255))
    draw.text((x0 + 56, y0 + 104), "В игре • Раунд активен • Нет препятствий", font=get_font(10, False), fill=(186, 230, 253))

    # Glass Card 2: Big Counter with Frosted Progress Ring/Bar
    draw_rounded_rect(draw, (x0 + 20, y0 + 138, x1 - 20, y0 + 235), radius=14, fill=(30, 45, 75), outline=(96, 165, 250), width=1)
    draw.text((x0 + 35, y0 + 150), "ВМЕСТИМОСТЬ СУМКИ", font=get_font(11, True), fill=(147, 197, 253))
    draw.text((x0 + 35, y0 + 170), "28 / 40", font=get_font(32, True), fill=(255, 255, 255))
    draw.text((x0 + 175, y0 + 185), "КОНФЕТ СОБРАНО В СЕССИИ: 184", font=get_font(10, True), fill=(224, 242, 254))
    
    # Smooth Frosted Glass Bar
    draw_rounded_rect(draw, (x0 + 35, y0 + 214, x1 - 35, y0 + 224), radius=5, fill=(20, 30, 50))
    draw_rounded_rect(draw, (x0 + 35, y0 + 214, x0 + 35 + int((x1 - x0 - 70) * 0.7), y0 + 224), radius=5, fill=(56, 189, 248))

    # Glass Card 3: High FPS & Telemetry
    draw_rounded_rect(draw, (x0 + 20, y0 + 248, x1 - 20, y0 + 330), radius=14, fill=(30, 45, 75), outline=(96, 165, 250), width=1)
    draw.text((x0 + 35, y0 + 262), "ВЫСОКИЙ FPS (ОПТИМИЗАЦИЯ)", font=get_font(11, True), fill=(255, 255, 255))
    draw.text((x0 + 35, y0 + 280), "Удаление лишних частиц и теней", font=get_font(10, False), fill=(147, 197, 253))
    # Glass toggle switch
    draw_rounded_rect(draw, (x1 - 85, y0 + 265, x1 - 35, y0 + 293), radius=14, fill=(14, 165, 233))
    draw.ellipse([x1 - 58, y0 + 268, x1 - 38, y0 + 290], fill=(255, 255, 255))

    draw.text((x0 + 35, y0 + 305), "Текущая частота: 60.1 FPS • Скорость: 32 ст/с", font=get_font(10, True), fill=(186, 230, 253))

    # Glass Primary Button
    draw_rounded_rect(draw, (x0 + 20, y0 + 345, x1 - 20, y0 + 398), radius=14, fill=(239, 68, 68), outline=(252, 165, 165), width=2)
    draw.text((x0 + 175, y0 + 360), "ОСТАНОВИТЬ СБОР", font=get_font(13, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "04_liquid_glass.png")

# ==============================================================================
# PROTOTYPE 5: PHANTOM (Dark Red & Black, Tactical Gaming UI)
# ==============================================================================
def render_05_phantom():
    img = Image.new("RGBA", (960, 540), (12, 8, 8, 255))
    draw_backdrop(img, (25, 10, 10))
    draw = ImageDraw.Draw(img)

    # Tactical Pill
    draw_chamfer_rect(draw, (30, 25, 190, 62), cut=6, fill=(35, 12, 12), outline=(239, 68, 68), width=2)
    draw.text((45, 36), "[PHANTOM: 28/40]", font=get_font(11, True), fill=(254, 202, 202))

    # Main Tactical Frame: 450 x 380
    x0, y0, x1, y1 = 260, 60, 740, 480
    draw_chamfer_rect(draw, (x0, y0, x1, y1), cut=12, fill=(18, 12, 12), outline=(220, 38, 38), width=2)

    # Tactical Header with Top Tabs
    draw.rectangle([x0, y0, x1, y0 + 44], fill=(32, 14, 14))
    draw.line([(x0, y0 + 44), (x1, y0 + 44)], fill=(185, 28, 28), width=1)
    draw.text((x0 + 20, y0 + 14), "PHANTOM TACTICAL v2.0", font=get_font(14, True), fill=(255, 255, 255))
    
    # 3 Top Tabs: [БОЙ] [НАСТРОЙКИ] [СЕТЬ]
    draw.rectangle([x1 - 190, y0 + 10, x1 - 135, y0 + 34], fill=(220, 38, 38))
    draw.text((x1 - 180, y0 + 15), "ФАРМ", font=get_font(10, True), fill=(255, 255, 255))
    draw.rectangle([x1 - 130, y0 + 10, x1 - 65, y0 + 34], fill=(40, 16, 16))
    draw.text((x1 - 122, y0 + 15), "ОПЦИИ", font=get_font(10, True), fill=(200, 160, 160))

    # Crosshair tactical telemetry box
    draw.rectangle([x0 + 20, y0 + 58, x1 - 20, y0 + 105], fill=(28, 15, 15), outline=(153, 27, 27))
    draw.text((x0 + 30, y0 + 66), "ТАКТИЧЕСКИЙ СТАТУС: СБОР ЦЕЛЕЙ", font=get_font(12, True), fill=(248, 113, 113))
    draw.text((x0 + 30, y0 + 85), "ДИСТАНЦИЯ: 14.2 СТАДОВ • ПЕРЕМЕЩЕНИЕ ЧЕРЕЗ СТЕНЫ", font=get_font(9, False), fill=(252, 165, 165))

    # Main Target Counter Grid
    draw.rectangle([x0 + 20, y0 + 115, x0 + 220, y0 + 195], fill=(24, 14, 14), outline=(127, 29, 29))
    draw.text((x0 + 30, y0 + 125), "ОБНАРУЖЕНО ЦЕЛЕЙ", font=get_font(10, True), fill=(239, 68, 68))
    draw.text((x0 + 30, y0 + 145), "28 / 40", font=get_font(26, True), fill=(255, 255, 255))
    draw.text((x0 + 30, y0 + 175), "ЗАПОЛНЕНИЕ: 70%", font=get_font(9, True), fill=(200, 150, 150))

    draw.rectangle([x0 + 235, y0 + 115, x1 - 20, y0 + 195], fill=(24, 14, 14), outline=(127, 29, 29))
    draw.text((x0 + 245, y0 + 125), "СЕССИЯ И РАУНД", font=get_font(10, True), fill=(239, 68, 68))
    draw.text((x0 + 245, y0 + 145), "184 КОНФ.", font=get_font(24, True), fill=(254, 202, 202))
    draw.text((x0 + 245, y0 + 175), "РАУНД: Mansion (АКТИВЕН)", font=get_font(9, True), fill=(74, 222, 128))

    # High FPS Tactical Switch
    draw.rectangle([x0 + 20, y0 + 208, x1 - 20, y0 + 260], fill=(26, 14, 14), outline=(127, 29, 29))
    draw.text((x0 + 30, y0 + 222), "ВЫСОКИЙ FPS (БУСТЕР КАДРОВ)", font=get_font(11, True), fill=(255, 255, 255))
    draw.rectangle([x1 - 90, y0 + 218, x1 - 35, y0 + 248], fill=(220, 38, 38))
    draw.text((x1 - 78, y0 + 226), "ВКЛ", font=get_font(11, True), fill=(255, 255, 255))

    # Movement Speed Control
    draw.rectangle([x0 + 20, y0 + 272, x1 - 20, y0 + 325], fill=(26, 14, 14), outline=(127, 29, 29))
    draw.text((x0 + 30, y0 + 286), "РЕЖИМ СКОРОСТИ: 32 СТАД/СЕК (БЕЗОПАСНЫЙ)", font=get_font(11, True), fill=(255, 255, 255))

    # Tactical Wide Abort Trigger
    draw.rectangle([x0 + 20, y0 + 340, x1 - 20, y0 + 395], fill=(185, 28, 28), outline=(239, 68, 68), width=2)
    draw.text((x0 + 175, y0 + 357), "■ ОСТАНОВИТЬ ОПЕРАЦИЮ", font=get_font(13, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "05_phantom.png")

# ==============================================================================
# PROTOTYPE 6: AURORA (Dark Blue & Cyan, Soft Gradients, Organic Wave)
# ==============================================================================
def render_06_aurora():
    img = Image.new("RGBA", (960, 540), (8, 14, 25, 255))
    draw_backdrop(img, (12, 24, 45))
    draw = ImageDraw.Draw(img)

    # Aurora Pill
    draw_rounded_rect(draw, (30, 25, 190, 62), radius=16, fill=(16, 35, 60), outline=(56, 189, 248), width=2)
    draw.ellipse([45, 38, 53, 46], fill=(45, 212, 191))
    draw.text((62, 35), "AURORA: 28/40", font=get_font(12, True), fill=(224, 242, 254))

    # Main Aurora Container: 440 x 370
    x0, y0, x1, y1 = 270, 65, 730, 475
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=18, fill=(14, 26, 46), outline=(45, 212, 191), width=2)

    # Header with soft cyan accent
    draw_rounded_rect(draw, (x0, y0, x1, y0 + 50), radius=18, fill=(20, 40, 70))
    draw.rectangle([x0, y0 + 35, x1, y0 + 50], fill=(20, 40, 70))
    draw.text((x0 + 24, y0 + 16), "AURORA ENGINE", font=get_font(15, True), fill=(255, 255, 255))
    draw.text((x0 + 160, y0 + 19), "• Плавный сбор", font=get_font(11, False), fill=(153, 246, 228))

    # Soft Metric Chips
    draw_rounded_rect(draw, (x0 + 20, y0 + 65, x1 - 20, y0 + 115), radius=12, fill=(22, 42, 74))
    draw.text((x0 + 35, y0 + 76), "ТЕКУЩИЙ СТАТУС", font=get_font(10, True), fill=(94, 234, 212))
    draw.text((x0 + 35, y0 + 92), "Сбор конфет • Карта активна", font=get_font(13, True), fill=(255, 255, 255))

    # Wave Progress Card
    draw_rounded_rect(draw, (x0 + 20, y0 + 128, x1 - 20, y0 + 225), radius=14, fill=(18, 34, 60), outline=(20, 184, 166), width=1)
    draw.text((x0 + 35, y0 + 140), "НАКОПЛЕНО В СУМКЕ", font=get_font(11, True), fill=(153, 246, 228))
    draw.text((x0 + 35, y0 + 160), "28 / 40", font=get_font(34, True), fill=(255, 255, 255))
    draw.text((x0 + 210, y0 + 175), "Собрано за раунд: 12 шт.", font=get_font(11, False), fill=(204, 251, 241))
    
    # Cyan Wave Bar
    draw_rounded_rect(draw, (x0 + 35, y0 + 204, x1 - 35, y0 + 214), radius=5, fill=(10, 20, 36))
    draw_rounded_rect(draw, (x0 + 35, y0 + 204, x0 + 35 + int((x1 - x0 - 70) * 0.7), y0 + 214), radius=5, fill=(45, 212, 191))

    # Settings Cards
    draw_rounded_rect(draw, (x0 + 20, y0 + 238, x1 - 20, y0 + 290), radius=12, fill=(22, 42, 74))
    draw.text((x0 + 35, y0 + 252), "ВЫСОКИЙ FPS (МЯГКИЙ РЕЖИМ)", font=get_font(11, True), fill=(255, 255, 255))
    draw_rounded_rect(draw, (x1 - 85, y0 + 248, x1 - 35, y0 + 276), radius=14, fill=(20, 184, 166))
    draw.ellipse([x1 - 58, y0 + 251, x1 - 38, y0 + 273], fill=(255, 255, 255))

    draw_rounded_rect(draw, (x0 + 20, y0 + 300, x1 - 20, y0 + 345), radius=12, fill=(22, 42, 74))
    draw.text((x0 + 35, y0 + 314), "Скорость перемещения: 32 ст/с • Пинг: 42мс", font=get_font(11, False), fill=(204, 251, 241))

    # Bottom Aurora Button
    draw_rounded_rect(draw, (x0 + 20, y0 + 358, x1 - 20, y0 + 400), radius=12, fill=(225, 29, 72), outline=(251, 113, 133))
    draw.text((x0 + 175, y0 + 370), "ОСТАНОВИТЬ СБОР", font=get_font(13, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "06_aurora.png")

# ==============================================================================
# PROTOTYPE 7: MONARCH (Black & Gold, Luxury Interface)
# ==============================================================================
def render_07_monarch():
    img = Image.new("RGBA", (960, 540), (10, 10, 12, 255))
    draw_backdrop(img, (20, 18, 14))
    draw = ImageDraw.Draw(img)

    # Gold Crown Pill
    draw_rounded_rect(draw, (30, 25, 190, 62), radius=10, fill=(25, 22, 16), outline=(217, 119, 6), width=2)
    draw.text((45, 36), "♦ MONARCH: 28/40", font=get_font(12, True), fill=(253, 230, 138))

    # Main Luxury Box: 440 x 380
    x0, y0, x1, y1 = 270, 60, 730, 480
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=10, fill=(18, 16, 14), outline=(245, 158, 11), width=2)

    # Gold Filigree Header
    draw.rectangle([x0, y0, x1, y0 + 48], fill=(30, 26, 20))
    draw.line([(x0, y0 + 48), (x1, y0 + 48)], fill=(217, 119, 6), width=1)
    draw.text((x0 + 24, y0 + 15), "MONARCH EDITION", font=get_font(16, True), fill=(253, 230, 138))
    draw.text((x1 - 100, y0 + 18), "ЗОЛОТОЙ ФАРМ", font=get_font(10, True), fill=(251, 191, 36))

    # Gold Status Banner
    draw_rounded_rect(draw, (x0 + 20, y0 + 65, x1 - 20, y0 + 115), radius=8, fill=(26, 22, 18), outline=(180, 83, 9), width=1)
    draw.text((x0 + 35, y0 + 76), "СТАТУС КОЛЛЕКЦИИ", font=get_font(10, True), fill=(251, 191, 36))
    draw.text((x0 + 35, y0 + 92), "Сбор конфет активен • Безопасный режим", font=get_font(13, True), fill=(255, 255, 255))

    # Massive Golden Stat Card
    draw_rounded_rect(draw, (x0 + 20, y0 + 128, x1 - 20, y0 + 225), radius=8, fill=(24, 20, 16), outline=(217, 119, 6), width=1)
    draw.text((x0 + 35, y0 + 140), "КОНФЕТ В КОЛЛЕКЦИИ", font=get_font(11, True), fill=(252, 211, 77))
    draw.text((x0 + 35, y0 + 160), "28 / 40", font=get_font(34, True), fill=(255, 255, 255))
    draw.text((x0 + 210, y0 + 175), "Всего золотых конфет: 184", font=get_font(11, True), fill=(253, 230, 138))
    
    # Gold Inlaid Progress Bar
    draw.rectangle([x0 + 35, y0 + 204, x1 - 35, y0 + 214], fill=(35, 30, 22))
    draw.rectangle([x0 + 35, y0 + 204, x0 + 35 + int((x1 - x0 - 70) * 0.7), y0 + 214], fill=(245, 158, 11))

    # High FPS Golden Switch
    draw_rounded_rect(draw, (x0 + 20, y0 + 240, x1 - 20, y0 + 295), radius=8, fill=(26, 22, 18), outline=(180, 83, 9))
    draw.text((x0 + 35, y0 + 255), "РЕЖИМ ВЫСОКОГО FPS", font=get_font(12, True), fill=(255, 255, 255))
    draw.text((x0 + 35, y0 + 273), "Текущая частота: 60 FPS", font=get_font(10, False), fill=(217, 119, 6))
    draw_rounded_rect(draw, (x1 - 85, y0 + 252, x1 - 35, y0 + 280), radius=14, fill=(245, 158, 11))
    draw.ellipse([x1 - 58, y0 + 255, x1 - 38, y0 + 277], fill=(20, 16, 12))

    # Settings Row
    draw.text((x0 + 35, y0 + 312), "Скорость: 32 ст/с • Премиум защита", font=get_font(11, True), fill=(253, 230, 138))

    # Golden Action Trigger
    draw_rounded_rect(draw, (x0 + 20, y0 + 342, x1 - 20, y0 + 395), radius=8, fill=(185, 28, 28), outline=(239, 68, 68), width=2)
    draw.text((x0 + 175, y0 + 360), "■ ПРИОСТАНОВИТЬ", font=get_font(13, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "07_monarch.png")

# ==============================================================================
# PROTOTYPE 8: NEXUS (Futuristic 3-Column Modular Dashboard)
# ==============================================================================
def render_08_nexus():
    img = Image.new("RGBA", (960, 540), (10, 14, 20, 255))
    draw_backdrop(img, (15, 22, 34))
    draw = ImageDraw.Draw(img)

    # Mini Nexus Pill
    draw_rounded_rect(draw, (30, 25, 180, 62), radius=8, fill=(20, 28, 42), outline=(56, 189, 248), width=1)
    draw.text((45, 36), "NEXUS: 28/40", font=get_font(12, True), fill=(224, 242, 254))

    # Main Window: 520 x 360 (Wide 3-Column)
    x0, y0, x1, y1 = 220, 70, 760, 470
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=12, fill=(16, 22, 34), outline=(14, 165, 233), width=2)

    # Top Modular Header
    draw.rectangle([x0, y0, x1, y0 + 44], fill=(24, 34, 52))
    draw.line([(x0, y0 + 44), (x1, y0 + 44)], fill=(14, 165, 233), width=1)
    draw.text((x0 + 20, y0 + 14), "NEXUS MODULAR DASHBOARD", font=get_font(14, True), fill=(255, 255, 255))
    draw.text((x1 - 110, y0 + 16), "STATUS: OK", font=get_font(11, True), fill=(52, 211, 153))

    # Column 1: Left Quick Controls (150w)
    c1_x0, c1_x1 = x0 + 15, x0 + 165
    draw_rounded_rect(draw, (c1_x0, y0 + 58, c1_x1, y0 + 175), radius=8, fill=(20, 30, 48))
    draw.text((c1_x0 + 12, y0 + 68), "ВЫСОКИЙ FPS", font=get_font(10, True), fill=(147, 197, 253))
    draw_rounded_rect(draw, (c1_x0 + 12, y0 + 88, c1_x1 - 12, y0 + 115), radius=6, fill=(16, 185, 129))
    draw.text((c1_x0 + 45, y0 + 94), "ВКЛЮЧЁН", font=get_font(10, True), fill=(255, 255, 255))
    draw.text((c1_x0 + 12, y0 + 130), "СКОРОСТЬ: 32", font=get_font(10, True), fill=(147, 197, 253))
    draw.text((c1_x0 + 12, y0 + 150), "ПИНГ: 38 мс", font=get_font(10, False), fill=(186, 230, 253))

    # Column 2: Center Main Display (190w)
    c2_x0, c2_x1 = x0 + 175, x0 + 365
    draw_rounded_rect(draw, (c2_x0, y0 + 58, c2_x1, y0 + 260), radius=8, fill=(22, 34, 55), outline=(56, 189, 248), width=1)
    draw.text((c2_x0 + 15, y0 + 70), "ЦЕЛЕВОЙ СЧЁТЧИК", font=get_font(10, True), fill=(186, 230, 253))
    draw.text((c2_x0 + 15, y0 + 90), "28", font=get_font(42, True), fill=(255, 255, 255))
    draw.text((c2_x0 + 75, y0 + 110), "/ 40", font=get_font(18, True), fill=(147, 197, 253))
    
    # Nexus Horizontal Progress
    draw.rectangle([c2_x0 + 15, y0 + 145, c2_x1 - 15, y0 + 158], fill=(12, 18, 30))
    draw.rectangle([c2_x0 + 15, y0 + 145, c2_x0 + 15 + int((c2_x1 - c2_x0 - 30) * 0.7), y0 + 158], fill=(14, 165, 233))
    draw.text((c2_x0 + 15, y0 + 170), "СТАТУС: ИДЁТ СБОР", font=get_font(11, True), fill=(74, 222, 128))
    draw.text((c2_x0 + 15, y0 + 190), "Осталось до лимита: 12", font=get_font(10, False), fill=(147, 197, 253))

    # Column 3: Right Telemetry (150w)
    c3_x0, c3_x1 = x0 + 375, x1 - 15
    draw_rounded_rect(draw, (c3_x0, y0 + 58, c3_x1, y0 + 260), radius=8, fill=(20, 30, 48))
    draw.text((c3_x0 + 12, y0 + 70), "КАРТА & РАУНД", font=get_font(10, True), fill=(147, 197, 253))
    draw.text((c3_x0 + 12, y0 + 90), "Mansion", font=get_font(14, True), fill=(255, 255, 255))
    draw.text((c3_x0 + 12, y0 + 115), "РЕЖИМ: АКТИВЕН", font=get_font(10, True), fill=(52, 211, 153))
    draw.text((c3_x0 + 12, y0 + 145), "ВСЕГО: 184 шт.", font=get_font(11, True), fill=(255, 255, 255))
    draw.text((c3_x0 + 12, y0 + 170), "РАУНДОВ: 5", font=get_font(11, False), fill=(186, 230, 253))

    # Bottom Full Width Action Deck
    draw_rounded_rect(draw, (x0 + 15, y0 + 275, x1 - 15, y0 + 335), radius=8, fill=(220, 38, 38))
    draw.text((x0 + 210, y0 + 295), "■ ОСТАНОВИТЬ ФАРМ", font=get_font(14, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "08_nexus.png")

# ==============================================================================
# PROTOTYPE 9: MIDNIGHT (Compact Pocket Overlay, Subtle Lighting)
# ==============================================================================
def render_09_midnight():
    img = Image.new("RGBA", (960, 540), (6, 6, 8, 255))
    draw_backdrop(img, (10, 10, 14))
    draw = ImageDraw.Draw(img)

    # Compact Floating Bar (Bottom-aligned pocket bar)
    x0, y0, x1, y1 = 280, 110, 680, 430
    draw_rounded_rect(draw, (x0, y0, x1, y1), radius=14, fill=(16, 16, 22), outline=(38, 38, 50), width=2)

    # Sleek Compact Header
    draw.text((x0 + 20, y0 + 16), "MIDNIGHT OVERLAY", font=get_font(14, True), fill=(255, 255, 255))
    draw.ellipse([x1 - 35, y0 + 20, x1 - 25, y0 + 30], fill=(16, 185, 129))

    # Single Row Telemetry
    draw_rounded_rect(draw, (x0 + 16, y0 + 50, x1 - 16, y0 + 95), radius=8, fill=(22, 22, 30))
    draw.text((x0 + 28, y0 + 62), "СТАТУС: СБОР КОНФЕТ • КАРТА АКТИВНА", font=get_font(11, True), fill=(220, 220, 230))
    draw.text((x0 + 28, y0 + 78), "60 FPS • Без лагов", font=get_font(9, False), fill=(140, 140, 160))

    # Large Counter
    draw_rounded_rect(draw, (x0 + 16, y0 + 105, x1 - 16, y0 + 185), radius=8, fill=(22, 22, 30))
    draw.text((x0 + 28, y0 + 118), "КОНФЕТ В СУМКЕ", font=get_font(10, True), fill=(150, 150, 170))
    draw.text((x0 + 28, y0 + 135), "28 / 40", font=get_font(28, True), fill=(255, 255, 255))
    draw.text((x1 - 120, y0 + 145), "ВСЕГО: 184", font=get_font(12, True), fill=(200, 200, 220))

    # High FPS Slider Row
    draw_rounded_rect(draw, (x0 + 16, y0 + 195, x1 - 16, y0 + 245), radius=8, fill=(22, 22, 30))
    draw.text((x0 + 28, y0 + 210), "ВЫСОКИЙ FPS", font=get_font(11, True), fill=(255, 255, 255))
    draw_rounded_rect(draw, (x1 - 70, y0 + 205, x1 - 28, y0 + 233), radius=14, fill=(16, 185, 129))
    draw.ellipse([x1 - 48, y0 + 208, x1 - 31, y0 + 230], fill=(255, 255, 255))

    # Compact Action Button
    draw_rounded_rect(draw, (x0 + 16, y0 + 258, x1 - 16, y0 + 305), radius=8, fill=(220, 38, 38))
    draw.text((x0 + 150, y0 + 273), "■ ОСТАНОВИТЬ", font=get_font(13, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "09_midnight.png")

# ==============================================================================
# PROTOTYPE 10: HYPER (Ultra-Modern Esports Style, Asymmetrical Angles)
# ==============================================================================
def render_10_hyper():
    img = Image.new("RGBA", (960, 540), (10, 8, 14, 255))
    draw_backdrop(img, (24, 12, 32))
    draw = ImageDraw.Draw(img)

    # Hyper HUD Pill
    draw_chamfer_rect(draw, (30, 25, 200, 65), cut=8, fill=(35, 15, 45), outline=(244, 63, 94), width=2)
    draw.text((45, 36), "HYPER: 28/40 [LIVE]", font=get_font(11, True), fill=(254, 205, 211))

    # Asymmetrical Main Frame: 460 x 380
    x0, y0, x1, y1 = 250, 60, 750, 480
    draw_chamfer_rect(draw, (x0, y0, x1, y1), cut=16, fill=(18, 12, 24), outline=(244, 63, 94), width=2)

    # Dynamic Top Angle Header
    draw_chamfer_rect(draw, (x0, y0, x1, y0 + 46), cut=16, fill=(45, 15, 45), outline=(251, 113, 133), width=1)
    draw.text((x0 + 24, y0 + 13), "HYPER // ESPORTS MM2", font=get_font(15, True), fill=(255, 255, 255))
    draw.text((x1 - 120, y0 + 15), "[144 HZ MODE]", font=get_font(10, True), fill=(251, 113, 133))

    # Dual Hyper Meters
    draw_chamfer_rect(draw, (x0 + 20, y0 + 58, x0 + 230, y0 + 170), cut=10, fill=(30, 16, 38), outline=(225, 29, 72), width=1)
    draw.text((x0 + 32, y0 + 68), "CANDY SPEEDMETER", font=get_font(10, True), fill=(251, 113, 133))
    draw.text((x0 + 32, y0 + 88), "28 / 40", font=get_font(30, True), fill=(255, 255, 255))
    draw.text((x0 + 32, y0 + 135), "СКОРОСТЬ: 32 STUDS/S", font=get_font(10, True), fill=(254, 205, 211))

    draw_chamfer_rect(draw, (x0 + 245, y0 + 58, x1 - 20, y0 + 170), cut=10, fill=(30, 16, 38), outline=(225, 29, 72), width=1)
    draw.text((x0 + 258, y0 + 68), "STATUS TELEMETRY", font=get_font(10, True), fill=(251, 113, 133))
    draw.text((x0 + 258, y0 + 88), "СБОР КОНФЕТ", font=get_font(20, True), fill=(74, 222, 128))
    draw.text((x0 + 258, y0 + 135), "РАУНД: Mansion (01:42)", font=get_font(10, True), fill=(254, 205, 211))

    # Real-time Sparkline Graph simulation
    draw_chamfer_rect(draw, (x0 + 20, y0 + 182, x1 - 20, y0 + 265), cut=8, fill=(24, 14, 32))
    draw.text((x0 + 32, y0 + 192), "FPS STABILITY & LATENCY (60.0 FPS)", font=get_font(10, True), fill=(251, 113, 133))
    # Draw mini sparkline graph
    graph_pts = [(x0 + 35 + i * 20, y0 + 245 - int(math.sin(i * 0.7) * 8 + 8)) for i in range(21)]
    for i in range(len(graph_pts) - 1):
        draw.line([graph_pts[i], graph_pts[i+1]], fill=(244, 63, 94), width=2)

    # Hyper High FPS Switch
    draw_chamfer_rect(draw, (x0 + 20, y0 + 278, x1 - 20, y0 + 328), cut=8, fill=(30, 16, 38))
    draw.text((x0 + 32, y0 + 292), "ТУРБО-РЕЖИМ (ВЫСОКИЙ FPS)", font=get_font(11, True), fill=(255, 255, 255))
    draw_chamfer_rect(draw, (x1 - 90, y0 + 286, x1 - 35, y0 + 316), cut=6, fill=(16, 185, 129))
    draw.text((x1 - 78, y0 + 294), "ВКЛ", font=get_font(11, True), fill=(255, 255, 255))

    # Bottom Hyper Dual Action
    draw_chamfer_rect(draw, (x0 + 20, y0 + 342, x1 - 20, y0 + 395), cut=10, fill=(225, 29, 72), outline=(251, 113, 133), width=2)
    draw.text((x0 + 175, y0 + 358), "■ СТОП АВТОФАРМ", font=get_font(14, True), fill=(255, 255, 255))

    img.save(OUTPUT_DIR / "10_hyper.png")

# ==============================================================================
# COMPARISON SHEET: MASTER GALLERY (2x5 Grid of All 10 Designs)
# ==============================================================================
def render_comparison_sheet():
    # 2 columns x 5 rows of 480x270 thumbnails -> 1060 x 1550 canvas with titles
    sheet = Image.new("RGBA", (1100, 1600), (12, 10, 16, 255))
    draw = ImageDraw.Draw(sheet)

    # Master Title
    draw.text((40, 25), "MM2 CANDY FARM — 10 ДИЗАЙН-ПРОТОТИПОВ ИНТЕРФЕЙСА (PREVIEW GALLERY)", font=get_font(20, True), fill=(255, 255, 255))
    draw.text((40, 55), "Сравнение 10 уникальных макетов мобильного UI для Delta Executor Android • Без эмодзи • Векторные иконки", font=get_font(12, False), fill=(196, 181, 253))

    designs = [
        ("01_nebula_pro.png", "1. NEBULA PRO", "Карточный грид 2x2, тёмно-фиолетовый, элегантный"),
        ("02_obsidian.png", "2. OBSIDIAN", "Монолитная панель, ультра-минимализм, глубокий чёрный"),
        ("03_cyber_violet.png", "3. CYBER VIOLET", "Круговой спидометр, неоновые скосы, кибер-гейминг"),
        ("04_liquid_glass.png", "4. LIQUID GLASS", "Многослойный матовый акрил, светящиеся синие контуры"),
        ("05_phantom.png", "5. PHANTOM", "Тактический красно-чёрный милитари HUD, верхние вкладки"),
        ("06_aurora.png", "6. AURORA", "Мягкие волны и скругления, аквамарин и морской градиент"),
        ("07_monarch.png", "7. MONARCH", "Золото и обсидиан, премиальный люкс-стиль, строгая геометрия"),
        ("08_nexus.png", "8. NEXUS", "3-колоночный модульный дашборд будущего, широкая панель"),
        ("09_midnight.png", "9. MIDNIGHT", "Компактный карманный оверлей, не перекрывает экран игры"),
        ("10_hyper.png", "10. HYPER", "Киберспортивный асимметричный пульт, график FPS в реальном времени"),
    ]

    thumb_w, thumb_h = 480, 270

    for idx, (filename, title, desc) in enumerate(designs):
        col = idx % 2
        row = idx // 2
        x = 50 + col * 520
        y = 100 + row * 295

        img_path = OUTPUT_DIR / filename
        if img_path.exists():
            thumb = Image.open(img_path).resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            sheet.paste(thumb, (x, y + 25))
            draw.rectangle([x, y + 25, x + thumb_w, y + 25 + thumb_h], outline=(80, 60, 110), width=1)

        draw.text((x, y), title, font=get_font(13, True), fill=(255, 255, 255))
        draw.text((x + 140, y + 2), desc, font=get_font(10, False), fill=(180, 160, 220))

    sheet.save(OUTPUT_DIR / "comparison_sheet.png")
    print("Successfully generated all 10 prototypes and master comparison sheet!")

if __name__ == "__main__":
    render_01_nebula_pro()
    render_02_obsidian()
    render_03_cyber_violet()
    render_04_liquid_glass()
    render_05_phantom()
    render_06_aurora()
    render_07_monarch()
    render_08_nexus()
    render_09_midnight()
    render_10_hyper()
    render_comparison_sheet()
