"""
Aion-2 Physical & Divine Skill Icons Generator
Produces 16 high-resolution, ornate, production-grade 256x256 PNG icons.
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageChops

OUTPUT_DIR = r"assets\images\icons\skills_physical"
os.makedirs(OUTPUT_DIR, exist_ok=True)

CANVAS = 512
FINAL = 256

def make_radial_bg(size, inner, outer, cx=0.5, cy=0.5, power=1.4):
    y, x = np.ogrid[:size, :size]
    icx, icy = cx * size, cy * size
    d = np.sqrt((x - icx)**2 + (y - icy)**2)
    max_d = math.sqrt(max(icx, size - icx)**2 + max(icy, size - icy)**2)
    t = np.clip(d / max_d, 0.0, 1.0) ** power
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    for c in range(3):
        col = (1.0 - t) * inner[c] + t * outer[c]
        arr[:, :, c] = np.clip(col, 0, 255).astype(np.uint8)
    arr[:, :, 3] = 255
    return Image.fromarray(arr, mode="RGBA")

def add_glow(base, glow_img, blur=14, intensity=1.2):
    b = glow_img.filter(ImageFilter.GaussianBlur(blur))
    if intensity != 1.0:
        b = ImageEnhance.Brightness(b).enhance(intensity)
    return Image.alpha_composite(base, b)

def apply_frame(img, theme="gold"):
    size = img.width
    frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    
    if theme == "gold":
        c_rim = (255, 225, 120, 255)
        c_dark = (55, 38, 15, 255)
        c_mid = (185, 145, 55, 255)
        c_gem = (100, 225, 255, 255)
    elif theme == "crimson":
        c_rim = (255, 120, 100, 255)
        c_dark = (50, 15, 15, 255)
        c_mid = (175, 45, 45, 255)
        c_gem = (255, 210, 80, 255)
    elif theme == "shadow":
        c_rim = (195, 145, 245, 255)
        c_dark = (28, 16, 38, 255)
        c_mid = (115, 60, 150, 255)
        c_gem = (225, 120, 255, 255)
    elif theme == "emerald":
        c_rim = (130, 245, 160, 255)
        c_dark = (16, 42, 26, 255)
        c_mid = (45, 150, 75, 255)
        c_gem = (190, 255, 210, 255)
    elif theme == "steel":
        c_rim = (225, 235, 250, 255)
        c_dark = (32, 38, 48, 255)
        c_mid = (120, 135, 160, 255)
        c_gem = (130, 210, 255, 255)
    else:
        c_rim = (255, 215, 120, 255)
        c_dark = (50, 35, 15, 255)
        c_mid = (170, 130, 45, 255)
        c_gem = (255, 240, 160, 255)

    m = 12
    draw.rounded_rectangle([m, m, size - m, size - m], radius=28, outline=c_dark, width=16)
    draw.rounded_rectangle([m + 7, m + 7, size - m - 7, size - m - 7], radius=24, outline=c_mid, width=6)
    draw.rounded_rectangle([m + 11, m + 11, size - m - 11, size - m - 11], radius=20, outline=c_rim, width=3)
    draw.rounded_rectangle([m + 15, m + 15, size - m - 15, size - m - 15], radius=16, outline=(10, 10, 15, 230), width=4)

    # Filigree corner brackets & gems
    corners = [(m + 18, m + 18), (size - m - 18, m + 18), (m + 18, size - m - 18), (size - m - 18, size - m - 18)]
    for cx, cy in corners:
        d = 20
        draw.polygon([(cx, cy - d), (cx + d, cy), (cx, cy + d), (cx - d, cy)], fill=c_mid, outline=c_rim)
        draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=c_gem, outline=(255, 255, 240, 240))
        draw.ellipse([cx - 3, cy - 3, cx + 1, cy + 1], fill=(255, 255, 255, 255))

    mid = size // 2
    for px, py in [(mid, m + 10), (mid, size - m - 10), (m + 10, mid), (size - m - 10, mid)]:
        draw.polygon([(px - 9, py), (px, py - 7), (px + 9, py), (px, py + 7)], fill=c_rim, outline=c_dark)
        draw.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(255, 255, 255, 255))

    return Image.alpha_composite(img, frame)

def save_icon(img, filename):
    resized = img.resize((FINAL, FINAL), Image.Resampling.LANCZOS)
    path = os.path.join(OUTPUT_DIR, filename)
    resized.save(path, format="PNG", optimize=True)
    print(f"Saved: {path} ({resized.size[0]}x{resized.size[1]})")

# -------------------------------------------------------------
# 1. Righteous Punishment
# -------------------------------------------------------------
def gen_righteous_punishment():
    bg = make_radial_bg(CANVAS, (35, 30, 70), (8, 6, 18), 0.5, 0.45)
    rays = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rays)
    for i in range(16):
        ang = i * (2 * math.pi / 16)
        r = 240
        x2 = 256 + r * math.cos(ang)
        y2 = 230 + r * math.sin(ang)
        rdraw.line([256, 230, x2, y2], fill=(255, 235, 150, 45), width=18)
    bg = Image.alpha_composite(bg, rays)

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.line([256, 50, 256, 420], fill=(255, 240, 160, 200), width=36)
    gdraw.ellipse([200, 360, 312, 430], fill=(255, 220, 90, 220))
    bg = add_glow(bg, glow, blur=22, intensity=1.5)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.ellipse([244, 52, 268, 76], fill=(240, 190, 60, 255), outline=(255, 245, 180, 255), width=2)
    draw.rectangle([250, 76, 262, 140], fill=(70, 45, 20, 255))
    for gy in range(82, 138, 8):
        draw.line([250, gy, 262, gy], fill=(255, 220, 100, 255), width=2)

    draw.polygon([(256, 140), (330, 148), (350, 138), (320, 165), (256, 158)], fill=(225, 175, 45, 255), outline=(255, 240, 150, 255))
    draw.polygon([(256, 140), (182, 148), (162, 138), (192, 165), (256, 158)], fill=(225, 175, 45, 255), outline=(255, 240, 150, 255))
    draw.ellipse([246, 144, 266, 164], fill=(100, 220, 255, 255), outline=(255, 255, 255, 255), width=2)

    draw.polygon([(256, 158), (274, 170), (270, 370), (256, 420)], fill=(235, 240, 250, 255))
    draw.polygon([(256, 158), (238, 170), (242, 370), (256, 420)], fill=(195, 205, 225, 255))
    draw.line([256, 160, 256, 395], fill=(255, 250, 200, 255), width=4)
    draw.line([270, 175, 266, 365], fill=(255, 255, 255, 240), width=2)

    draw.ellipse([216, 400, 296, 430], outline=(255, 240, 160, 230), width=3)
    draw.ellipse([186, 408, 326, 442], outline=(255, 210, 80, 160), width=2)

    bg = Image.alpha_composite(bg, art)

    fg_glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    fgd = ImageDraw.Draw(fg_glow)
    fgd.line([256, 170, 256, 410], fill=(255, 255, 220, 230), width=6)
    fgd.ellipse([250, 414, 262, 426], fill=(255, 255, 255, 255))
    bg = add_glow(bg, fg_glow, blur=8, intensity=1.6)

    return apply_frame(bg, "gold")

# -------------------------------------------------------------
# 2. Shield Bastion
# -------------------------------------------------------------
def gen_shield_bastion():
    bg = make_radial_bg(CANVAS, (25, 38, 60), (6, 10, 20), 0.5, 0.5)
    
    hex_img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(hex_img)
    for hx in range(60, 460, 50):
        for hy in range(60, 460, 44):
            pts = []
            for k in range(6):
                ang = k * (math.pi / 3)
                pts.append((hx + 18 * math.cos(ang), hy + 18 * math.sin(ang)))
            hdraw.polygon(pts, outline=(80, 160, 240, 35), width=2)
    bg = Image.alpha_composite(bg, hex_img)

    rings = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rings)
    rdraw.ellipse([90, 50, 422, 460], outline=(120, 210, 255, 140), width=5)
    rdraw.ellipse([70, 30, 442, 480], outline=(80, 170, 255, 90), width=3)
    bg = add_glow(bg, rings, blur=10, intensity=1.3)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    shield_pts = [
        (130, 110), (256, 90), (382, 110),
        (376, 270), (256, 430), (136, 270)
    ]
    draw.polygon(shield_pts, fill=(35, 45, 60, 255), outline=(190, 150, 60, 255))
    
    inner_pts = [
        (146, 122), (256, 106), (366, 122),
        (360, 264), (256, 410), (152, 264)
    ]
    draw.polygon(inner_pts, fill=(55, 70, 92, 255), outline=(240, 200, 100, 255))

    draw.line([256, 106, 256, 410], fill=(220, 180, 80, 255), width=8)
    draw.line([146, 210, 366, 210], fill=(200, 160, 70, 255), width=6)

    # Detailed Embossed Lion Head Sigil on shield
    for i in range(16):
        ang = i * (2 * math.pi / 16)
        p1 = (256 + 36 * math.cos(ang), 210 + 36 * math.sin(ang))
        p2 = (256 + 62 * math.cos(ang + 0.1), 210 + 62 * math.sin(ang + 0.1))
        p3 = (256 + 36 * math.cos(ang + 0.2), 210 + 36 * math.sin(ang + 0.2))
        draw.polygon([p1, p2, p3], fill=(245, 195, 65, 255), outline=(255, 240, 150, 255))

    draw.ellipse([216, 172, 296, 248], fill=(220, 170, 50, 255), outline=(255, 230, 120, 255), width=3)
    draw.polygon([(236, 195), (256, 205), (276, 195), (256, 222)], fill=(180, 130, 30, 255))
    draw.polygon([(234, 202), (246, 205), (238, 212)], fill=(130, 235, 255, 255))
    draw.polygon([(278, 202), (266, 205), (274, 212)], fill=(130, 235, 255, 255))
    draw.polygon([(242, 226), (270, 226), (256, 242)], fill=(40, 25, 10, 255), outline=(255, 215, 80, 255))
    draw.polygon([(246, 226), (250, 226), (248, 234)], fill=(255, 255, 240, 255))
    draw.polygon([(262, 226), (266, 226), (264, 234)], fill=(255, 255, 240, 255))

    bg = Image.alpha_composite(bg, art)

    core_glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(core_glow)
    cdraw.ellipse([230, 185, 282, 235], fill=(255, 245, 140, 180))
    bg = add_glow(bg, core_glow, blur=12, intensity=1.5)

    return apply_frame(bg, "steel")

# -------------------------------------------------------------
# 3. Ankle Snare
# -------------------------------------------------------------
def gen_ankle_snare():
    bg = make_radial_bg(CANVAS, (40, 25, 20), (12, 8, 8), 0.5, 0.55)
    
    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    for cy in range(350, 440, 24):
        draw.ellipse([240, cy, 272, cy + 30], outline=(110, 110, 120, 255), width=6)

    draw.ellipse([216, 230, 296, 280], fill=(45, 48, 55, 255), outline=(130, 135, 145, 255), width=5)
    draw.ellipse([236, 245, 276, 265], fill=(180, 60, 30, 255), outline=(240, 140, 50, 255), width=3)
    draw.line([130, 255, 382, 255], fill=(70, 75, 85, 255), width=10)

    jaw_l = [(140, 255), (150, 170), (190, 120), (256, 110), (256, 135), (205, 145), (175, 185), (165, 255)]
    draw.polygon(jaw_l, fill=(95, 102, 115, 255), outline=(180, 190, 210, 255))

    jaw_r = [(372, 255), (362, 170), (322, 120), (256, 110), (256, 135), (307, 145), (337, 185), (347, 255)]
    draw.polygon(jaw_r, fill=(80, 86, 98, 255), outline=(160, 170, 190, 255))

    teeth_pts = [
        (185, 185, 215, 160), (210, 150, 235, 130), (240, 130, 255, 115),
        (327, 185, 297, 160), (302, 150, 277, 130), (272, 130, 257, 115)
    ]
    for x1, y1, x2, y2 in teeth_pts:
        draw.line([x1, y1, x2, y2], fill=(225, 230, 240, 255), width=5)

    spark_img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(spark_img)
    sdraw.ellipse([236, 110, 276, 140], fill=(255, 255, 200, 255))
    for ang in np.linspace(0, 2*math.pi, 20):
        length = np.random.uniform(30, 130)
        ex = 256 + length * math.cos(ang)
        ey = 125 + length * math.sin(ang)
        col = (255, int(np.random.uniform(140, 220)), 40, int(np.random.uniform(180, 255)))
        sdraw.line([256, 125, ex, ey], fill=col, width=int(np.random.uniform(2, 5)))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, spark_img, blur=8, intensity=1.5)

    return apply_frame(bg, "steel")

# -------------------------------------------------------------
# 4. Shadow Step
# -------------------------------------------------------------
def gen_shadow_step():
    bg = make_radial_bg(CANVAS, (35, 15, 45), (8, 4, 14), 0.5, 0.45)
    
    vortex = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vortex)
    for i in range(30):
        rad = 40 + i * 8
        ang0 = i * 0.4
        pts = [(256 + rad * math.cos(ang0 + k*0.1), 256 + (rad*0.8) * math.sin(ang0 + k*0.1)) for k in range(8)]
        vdraw.line(pts, fill=(160, 60, 220, 50), width=6)
    bg = Image.alpha_composite(bg, vortex)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    cloak_pts = [
        (256, 120), (290, 160), (330, 250), (350, 360),
        (290, 390), (256, 370), (220, 390), (160, 360),
        (180, 250), (222, 160)
    ]
    draw.polygon(cloak_pts, fill=(20, 12, 28, 240), outline=(80, 40, 110, 200))
    draw.polygon([(256, 110), (285, 145), (256, 190), (227, 145)], fill=(12, 8, 18, 255))

    draw.polygon([(160, 140), (180, 130), (140, 230), (130, 225)], fill=(140, 90, 200, 255), outline=(220, 160, 255, 255))
    draw.polygon([(350, 140), (330, 130), (370, 230), (380, 225)], fill=(140, 90, 200, 255), outline=(220, 160, 255, 255))

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.line([(244, 155), (200, 145)], fill=(255, 80, 220, 255), width=5)
    gdraw.line([(268, 155), (312, 145)], fill=(255, 80, 220, 255), width=5)
    for py in range(260, 420, 15):
        gdraw.ellipse([170, py, 342, py + 30], fill=(120, 40, 180, 70))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, glow, blur=12, intensity=1.5)

    return apply_frame(bg, "shadow")

# -------------------------------------------------------------
# 5. Executioner's Cleave
# -------------------------------------------------------------
def gen_executioners_cleave():
    bg = make_radial_bg(CANVAS, (50, 15, 15), (14, 4, 4), 0.55, 0.45)
    
    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.polygon([(140, 410), (160, 425), (340, 130), (325, 115)], fill=(55, 38, 28, 255), outline=(130, 95, 70, 255))
    for t in [0.3, 0.5, 0.7]:
        bx = int(150 + t * 180)
        by = int(418 - t * 295)
        draw.ellipse([bx - 10, by - 10, bx + 10, by + 10], fill=(160, 165, 175, 255))

    blade_pts = [
        (330, 120), (370, 90), (430, 130), (450, 230),
        (390, 290), (310, 230), (330, 190)
    ]
    draw.polygon(blade_pts, fill=(75, 80, 90, 255), outline=(180, 190, 205, 255), width=3)
    draw.line([(370, 90), (430, 130), (450, 230), (390, 290)], fill=(240, 245, 255, 255), width=6)

    slash = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(slash)
    sdraw.arc([60, 70, 440, 440], start=180, end=340, fill=(230, 30, 30, 220), width=24)
    sdraw.arc([75, 85, 425, 425], start=190, end=330, fill=(255, 120, 100, 255), width=10)
    
    np.random.seed(42)
    for _ in range(40):
        bx = np.random.uniform(90, 440)
        by = np.random.uniform(80, 380)
        br = np.random.uniform(3, 8)
        sdraw.ellipse([bx - br, by - br, bx + br, by + br], fill=(220, 20, 20, 230))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, slash, blur=10, intensity=1.4)

    return apply_frame(bg, "crimson")

# -------------------------------------------------------------
# 6. Divine Grace
# -------------------------------------------------------------
def gen_divine_grace():
    bg = make_radial_bg(CANVAS, (35, 42, 70), (10, 12, 25), 0.5, 0.4)
    
    wings = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    wdraw = ImageDraw.Draw(wings)
    wdraw.polygon([(256, 320), (120, 200), (90, 130), (150, 150), (120, 100), (200, 150), (256, 250)],
                  fill=(220, 230, 255, 60))
    wdraw.polygon([(256, 320), (392, 200), (422, 130), (362, 150), (392, 100), (312, 150), (256, 250)],
                  fill=(220, 230, 255, 60))
    bg = Image.alpha_composite(bg, wings)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.polygon([(180, 410), (195, 330), (220, 270), (235, 275), (215, 340), (225, 410)],
                 fill=(245, 225, 195, 255), outline=(255, 245, 220, 255))
    draw.polygon([(332, 410), (317, 330), (292, 270), (277, 275), (297, 340), (287, 410)],
                 fill=(245, 225, 195, 255), outline=(255, 245, 220, 255))

    spark = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(spark)
    cx, cy = 256, 220
    sdraw.ellipse([cx - 25, cy - 25, cx + 25, cy + 25], fill=(255, 255, 255, 255))
    for i in range(8):
        ang = i * (math.pi / 4)
        length = 90 if i % 2 == 0 else 55
        ex = cx + length * math.cos(ang)
        ey = cy + length * math.sin(ang)
        sdraw.line([cx, cy, ex, ey], fill=(255, 230, 110, 240), width=4 if i % 2 == 0 else 2)

    np.random.seed(77)
    for _ in range(35):
        mx = np.random.uniform(180, 332)
        my = np.random.uniform(100, 300)
        sdraw.ellipse([mx - 3, my - 3, mx + 3, my + 3], fill=(255, 245, 180, 220))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, spark, blur=15, intensity=1.6)

    return apply_frame(bg, "gold")

# -------------------------------------------------------------
# 7. Holy Aegis
# -------------------------------------------------------------
def gen_holy_aegis():
    bg = make_radial_bg(CANVAS, (20, 35, 65), (6, 8, 20), 0.5, 0.5)

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([110, 110, 402, 402], fill=(80, 180, 255, 80), outline=(160, 230, 255, 230), width=8)
    gdraw.ellipse([170, 170, 342, 342], fill=(255, 225, 100, 110))
    bg = add_glow(bg, glow, blur=14, intensity=1.5)

    # Sharp geometric runes & radiant Daevic seal
    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)
    
    draw.ellipse([120, 120, 392, 392], outline=(255, 235, 140, 220), width=4)
    draw.ellipse([140, 140, 372, 372], outline=(140, 220, 255, 180), width=2)
    
    r_ring = 166
    for i in range(24):
        ang = i * (2 * math.pi / 24)
        rx = 256 + r_ring * math.cos(ang)
        ry = 256 + r_ring * math.sin(ang)
        draw.rectangle([rx - 4, ry - 4, rx + 4, ry + 4], fill=(255, 245, 180, 255), outline=(50, 40, 15, 255))

    # Central Daevic Solar Cross Seal
    draw.line([256, 160, 256, 352], fill=(255, 255, 240, 255), width=8)
    draw.line([160, 256, 352, 256], fill=(255, 255, 240, 255), width=8)
    draw.ellipse([236, 236, 276, 276], fill=(255, 255, 255, 255), outline=(255, 215, 80, 255), width=3)
    draw.ellipse([246, 246, 266, 266], fill=(120, 230, 255, 255))

    for ang in np.linspace(0, 2*math.pi, 6, endpoint=False):
        hx = 256 + 95 * math.cos(ang)
        hy = 256 + 95 * math.sin(ang)
        draw.ellipse([hx - 12, hy - 12, hx + 12, hy + 12], fill=(70, 160, 230, 200), outline=(255, 240, 160, 255), width=2)

    bg = Image.alpha_composite(bg, art)

    return apply_frame(bg, "gold")

# -------------------------------------------------------------
# 8. Venomous Strike
# -------------------------------------------------------------
def gen_venomous_strike():
    bg = make_radial_bg(CANVAS, (15, 45, 25), (4, 15, 8), 0.5, 0.45)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.polygon([(160, 110), (195, 135), (290, 350), (256, 370), (170, 150)],
                 fill=(60, 75, 70, 255), outline=(130, 220, 160, 255), width=2)
    draw.polygon([(352, 110), (317, 135), (222, 350), (256, 370), (342, 150)],
                 fill=(50, 65, 60, 255), outline=(130, 220, 160, 255), width=2)

    draw.line([(160, 110), (190, 210), (175, 280), (256, 370)], fill=(80, 240, 130, 255), width=4)
    draw.line([(352, 110), (322, 210), (337, 280), (256, 370)], fill=(80, 240, 130, 255), width=4)

    venom = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(venom)
    for dy in [390, 420, 445]:
        vdraw.ellipse([250, dy, 262, dy + 18], fill=(60, 255, 120, 240))
        vdraw.polygon([(256, dy - 6), (250, dy + 8), (262, dy + 8)], fill=(60, 255, 120, 240))

    for i in range(15):
        cx = np.random.uniform(180, 332)
        cy = np.random.uniform(220, 400)
        cr = np.random.uniform(25, 60)
        vdraw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=(40, 220, 90, 65))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, venom, blur=11, intensity=1.5)

    return apply_frame(bg, "emerald")

# -------------------------------------------------------------
# 9. Sniper Arrow
# -------------------------------------------------------------
def gen_sniper_arrow():
    bg = make_radial_bg(CANVAS, (18, 38, 58), (5, 12, 22), 0.6, 0.4)

    waves = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    wdraw = ImageDraw.Draw(waves)
    for r in [60, 110, 170]:
        wdraw.arc([360 - r, 150 - r, 360 + r, 150 + r], start=100, end=260, fill=(130, 220, 255, 140), width=4)
    bg = Image.alpha_composite(bg, waves)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.line([(100, 410), (380, 130)], fill=(70, 50, 35, 255), width=8)
    for t in np.linspace(0.1, 0.9, 12):
        px = int(100 + t * 280)
        py = int(410 - t * 280)
        draw.ellipse([px - 8, py - 8, px + 8, py + 8], fill=(90, 220, 255, 200))

    draw.polygon([(100, 410), (70, 400), (85, 440), (120, 430)], fill=(230, 240, 250, 255), outline=(100, 180, 240, 255))
    draw.polygon([(100, 410), (110, 440), (70, 445), (80, 415)], fill=(200, 215, 235, 255))

    draw.polygon([(360, 150), (410, 100), (385, 160), (370, 140)], fill=(225, 235, 250, 255), outline=(255, 215, 90, 255), width=2)
    draw.polygon([(360, 150), (410, 100), (350, 125), (370, 140)], fill=(185, 200, 225, 255))

    spark = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(spark)
    sdraw.ellipse([400, 90, 420, 110], fill=(255, 255, 255, 255))
    for i in range(12):
        sx = np.random.uniform(140, 380)
        sy = np.random.uniform(120, 380)
        sdraw.line([(sx, sy), (sx - 40, sy + 40)], fill=(180, 240, 255, 180), width=2)

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, spark, blur=9, intensity=1.6)

    return apply_frame(bg, "steel")

# -------------------------------------------------------------
# 10. Mantra of Wrath
# -------------------------------------------------------------
def gen_mantra_of_wrath():
    bg = make_radial_bg(CANVAS, (55, 22, 12), (15, 6, 4), 0.5, 0.5)

    waves = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    wdraw = ImageDraw.Draw(waves)
    for r in [90, 140, 190, 235]:
        wdraw.ellipse([256 - r, 256 - r, 256 + r, 256 + r], outline=(255, 60, 30, 90), width=5)
    bg = Image.alpha_composite(bg, waves)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.polygon([(160, 220), (352, 220), (330, 360), (182, 360)], fill=(65, 30, 18, 255), outline=(190, 120, 45, 255), width=4)
    draw.ellipse([150, 180, 362, 260], fill=(120, 65, 35, 255), outline=(245, 190, 75, 255), width=6)
    draw.line([256, 195, 256, 245], fill=(255, 80, 40, 255), width=6)
    draw.line([210, 220, 302, 220], fill=(255, 80, 40, 255), width=6)
    draw.ellipse([236, 205, 276, 235], outline=(255, 210, 80, 255), width=3)

    draw.line([(120, 120), (220, 195)], fill=(160, 120, 60, 255), width=7)
    draw.ellipse([210, 185, 235, 210], fill=(240, 80, 40, 255))
    draw.line([(392, 120), (292, 195)], fill=(160, 120, 60, 255), width=7)
    draw.ellipse([277, 185, 302, 210], fill=(240, 80, 40, 255))

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([216, 190, 296, 250], fill=(255, 220, 80, 210))
    np.random.seed(99)
    for _ in range(30):
        ex = np.random.uniform(130, 382)
        ey = np.random.uniform(130, 380)
        gdraw.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=(255, 120, 30, 230))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, glow, blur=11, intensity=1.5)

    return apply_frame(bg, "crimson")

# -------------------------------------------------------------
# 11. Berserker Rage
# -------------------------------------------------------------
def gen_berserker_rage():
    bg = make_radial_bg(CANVAS, (60, 12, 12), (18, 4, 4), 0.5, 0.45)

    flame_glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(flame_glow)
    fdraw.ellipse([170, 160, 260, 260], fill=(255, 120, 20, 190))
    fdraw.ellipse([252, 160, 342, 260], fill=(255, 120, 20, 190))
    fdraw.ellipse([200, 280, 312, 380], fill=(255, 80, 10, 220))
    fdraw.ellipse([90, 60, 200, 200], fill=(255, 90, 20, 150))
    fdraw.ellipse([312, 60, 422, 200], fill=(255, 90, 20, 150))
    bg = add_glow(bg, flame_glow, blur=16, intensity=1.6)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    horn_l = [(210, 175), (155, 135), (110, 65), (105, 115), (145, 195), (190, 215)]
    draw.polygon(horn_l, fill=(80, 25, 20, 255), outline=(230, 80, 40, 255))
    for ht in [0.25, 0.5, 0.75]:
        hx1 = int(210 - ht * 95)
        hy1 = int(175 - ht * 105)
        draw.line([hx1 - 8, hy1 + 10, hx1 + 10, hy1 - 8], fill=(255, 140, 50, 255), width=3)

    horn_r = [(302, 175), (357, 135), (402, 65), (407, 115), (367, 195), (322, 215)]
    draw.polygon(horn_r, fill=(80, 25, 20, 255), outline=(230, 80, 40, 255))
    for ht in [0.25, 0.5, 0.75]:
        hx1 = int(302 + ht * 95)
        hy1 = int(175 - ht * 105)
        draw.line([hx1 + 8, hy1 + 10, hx1 - 10, hy1 - 8], fill=(255, 140, 50, 255), width=3)

    draw.ellipse([180, 150, 332, 290], fill=(45, 18, 18, 255), outline=(225, 60, 45, 255), width=4)
    draw.polygon([(185, 240), (165, 280), (210, 280)], fill=(40, 15, 15, 255), outline=(190, 40, 30, 255))
    draw.polygon([(327, 240), (347, 280), (302, 280)], fill=(40, 15, 15, 255), outline=(190, 40, 30, 255))

    jaw = [(205, 275), (307, 275), (292, 365), (220, 365)]
    draw.polygon(jaw, fill=(28, 10, 10, 255), outline=(220, 45, 35, 255), width=3)
    
    for tx in range(215, 288, 16):
        draw.polygon([(tx, 275), (tx + 12, 275), (tx + 6, 298)], fill=(250, 245, 230, 255), outline=(255, 120, 50, 255))
    for tx in range(218, 285, 16):
        draw.polygon([(tx, 360), (tx + 12, 360), (tx + 6, 332)], fill=(250, 245, 230, 255), outline=(255, 120, 50, 255))

    draw.ellipse([202, 202, 238, 238], fill=(255, 255, 220, 255), outline=(255, 150, 30, 255), width=3)
    draw.ellipse([274, 202, 310, 238], fill=(255, 255, 220, 255), outline=(255, 150, 30, 255), width=3)

    draw.line([256, 165, 256, 215], fill=(255, 240, 120, 255), width=5)
    draw.line([238, 185, 274, 185], fill=(255, 240, 120, 255), width=4)
    draw.line([244, 200, 268, 200], fill=(255, 240, 120, 255), width=3)

    bg = Image.alpha_composite(bg, art)

    return apply_frame(bg, "crimson")

# -------------------------------------------------------------
# 12. Whirlwind Slash
# -------------------------------------------------------------
def gen_whirlwind_slash():
    bg = make_radial_bg(CANVAS, (25, 38, 55), (8, 12, 18), 0.5, 0.5)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    for r, width, alpha in [(170, 16, 180), (130, 12, 220), (90, 8, 255)]:
        draw.arc([256 - r, 256 - r, 256 + r, 256 + r], start=30, end=240, fill=(180, 215, 245, alpha), width=width)
        draw.arc([256 - r, 256 - r, 256 + r, 256 + r], start=210, end=60, fill=(240, 250, 255, alpha), width=width)

    draw.polygon([(256, 110), (270, 230), (256, 402), (242, 282)], fill=(225, 235, 245, 255), outline=(130, 165, 200, 255))
    draw.polygon([(110, 256), (230, 242), (402, 256), (282, 270)], fill=(195, 210, 230, 255), outline=(110, 145, 180, 255))

    sparks = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(sparks)
    np.random.seed(123)
    for _ in range(45):
        ang = np.random.uniform(0, 2*math.pi)
        rad = np.random.uniform(80, 210)
        sx = 256 + rad * math.cos(ang)
        sy = 256 + rad * math.sin(ang)
        sdraw.line([(sx, sy), (sx + 8*math.cos(ang + 1.2), sy + 8*math.sin(ang + 1.2))], fill=(255, 255, 220, 240), width=2)
        sdraw.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=(255, 255, 255, 255))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, sparks, blur=8, intensity=1.5)

    return apply_frame(bg, "steel")

# -------------------------------------------------------------
# 13. Smite Evil
# -------------------------------------------------------------
def gen_smite_evil():
    bg = make_radial_bg(CANVAS, (40, 18, 45), (10, 6, 15), 0.55, 0.45)

    chains = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(chains)
    chain_links = [
        (130, 360, 20), (170, 310, -35), (210, 270, 15),
        (310, 270, -25), (350, 320, 40), (380, 370, -10)
    ]
    for cx, cy, rot in chain_links:
        cdraw.ellipse([cx - 24, cy - 14, cx + 24, cy + 14], outline=(70, 45, 80, 255), width=8)
        cdraw.line([cx - 20, cy, cx + 20, cy], fill=(160, 50, 220, 240), width=4)

    np.random.seed(88)
    for _ in range(25):
        fx = np.random.uniform(150, 360)
        fy = np.random.uniform(220, 380)
        cdraw.polygon([(fx, fy), (fx + 10, fy + 4), (fx + 4, fy + 12)], fill=(120, 70, 150, 255))

    bg = Image.alpha_composite(bg, chains)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.line([(370, 90), (270, 240)], fill=(75, 50, 30, 255), width=12)
    draw.line([(370, 90), (270, 240)], fill=(220, 175, 60, 255), width=4)

    h_head = [(230, 210), (300, 160), (330, 200), (260, 250)]
    draw.polygon(h_head, fill=(235, 185, 55, 255), outline=(255, 240, 160, 255), width=3)
    draw.polygon([(215, 225), (245, 200), (265, 235), (235, 260)], fill=(255, 230, 100, 255))
    draw.line([235, 215, 245, 245], fill=(45, 30, 10, 255), width=3)
    draw.line([225, 230, 255, 230], fill=(45, 30, 10, 255), width=3)

    flash = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(flash)
    fdraw.ellipse([210, 220, 290, 290], fill=(255, 255, 220, 255))
    for i in range(12):
        ang = i * (math.pi / 6)
        fdraw.line([250, 255, 250 + 130 * math.cos(ang), 255 + 130 * math.sin(ang)], fill=(255, 230, 100, 220), width=4)

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, flash, blur=13, intensity=1.6)

    return apply_frame(bg, "gold")

# -------------------------------------------------------------
# 14. Smoke Bomb
# -------------------------------------------------------------
def gen_smoke_bomb():
    bg = make_radial_bg(CANVAS, (30, 25, 38), (8, 6, 12), 0.5, 0.5)

    smoke = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(smoke)
    smoke_bubbles = [
        (200, 190, 90), (312, 190, 85), (256, 140, 95),
        (170, 280, 80), (342, 280, 85), (256, 330, 100),
        (140, 220, 70), (372, 220, 75), (256, 256, 110)
    ]
    for sx, sy, sr in smoke_bubbles:
        sdraw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(20, 14, 28, 140), outline=(80, 45, 110, 120), width=4)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.polygon([(230, 230), (250, 210), (240, 260)], fill=(35, 35, 45, 255), outline=(140, 80, 200, 255))
    draw.polygon([(282, 230), (262, 210), (272, 260)], fill=(30, 30, 40, 255), outline=(140, 80, 200, 255))
    draw.polygon([(256, 265), (235, 285), (277, 285)], fill=(25, 25, 35, 255), outline=(140, 80, 200, 255))

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([240, 240, 272, 272], fill=(220, 100, 255, 255))
    for ang in np.linspace(0, 2*math.pi, 16):
        ex = 256 + 120 * math.cos(ang)
        ey = 256 + 120 * math.sin(ang)
        gdraw.line([256, 256, ex, ey], fill=(180, 60, 240, 150), width=3)

    bg = Image.alpha_composite(bg, smoke)
    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, glow, blur=14, intensity=1.5)

    return apply_frame(bg, "shadow")

# -------------------------------------------------------------
# 15. Resurrection Light
# -------------------------------------------------------------
def gen_resurrection_light():
    bg = make_radial_bg(CANVAS, (25, 32, 65), (6, 8, 20), 0.5, 0.3)

    beam = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(beam)
    bdraw.polygon([(210, 40), (302, 40), (370, 460), (142, 460)], fill=(255, 245, 180, 75))
    bdraw.polygon([(236, 40), (276, 40), (316, 460), (196, 460)], fill=(255, 255, 220, 95))
    bg = Image.alpha_composite(bg, beam)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.polygon([(256, 260), (160, 180), (120, 110), (180, 140), (140, 90), (210, 130), (256, 210)],
                 fill=(255, 235, 140, 230), outline=(255, 255, 220, 255))
    draw.polygon([(256, 260), (352, 180), (392, 110), (332, 140), (372, 90), (302, 130), (256, 210)],
                 fill=(255, 235, 140, 230), outline=(255, 255, 220, 255))

    draw.ellipse([244, 150, 268, 178], fill=(255, 255, 240, 255))
    draw.polygon([(256, 178), (270, 240), (262, 330), (250, 330), (242, 240)], fill=(255, 245, 190, 255))

    draw.ellipse([236, 130, 276, 148], outline=(255, 235, 120, 255), width=3)

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([226, 140, 286, 200], fill=(255, 255, 200, 180))
    np.random.seed(55)
    for _ in range(40):
        mx = np.random.uniform(170, 342)
        my = np.random.uniform(70, 420)
        gdraw.ellipse([mx - 2, my - 2, mx + 2, my + 2], fill=(255, 250, 210, 240))

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, glow, blur=12, intensity=1.5)

    return apply_frame(bg, "gold")

# -------------------------------------------------------------
# 16. Blade Flurry
# -------------------------------------------------------------
def gen_blade_flurry():
    bg = make_radial_bg(CANVAS, (22, 28, 48), (6, 8, 16), 0.5, 0.5)

    art = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    draw.line([(380, 110), (120, 390)], fill=(235, 245, 255, 255), width=5)
    draw.ellipse([110, 370, 145, 405], outline=(225, 185, 60, 255), width=4)
    draw.ellipse([100, 395, 116, 411], fill=(240, 200, 80, 255))

    draw.line([(130, 120), (370, 380)], fill=(215, 230, 250, 255), width=7)
    draw.line([(335, 345), (375, 385)], fill=(185, 145, 45, 255), width=8)
    draw.ellipse([375, 385, 395, 405], fill=(225, 185, 60, 255))

    flurry = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(flurry)
    slash_angles = [0.2, 0.7, 1.3, 1.8, 2.4, 2.9]
    for ang in slash_angles:
        x1 = 256 - 160 * math.cos(ang)
        y1 = 256 - 160 * math.sin(ang)
        x2 = 256 + 160 * math.cos(ang)
        y2 = 256 + 160 * math.sin(ang)
        fdraw.line([(x1, y1), (x2, y2)], fill=(160, 225, 255, 210), width=4)

    fdraw.ellipse([236, 236, 276, 276], fill=(255, 255, 255, 255))
    for i in range(8):
        ang = i * (math.pi / 4)
        fdraw.line([256, 256, 256 + 70 * math.cos(ang), 256 + 70 * math.sin(ang)], fill=(220, 245, 255, 240), width=3)

    bg = Image.alpha_composite(bg, art)
    bg = add_glow(bg, flurry, blur=9, intensity=1.5)

    return apply_frame(bg, "steel")

# -------------------------------------------------------------
# Main Execution
# -------------------------------------------------------------
def main():
    generators = [
        ("skill_righteous_punishment.png", gen_righteous_punishment),
        ("skill_shield_bastion.png", gen_shield_bastion),
        ("skill_ankle_snare.png", gen_ankle_snare),
        ("skill_shadow_step.png", gen_shadow_step),
        ("skill_executioners_cleave.png", gen_executioners_cleave),
        ("skill_divine_grace.png", gen_divine_grace),
        ("skill_holy_aegis.png", gen_holy_aegis),
        ("skill_venomous_strike.png", gen_venomous_strike),
        ("skill_sniper_arrow.png", gen_sniper_arrow),
        ("skill_mantra_of_wrath.png", gen_mantra_of_wrath),
        ("skill_berserker_rage.png", gen_berserker_rage),
        ("skill_whirlwind_slash.png", gen_whirlwind_slash),
        ("skill_smite_evil.png", gen_smite_evil),
        ("skill_smoke_bomb.png", gen_smoke_bomb),
        ("skill_resurrection_light.png", gen_resurrection_light),
        ("skill_blade_flurry.png", gen_blade_flurry),
    ]

    print(f"Generating {len(generators)} physical and divine skill icons...")
    for filename, fn in generators:
        img = fn()
        save_icon(img, filename)
    print("All skill icons generated successfully!")

if __name__ == "__main__":
    main()
