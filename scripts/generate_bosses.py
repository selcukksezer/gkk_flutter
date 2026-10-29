"""
High-detail, production-grade Aion-2 World & Raid Boss Portrait Generator.
Generates 1024x1024 dark-fantasy boss portraits with ornate frames, elemental auras,
volumetric lighting, and intricate artistic composition.
"""

import os
import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

TARGET_DIR = os.path.abspath("assets/images/portraits/bosses")
W = 1024
H = 1024

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def create_radial_gradient(w, h, cx, cy, inner_col, outer_col, radius=None):
    if radius is None:
        radius = math.hypot(w, h) / 1.7
    y, x = np.ogrid[:h, :w]
    dist = np.hypot(x - cx, y - cy)
    t = np.clip(dist / radius, 0.0, 1.0)
    t = t * t * (3 - 2 * t)  # Smoothstep
    
    arr = np.zeros((h, w, 4), dtype=np.float32)
    for c in range(4):
        arr[..., c] = inner_col[c] * (1.0 - t) + outer_col[c] * t
    return arr

def apply_glow(base_img, glow_img, blur_radius=18, intensity=1.2):
    """Blurs glow_img and adds it to base_img using additive screen blending."""
    blurred = glow_img.filter(ImageFilter.GaussianBlur(blur_radius))
    b_arr = np.array(base_img, dtype=np.float32)
    g_arr = np.array(blurred, dtype=np.float32) * intensity
    
    # Screen blend: 1 - (1 - A)*(1 - B)
    norm_b = b_arr[..., :3] / 255.0
    norm_g = g_arr[..., :3] / 255.0
    screen = 1.0 - (1.0 - norm_b) * (1.0 - norm_g)
    
    res = b_arr.copy()
    res[..., :3] = np.clip(screen * 255.0, 0, 255)
    return Image.fromarray(res.astype(np.uint8))

def draw_ornate_boss_frame(draw, boss_type, w, h):
    """
    Renders an ornate dragon-bone, gothic gold, or abyssal iron frame
    with corner cabochons, runic inlays, and metallic bevels.
    """
    margin = 36
    thickness = 28
    
    if boss_type == "tiamat":
        c_outer = (45, 12, 10, 255)
        c_inner = (190, 85, 20, 255)
        c_gold = (255, 175, 40, 255)
        c_gem = (255, 30, 10, 255)
        c_rune = (255, 110, 30, 255)
    elif boss_type == "stormwing":
        c_outer = (10, 22, 42, 255)
        c_inner = (35, 115, 165, 255)
        c_gold = (140, 215, 255, 255)
        c_gem = (0, 240, 255, 255)
        c_rune = (80, 230, 255, 255)
    elif boss_type == "beritra":
        c_outer = (22, 8, 30, 255)
        c_inner = (95, 30, 135, 255)
        c_gold = (190, 110, 235, 255)
        c_gem = (245, 0, 175, 255)
        c_rune = (210, 80, 255, 255)
    elif boss_type == "ereshkigal":
        c_outer = (12, 28, 48, 255)
        c_inner = (80, 140, 190, 255)
        c_gold = (205, 230, 255, 255)
        c_gem = (130, 220, 255, 255)
        c_rune = (180, 240, 255, 255)
    elif boss_type == "kromede":
        c_outer = (32, 10, 14, 255)
        c_inner = (150, 45, 55, 255)
        c_gold = (225, 180, 85, 255)
        c_gem = (215, 15, 35, 255)
        c_rune = (255, 100, 80, 255)
    else:  # tahabata
        c_outer = (40, 10, 5, 255)
        c_inner = (170, 50, 12, 255)
        c_gold = (255, 130, 25, 255)
        c_gem = (255, 60, 0, 255)
        c_rune = (255, 160, 20, 255)

    # 1. Beveled outer shadow band
    for i in range(14):
        shade = 0.2 + 0.8 * (i / 14.0)
        col = (int(c_outer[0]*shade), int(c_outer[1]*shade), int(c_outer[2]*shade), 255)
        draw.rectangle([margin - 14 + i, margin - 14 + i, w - margin + 14 - i, h - margin + 14 - i], outline=col, width=1)

    # 2. Heavy middle metallic frame
    draw.rectangle([margin, margin, w - margin, h - margin], outline=c_outer, width=thickness)
    draw.rectangle([margin + 4, margin + 4, w - margin - 4, h - margin - 4], outline=c_inner, width=4)
    draw.rectangle([margin + 12, margin + 12, w - margin - 12, h - margin - 12], outline=c_gold, width=3)
    draw.rectangle([margin + thickness - 2, margin + thickness - 2, w - margin - thickness + 2, h - margin - thickness + 2], outline=c_outer, width=2)
    draw.rectangle([margin + thickness + 4, margin + thickness + 4, w - margin - thickness - 4, h - margin - thickness - 4], outline=c_gold, width=1)

    # 3. Corner boss plaques with deep relief
    corner_size = 72
    corners = [(margin, margin), (w - margin, margin), (margin, h - margin), (w - margin, h - margin)]
    for cx, cy in corners:
        # Diamond crest
        pts = [(cx - corner_size, cy), (cx, cy - corner_size), (cx + corner_size, cy), (cx, cy + corner_size)]
        draw.polygon(pts, fill=c_outer, outline=c_gold)
        s = corner_size * 0.65
        pts_in = [(cx - s, cy), (cx, cy - s), (cx + s, cy), (cx, cy + s)]
        draw.polygon(pts_in, fill=c_inner, outline=c_gold)
        
        # Center jewel
        r = 18
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c_gem, outline=(255, 255, 255, 230))
        # Specular shine
        draw.ellipse([cx - r + 4, cy - r + 4, cx - r + 9, cy - r + 9], fill=(255, 255, 255, 240))

    # 4. Cardinal Medallions
    meds = [(w // 2, margin), (w // 2, h - margin), (margin, h // 2), (w - margin, h // 2)]
    for mx, my in meds:
        pw, ph = 42, 20
        if mx == margin or mx == w - margin:
            pw, ph = ph, pw
        draw.rectangle([mx - pw, my - ph, mx + pw, my + ph], fill=c_inner, outline=c_gold, width=2)
        draw.ellipse([mx - 7, my - 7, mx + 7, my + 7], fill=c_gem, outline=(255, 255, 255, 220))

    # 5. Ancient dragon runes carved along frame
    step = 28
    for x in range(margin + corner_size + 16, w - margin - corner_size - 16, step):
        draw.line([(x, margin + 6), (x + 8, margin + thickness - 6)], fill=c_rune, width=2)
        draw.line([(x + 4, margin + 6), (x + 4, margin + thickness - 6)], fill=c_gold, width=1)
        draw.line([(x, h - margin - 6), (x + 8, h - margin - thickness + 6)], fill=c_rune, width=2)
        draw.line([(x + 4, h - margin - 6), (x + 4, h - margin - thickness + 6)], fill=c_gold, width=1)

    for y in range(margin + corner_size + 16, h - margin - corner_size - 16, step):
        draw.line([(margin + 6, y), (margin + thickness - 6, y + 8)], fill=c_rune, width=2)
        draw.line([(margin + 6, y + 4), (margin + thickness - 6, y + 4)], fill=c_gold, width=1)
        draw.line([(w - margin - 6, y), (w - margin - thickness + 6, y + 8)], fill=c_rune, width=2)
        draw.line([(w - margin - 6, y + 4), (w - margin - thickness + 6, y + 4)], fill=c_gold, width=1)


# ==============================================================================
# BOSS 1: DRAGON LORD TIAMAT
# ==============================================================================
def render_tiamat():
    print("Rendering Dragon Lord Tiamat...")
    bg_arr = create_radial_gradient(W, H, W//2, H//2 + 50, (65, 12, 5, 255), (10, 2, 2, 255))
    base = Image.fromarray(bg_arr.astype(np.uint8))
    draw = ImageDraw.Draw(base)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    random.seed(42)
    for _ in range(180):
        ex = random.randint(50, W - 50)
        ey = random.randint(80, H - 80)
        er = random.randint(2, 6)
        alpha = random.randint(80, 220)
        glow_draw.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(255, random.randint(60, 180), 10, alpha))

    for _ in range(8):
        fx = random.randint(150, W - 150)
        fy = random.randint(400, H - 100)
        pts = [(fx, fy)]
        for _ in range(6):
            fx += random.randint(-40, 40)
            fy += random.randint(-60, 60)
            pts.append((fx, fy))
        glow_draw.line(pts, fill=(255, 90, 10, 180), width=4)
        glow_draw.line(pts, fill=(255, 200, 50, 240), width=1)

    cx, cy = W // 2, 450
    for angle in range(0, 360, 8):
        rad = math.radians(angle)
        length = random.randint(280, 480)
        x2 = cx + math.cos(rad) * length
        y2 = cy + math.sin(rad) * length
        glow_draw.line([(cx, cy), (x2, y2)], fill=(255, 80, 15, 60), width=6)

    wing_left = [(W//2, 650), (100, 320), (60, 480), (180, 600), (80, 720), (W//2, 850)]
    wing_right = [(W//2, 650), (W - 100, 320), (W - 60, 480), (W - 180, 600), (W - 80, 720), (W//2, 850)]
    draw.polygon(wing_left, fill=(20, 6, 8, 255), outline=(70, 20, 15, 255))
    draw.polygon(wing_right, fill=(20, 6, 8, 255), outline=(70, 20, 15, 255))

    bust_pts = [
        (W//2 - 240, H), (W//2 - 200, 740), (W//2 - 130, 650),
        (W//2 - 80, 560), (W//2 + 80, 560), (W//2 + 130, 650),
        (W//2 + 200, 740), (W//2 + 240, H)
    ]
    draw.polygon(bust_pts, fill=(25, 8, 8, 255), outline=(120, 35, 20, 255))

    for y_band in range(600, 880, 45):
        plate = [
            (W//2 - 140, y_band), (W//2, y_band + 25), (W//2 + 140, y_band),
            (W//2 + 130, y_band + 38), (W//2, y_band + 48), (W//2 - 130, y_band + 38)
        ]
        draw.polygon(plate, fill=(38, 12, 10, 255), outline=(180, 50, 20, 255))
        glow_draw.line([(W//2 - 120, y_band + 20), (W//2, y_band + 35), (W//2 + 120, y_band + 20)], fill=(255, 110, 20, 230), width=3)
        glow_draw.line([(W//2 - 120, y_band + 20), (W//2, y_band + 35), (W//2 + 120, y_band + 20)], fill=(255, 230, 80, 255), width=1)

    neck = [(W//2 - 50, 480), (W//2 + 50, 480), (W//2 + 65, 590), (W//2 - 65, 590)]
    draw.polygon(neck, fill=(35, 10, 10, 255), outline=(90, 25, 15, 255))

    horn_left = [
        (W//2 - 40, 410), (W//2 - 120, 360), (W//2 - 240, 270),
        (W//2 - 360, 140), (W//2 - 380, 80), (W//2 - 340, 120),
        (W//2 - 220, 240), (W//2 - 90, 340), (W//2 - 30, 420)
    ]
    horn_right = [
        (W//2 + 40, 410), (W//2 + 120, 360), (W//2 + 240, 270),
        (W//2 + 360, 140), (W//2 + 380, 80), (W//2 + 340, 120),
        (W//2 + 220, 240), (W//2 + 90, 340), (W//2 + 30, 420)
    ]
    draw.polygon(horn_left, fill=(20, 6, 6, 255), outline=(160, 45, 15, 255))
    draw.polygon(horn_right, fill=(20, 6, 6, 255), outline=(160, 45, 15, 255))

    horn_vein_l = [(W//2 - 35, 415), (W//2 - 110, 350), (W//2 - 230, 255), (W//2 - 350, 130), (W//2 - 370, 85)]
    horn_vein_r = [(W//2 + 35, 415), (W//2 + 110, 350), (W//2 + 230, 255), (W//2 + 350, 130), (W//2 + 370, 85)]
    glow_draw.line(horn_vein_l, fill=(255, 90, 15, 255), width=6)
    glow_draw.line(horn_vein_l, fill=(255, 220, 80, 255), width=2)
    glow_draw.line(horn_vein_r, fill=(255, 90, 15, 255), width=6)
    glow_draw.line(horn_vein_r, fill=(255, 220, 80, 255), width=2)

    for i in range(1, 5):
        t = i / 5.0
        hx_l = int((W//2 - 40)*(1-t) + (W//2 - 360)*t)
        hy_l = int(410*(1-t) + 140*t)
        draw.line([(hx_l, hy_l), (hx_l - 25, hy_l - 20)], fill=(220, 70, 20, 255), width=3)
        hx_r = int((W//2 + 40)*(1-t) + (W//2 + 360)*t)
        hy_r = int(410*(1-t) + 140*t)
        draw.line([(hx_r, hy_r), (hx_r + 25, hy_r - 20)], fill=(220, 70, 20, 255), width=3)

    head = [
        (W//2, 340), (W//2 + 65, 400), (W//2 + 55, 470),
        (W//2, 510), (W//2 - 55, 470), (W//2 - 65, 400)
    ]
    draw.polygon(head, fill=(35, 12, 12, 255), outline=(180, 60, 25, 255))

    crown_pts = [
        (W//2 - 70, 390), (W//2 - 50, 310), (W//2 - 30, 360),
        (W//2, 290), (W//2 + 30, 360), (W//2 + 50, 310), (W//2 + 70, 390)
    ]
    draw.polygon(crown_pts, fill=(18, 5, 5, 255), outline=(255, 160, 30, 255))
    glow_draw.polygon(crown_pts, outline=(255, 110, 20, 200))

    eye_l = [(W//2 - 38, 420), (W//2 - 15, 416), (W//2 - 20, 425), (W//2 - 38, 422)]
    eye_r = [(W//2 + 15, 416), (W//2 + 38, 420), (W//2 + 38, 422), (W//2 + 20, 425)]
    glow_draw.polygon(eye_l, fill=(255, 240, 160, 255))
    glow_draw.polygon(eye_r, fill=(255, 240, 160, 255))
    glow_draw.line([(W//2 - 50, 421), (W//2 - 5, 421)], fill=(255, 140, 20, 255), width=4)
    glow_draw.line([(W//2 + 5, 421), (W//2 + 50, 421)], fill=(255, 140, 20, 255), width=4)

    draw.line([(W//2, 420), (W//2, 475)], fill=(15, 4, 4, 255), width=2)
    draw.line([(W//2 - 25, 485), (W//2, 495), (W//2 + 25, 485)], fill=(20, 5, 5, 255), width=2)

    img = apply_glow(base, glow, blur_radius=12, intensity=1.4)
    frame_draw = ImageDraw.Draw(img)
    draw_ornate_boss_frame(frame_draw, "tiamat", W, H)

    out_path = os.path.join(TARGET_DIR, "boss_tiamat.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# BOSS 2: STORMWING
# ==============================================================================
def render_stormwing():
    print("Rendering The Beshmundir Dragon: Stormwing...")
    bg_arr = create_radial_gradient(W, H, W//2, H//2 - 40, (12, 35, 65, 255), (3, 7, 18, 255))
    base = Image.fromarray(bg_arr.astype(np.uint8))
    draw = ImageDraw.Draw(base)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    cx, cy = W // 2, 440
    for arm in range(4):
        offset = arm * (math.pi / 2)
        pts = []
        for step in range(60):
            th = offset + step * 0.12
            r = step * 8.5
            x = cx + r * math.cos(th)
            y = cy + r * math.sin(th)
            pts.append((x, y))
        glow_draw.line(pts, fill=(0, 180, 255, 75), width=5)

    random.seed(101)
    for _ in range(12):
        lx = random.randint(80, W - 80)
        ly = random.randint(60, 260)
        pts = [(lx, ly)]
        for _ in range(8):
            lx += random.randint(-45, 45)
            ly += random.randint(30, 75)
            pts.append((lx, ly))
        glow_draw.line(pts, fill=(0, 230, 255, 220), width=3)
        glow_draw.line(pts, fill=(230, 255, 255, 255), width=1)

    wing_l = [(W//2, 600), (40, 200), (80, 380), (120, 560), (60, 700), (W//2, 850)]
    wing_r = [(W//2, 600), (W - 40, 200), (W - 80, 380), (W - 120, 560), (W - 60, 700), (W//2, 850)]
    draw.polygon(wing_l, fill=(15, 28, 45, 255), outline=(0, 160, 220, 255))
    draw.polygon(wing_r, fill=(15, 28, 45, 255), outline=(0, 160, 220, 255))

    for wy in range(260, 720, 40):
        glow_draw.line([(80, wy), (W//2 - 120, wy + 80)], fill=(0, 210, 255, 110), width=2)
        glow_draw.line([(W - 80, wy), (W//2 + 120, wy + 80)], fill=(0, 210, 255, 110), width=2)

    body = [
        (W//2 - 220, H), (W//2 - 170, 720), (W//2 - 100, 620),
        (W//2 + 100, 620), (W//2 + 170, 720), (W//2 + 220, H)
    ]
    draw.polygon(body, fill=(18, 32, 52, 255), outline=(50, 140, 200, 255))

    neck = [(W//2 - 70, 480), (W//2 + 70, 480), (W//2 + 90, 640), (W//2 - 90, 640)]
    draw.polygon(neck, fill=(22, 40, 65, 255), outline=(70, 160, 220, 255))
    for sy in range(500, 640, 28):
        spine = [(W//2, sy), (W//2 - 35, sy - 20), (W//2, sy - 10), (W//2 + 35, sy - 20)]
        draw.polygon(spine, fill=(80, 200, 255, 255), outline=(220, 250, 255, 255))

    for side in [-1, 1]:
        h1 = [
            (W//2 + side * 45, 420), (W//2 + side * 140, 350), (W//2 + side * 260, 250),
            (W//2 + side * 370, 110), (W//2 + side * 390, 80), (W//2 + side * 340, 150),
            (W//2 + side * 220, 280), (W//2 + side * 110, 380), (W//2 + side * 35, 430)
        ]
        draw.polygon(h1, fill=(25, 60, 95, 255), outline=(130, 220, 255, 255))
        h_in = [
            (W//2 + side * 55, 415), (W//2 + side * 140, 340), (W//2 + side * 255, 240),
            (W//2 + side * 365, 115), (W//2 + side * 340, 160), (W//2 + side * 215, 275)
        ]
        glow_draw.polygon(h_in, fill=(0, 200, 255, 140))
        glow_draw.line(h1[:5], fill=(210, 255, 255, 255), width=2)

        h2 = [
            (W//2 + side * 60, 460), (W//2 + side * 160, 420), (W//2 + side * 260, 360),
            (W//2 + side * 240, 390), (W//2 + side * 140, 450), (W//2 + side * 50, 475)
        ]
        draw.polygon(h2, fill=(20, 50, 80, 255), outline=(100, 190, 240, 255))

    head = [
        (W//2, 360), (W//2 + 75, 420), (W//2 + 65, 480),
        (W//2 + 35, 540), (W//2, 565), (W//2 - 35, 540),
        (W//2 - 65, 480), (W//2 - 75, 420)
    ]
    draw.polygon(head, fill=(28, 52, 82, 255), outline=(90, 190, 255, 255))

    maw = [(W//2 - 30, 510), (W//2, 530), (W//2 + 30, 510), (W//2, 555)]
    draw.polygon(maw, fill=(10, 20, 35, 255), outline=(0, 180, 255, 255))
    glow_draw.polygon(maw, fill=(0, 220, 255, 200))

    for fx in range(W//2 - 25, W//2 + 25, 10):
        draw.line([(fx, 510), (fx + 3, 522)], fill=(240, 255, 255, 255), width=2)
        draw.line([(fx, 548), (fx + 3, 536)], fill=(240, 255, 255, 255), width=2)

    eye_l = [(W//2 - 45, 440), (W//2 - 20, 436), (W//2 - 25, 448), (W//2 - 45, 445)]
    eye_r = [(W//2 + 20, 436), (W//2 + 45, 440), (W//2 + 45, 445), (W//2 + 25, 448)]
    glow_draw.polygon(eye_l, fill=(240, 255, 255, 255))
    glow_draw.polygon(eye_r, fill=(240, 255, 255, 255))
    glow_draw.line([(W//2 - 70, 442), (W//2 - 10, 442)], fill=(0, 220, 255, 255), width=5)
    glow_draw.line([(W//2 + 10, 442), (W//2 + 70, 442)], fill=(0, 220, 255, 255), width=5)

    img = apply_glow(base, glow, blur_radius=14, intensity=1.5)
    frame_draw = ImageDraw.Draw(img)
    draw_ornate_boss_frame(frame_draw, "stormwing", W, H)

    out_path = os.path.join(TARGET_DIR, "boss_stormwing.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# BOSS 3: BERITRA
# ==============================================================================
def render_beritra():
    print("Rendering Lord of Darkness and Chaos: Beritra...")
    bg_arr = create_radial_gradient(W, H, W//2, H//2 - 20, (35, 10, 52, 255), (4, 2, 8, 255))
    base = Image.fromarray(bg_arr.astype(np.uint8))
    draw = ImageDraw.Draw(base)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    cx, cy = W // 2, 430
    for r in range(280, 520, 30):
        glow_draw.ellipse([cx - r, cy - r*0.75, cx + r, cy + r*0.75], outline=(150, 30, 220, 70), width=4)

    random.seed(333)
    for _ in range(40):
        sx = random.randint(80, W - 80)
        sy = random.randint(80, H - 80)
        ss = random.randint(12, 32)
        shard = [(sx, sy - ss), (sx + ss*0.6, sy + ss*0.4), (sx - ss*0.5, sy + ss*0.8)]
        draw.polygon(shard, fill=(20, 5, 30, 240), outline=(180, 40, 255, 200))
        glow_draw.polygon(shard, outline=(220, 80, 255, 220))

    for t_idx in range(16):
        tx = W//2 + random.randint(-260, 260)
        ty = 650
        pts = [(tx, ty)]
        for _ in range(10):
            tx += random.randint(-35, 35)
            ty -= random.randint(30, 60)
            pts.append((tx, ty))
        glow_draw.line(pts, fill=(190, 20, 240, 110), width=6)
        glow_draw.line(pts, fill=(255, 140, 255, 190), width=2)

    claw_l = [
        (W//2 - 260, 780), (W//2 - 290, 640), (W//2 - 220, 560),
        (W//2 - 160, 620), (W//2 - 180, 750)
    ]
    claw_r = [
        (W//2 + 260, 780), (W//2 + 290, 640), (W//2 + 220, 560),
        (W//2 + 160, 620), (W//2 + 180, 750)
    ]
    draw.polygon(claw_l, fill=(25, 8, 35, 255), outline=(170, 50, 220, 255))
    draw.polygon(claw_r, fill=(25, 8, 35, 255), outline=(170, 50, 220, 255))

    torso = [
        (W//2 - 220, H), (W//2 - 170, 700), (W//2 - 90, 590),
        (W//2 + 90, 590), (W//2 + 170, 700), (W//2 + 220, H)
    ]
    draw.polygon(torso, fill=(18, 5, 25, 255), outline=(140, 30, 180, 255))

    core = [(W//2, 640), (W//2 + 45, 680), (W//2, 720), (W//2 - 45, 680)]
    draw.polygon(core, fill=(10, 2, 15, 255), outline=(220, 60, 255, 255))
    glow_draw.polygon(core, fill=(240, 20, 200, 200))
    glow_draw.ellipse([W//2 - 18, 680 - 18, W//2 + 18, 680 + 18], fill=(255, 200, 255, 255))

    gorget = [(W//2 - 65, 520), (W//2 + 65, 520), (W//2 + 80, 610), (W//2 - 80, 610)]
    draw.polygon(gorget, fill=(24, 7, 32, 255), outline=(160, 40, 210, 255))

    spires = [
        (W//2 - 80, 390), (W//2 - 180, 240), (W//2 - 160, 220), (W//2 - 70, 350),
        (W//2 - 50, 340), (W//2 - 90, 140), (W//2 - 70, 120), (W//2 - 30, 310),
        (W//2 - 15, 290), (W//2, 80), (W//2 + 15, 290),
        (W//2 + 30, 310), (W//2 + 70, 120), (W//2 + 90, 140), (W//2 + 50, 340),
        (W//2 + 70, 350), (W//2 + 160, 220), (W//2 + 180, 240), (W//2 + 80, 390)
    ]
    draw.polygon(spires, fill=(15, 4, 20, 255), outline=(210, 70, 255, 255))
    glow_draw.polygon(spires, outline=(240, 100, 255, 200))

    helm = [
        (W//2, 330), (W//2 + 70, 390), (W//2 + 60, 480),
        (W//2, 530), (W//2 - 60, 480), (W//2 - 70, 390)
    ]
    draw.polygon(helm, fill=(12, 3, 18, 255), outline=(190, 50, 240, 255))

    v_eye_l = [(W//2 - 38, 425), (W//2 - 16, 422), (W//2 - 20, 432), (W//2 - 38, 430)]
    v_eye_r = [(W//2 + 16, 422), (W//2 + 38, 425), (W//2 + 38, 430), (W//2 + 20, 432)]
    glow_draw.polygon(v_eye_l, fill=(255, 210, 255, 255))
    glow_draw.polygon(v_eye_r, fill=(255, 210, 255, 255))
    glow_draw.line([(W//2 - 60, 427), (W//2 - 5, 427)], fill=(255, 30, 200, 255), width=4)
    glow_draw.line([(W//2 + 5, 427), (W//2 + 60, 427)], fill=(255, 30, 200, 255), width=4)

    for vy in range(460, 500, 8):
        draw.line([(W//2 - 25, vy), (W//2 + 25, vy)], fill=(180, 30, 220, 255), width=2)
        glow_draw.line([(W//2 - 25, vy), (W//2 + 25, vy)], fill=(255, 80, 240, 180), width=1)

    img = apply_glow(base, glow, blur_radius=13, intensity=1.5)
    frame_draw = ImageDraw.Draw(img)
    draw_ornate_boss_frame(frame_draw, "beritra", W, H)

    out_path = os.path.join(TARGET_DIR, "boss_beritra.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# BOSS 4: ERESHKIGAL
# ==============================================================================
def render_ereshkigal():
    print("Rendering Dragon Lord of Ice and Death: Ereshkigal...")
    bg_arr = create_radial_gradient(W, H, W//2, H//2 - 30, (20, 55, 95, 255), (4, 12, 26, 255))
    base = Image.fromarray(bg_arr.astype(np.uint8))
    draw = ImageDraw.Draw(base)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    for ang in range(0, 360, 30):
        rad = math.radians(ang)
        x1 = W//2 + math.cos(rad) * 120
        y1 = 450 + math.sin(rad) * 90
        x2 = W//2 + math.cos(rad + 1.2) * 440
        y2 = 450 + math.sin(rad + 1.2) * 360
        glow_draw.line([(x1, y1), (x2, y2)], fill=(150, 220, 255, 60), width=8)

    random.seed(777)
    for _ in range(160):
        ix = random.randint(60, W - 60)
        iy = random.randint(60, H - 60)
        ir = random.randint(2, 7)
        for sa in range(0, 180, 60):
            srad = math.radians(sa)
            dx = math.cos(srad) * ir
            dy = math.sin(srad) * ir
            glow_draw.line([(ix - dx, iy - dy), (ix + dx, iy + dy)], fill=(220, 245, 255, 210), width=1)

    wing_l = [(W//2, 620), (80, 240), (120, 420), (70, 600), (W//2, 850)]
    wing_r = [(W//2, 620), (W - 80, 240), (W - 120, 420), (W - 70, 600), (W//2, 850)]
    draw.polygon(wing_l, fill=(14, 38, 62, 255), outline=(130, 210, 255, 255))
    draw.polygon(wing_r, fill=(14, 38, 62, 255), outline=(130, 210, 255, 255))

    gown = [
        (W//2 - 210, H), (W//2 - 170, 720), (W//2 - 100, 610),
        (W//2 + 100, 610), (W//2 + 170, 720), (W//2 + 210, H)
    ]
    draw.polygon(gown, fill=(20, 48, 78, 255), outline=(150, 220, 255, 255))

    collar = [(W//2 - 70, 500), (W//2 + 70, 500), (W//2 + 95, 620), (W//2 - 95, 620)]
    draw.polygon(collar, fill=(35, 80, 120, 255), outline=(200, 240, 255, 255))
    glow_draw.polygon(collar, outline=(180, 230, 255, 180))

    neck = [(W//2 - 42, 450), (W//2 + 42, 450), (W//2 + 55, 530), (W//2 - 55, 530)]
    draw.polygon(neck, fill=(210, 230, 245, 255), outline=(130, 180, 215, 255))

    for side in [-1, 1]:
        h_main = [
            (W//2 + side * 40, 390), (W//2 + side * 120, 310), (W//2 + side * 230, 210),
            (W//2 + side * 340, 90), (W//2 + side * 355, 60), (W//2 + side * 315, 120),
            (W//2 + side * 205, 235), (W//2 + side * 95, 335), (W//2 + side * 30, 405)
        ]
        draw.polygon(h_main, fill=(80, 170, 225, 220), outline=(230, 250, 255, 255))
        glow_draw.polygon(h_main, fill=(150, 220, 255, 120))
        glow_draw.line(h_main[:5], fill=(255, 255, 255, 255), width=2)

        h_sub = [
            (W//2 + side * 60, 340), (W//2 + side * 150, 240), (W//2 + side * 200, 150),
            (W//2 + side * 180, 180), (W//2 + side * 130, 270), (W//2 + side * 50, 360)
        ]
        draw.polygon(h_sub, fill=(60, 140, 200, 220), outline=(210, 245, 255, 255))
        glow_draw.polygon(h_sub, fill=(130, 210, 255, 100))

    face = [
        (W//2, 330), (W//2 + 55, 380), (W//2 + 45, 440),
        (W//2, 475), (W//2 - 45, 440), (W//2 - 55, 380)
    ]
    draw.polygon(face, fill=(225, 238, 248, 255), outline=(140, 190, 225, 255))

    diadem = [
        (W//2 - 50, 360), (W//2 - 25, 335), (W//2, 320),
        (W//2 + 25, 335), (W//2 + 50, 360), (W//2, 375)
    ]
    draw.polygon(diadem, fill=(100, 190, 240, 255), outline=(255, 255, 255, 255))
    glow_draw.ellipse([W//2 - 12, 350 - 12, W//2 + 12, 350 + 12], fill=(0, 240, 255, 255))
    glow_draw.ellipse([W//2 - 5, 346, W//2 + 2, 353], fill=(255, 255, 255, 255))

    f_eye_l = [(W//2 - 34, 400), (W//2 - 14, 396), (W//2 - 18, 404), (W//2 - 34, 402)]
    f_eye_r = [(W//2 + 14, 396), (W//2 + 34, 400), (W//2 + 34, 402), (W//2 + 18, 404)]
    glow_draw.polygon(f_eye_l, fill=(245, 255, 255, 255))
    glow_draw.polygon(f_eye_r, fill=(245, 255, 255, 255))
    glow_draw.line([(W//2 - 55, 401), (W//2 - 5, 401)], fill=(0, 210, 255, 255), width=3)
    glow_draw.line([(W//2 + 5, 401), (W//2 + 55, 401)], fill=(0, 210, 255, 255), width=3)

    draw.line([(W//2 - 14, 446), (W//2, 448), (W//2 + 14, 446)], fill=(120, 160, 200, 255), width=2)

    img = apply_glow(base, glow, blur_radius=12, intensity=1.4)
    frame_draw = ImageDraw.Draw(img)
    draw_ornate_boss_frame(frame_draw, "ereshkigal", W, H)

    out_path = os.path.join(TARGET_DIR, "boss_ereshkigal.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# BOSS 5: KROMEDE THE CORRUPT
# ==============================================================================
def render_kromede():
    print("Rendering Kromede the Corrupt...")
    bg_arr = create_radial_gradient(W, H, W//2, H//2, (45, 12, 18, 255), (8, 2, 4, 255))
    base = Image.fromarray(bg_arr.astype(np.uint8))
    draw = ImageDraw.Draw(base)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    for ax in [W//2 - 280, W//2, W//2 + 280]:
        arch = [
            (ax - 90, 750), (ax - 90, 360), (ax - 45, 240),
            (ax, 200), (ax + 45, 240), (ax + 90, 360), (ax + 90, 750)
        ]
        draw.line(arch, fill=(75, 20, 28, 200), width=4)

    cx, cy = W // 2, 380
    r_inner = 170
    r_outer = 250
    for i in range(24):
        ang = i * (360 / 24)
        rad = math.radians(ang)
        x1 = cx + math.cos(rad) * r_inner
        y1 = cy + math.sin(rad) * r_inner
        x2 = cx + math.cos(rad) * r_outer
        y2 = cy + math.sin(rad) * r_outer
        draw.line([(x1, y1), (x2, y2)], fill=(225, 185, 75, 255), width=3)
        glow_draw.line([(x1, y1), (x2, y2)], fill=(255, 210, 90, 160), width=4)
    glow_draw.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], outline=(255, 195, 70, 220), width=3)

    random.seed(999)
    for _ in range(80):
        px = random.randint(80, W - 80)
        py = random.randint(80, H - 80)
        pr = random.randint(4, 9)
        draw.ellipse([px - pr, py - pr*0.6, px + pr, py + pr*0.6], fill=(170, 20, 35, 200), outline=(255, 60, 80, 180))

    hair_l = [(W//2 - 60, 350), (W//2 - 160, 480), (W//2 - 220, 680), (W//2 - 160, 850), (W//2 - 80, 650)]
    hair_r = [(W//2 + 60, 350), (W//2 + 160, 480), (W//2 + 220, 680), (W//2 + 160, 850), (W//2 + 80, 650)]
    draw.polygon(hair_l, fill=(12, 4, 8, 255), outline=(45, 15, 22, 255))
    draw.polygon(hair_r, fill=(12, 4, 8, 255), outline=(45, 15, 22, 255))

    vest = [
        (W//2 - 200, H), (W//2 - 160, 710), (W//2 - 90, 580),
        (W//2 + 90, 580), (W//2 + 160, 710), (W//2 + 200, H)
    ]
    draw.polygon(vest, fill=(35, 10, 15, 255), outline=(190, 140, 60, 255))

    collar = [(W//2 - 65, 490), (W//2 + 65, 490), (W//2 + 85, 590), (W//2 - 85, 590)]
    draw.polygon(collar, fill=(185, 140, 50, 255), outline=(255, 215, 90, 255))
    draw.polygon([(W//2, 530), (W//2 + 15, 550), (W//2, 570), (W//2 - 15, 550)], fill=(220, 20, 40, 255), outline=(255, 255, 255, 240))
    glow_draw.ellipse([W//2 - 12, 550 - 12, W//2 + 12, 550 + 12], fill=(255, 40, 60, 220))

    neck = [(W//2 - 38, 430), (W//2 + 38, 430), (W//2 + 48, 510), (W//2 - 48, 510)]
    draw.polygon(neck, fill=(235, 220, 215, 255), outline=(160, 120, 115, 255))

    face = [
        (W//2, 320), (W//2 + 48, 365), (W//2 + 40, 420),
        (W//2, 455), (W//2 - 40, 420), (W//2 - 48, 365)
    ]
    draw.polygon(face, fill=(245, 230, 225, 255), outline=(175, 130, 125, 255))

    tiara = [
        (W//2 - 50, 335), (W//2 - 25, 310), (W//2, 295),
        (W//2 + 25, 310), (W//2 + 50, 335), (W//2, 345)
    ]
    draw.polygon(tiara, fill=(180, 135, 50, 255), outline=(255, 215, 90, 255))

    k_eye_l = [(W//2 - 30, 380), (W//2 - 12, 376), (W//2 - 16, 384), (W//2 - 30, 382)]
    k_eye_r = [(W//2 + 12, 376), (W//2 + 30, 380), (W//2 + 30, 382), (W//2 + 16, 384)]
    glow_draw.polygon(k_eye_l, fill=(255, 180, 120, 255))
    glow_draw.polygon(k_eye_r, fill=(255, 180, 120, 255))

    tear_l = [(W//2 - 22, 384), (W//2 - 24, 405), (W//2 - 20, 430), (W//2 - 23, 465), (W//2 - 25, 495)]
    tear_r = [(W//2 + 22, 384), (W//2 + 24, 405), (W//2 + 20, 430), (W//2 + 23, 465), (W//2 + 25, 495)]
    glow_draw.line(tear_l, fill=(255, 20, 40, 240), width=4)
    glow_draw.line(tear_l, fill=(255, 150, 170, 255), width=1)
    glow_draw.line(tear_r, fill=(255, 20, 40, 240), width=4)
    glow_draw.line(tear_r, fill=(255, 150, 170, 255), width=1)

    draw.line([(W//2 - 12, 428), (W//2, 431), (W//2 + 12, 428)], fill=(160, 30, 45, 255), width=2)

    bx, by = W//2 - 240, 680
    draw.line([(bx, by - 80), (bx, by + 100)], fill=(200, 150, 60, 255), width=4)
    draw.line([(bx - 80, by - 60), (bx + 80, by - 20)], fill=(225, 180, 75, 255), width=4)
    draw.line([(bx - 80, by - 60), (bx - 100, by - 10)], fill=(180, 130, 50, 255), width=2)
    draw.line([(bx - 80, by - 60), (bx - 60, by - 10)], fill=(180, 130, 50, 255), width=2)
    draw.arc([bx - 105, by - 20, bx - 55, by + 5], 0, 180, fill=(230, 180, 70, 255), width=3)
    draw.line([(bx + 80, by - 20), (bx + 60, by + 30)], fill=(180, 130, 50, 255), width=2)
    draw.line([(bx + 80, by - 20), (bx + 100, by + 30)], fill=(180, 130, 50, 255), width=2)
    draw.arc([bx + 55, by + 20, bx + 105, by + 45], 0, 180, fill=(230, 180, 70, 255), width=3)
    glow_draw.ellipse([bx + 70, by + 15, bx + 90, by + 35], fill=(255, 30, 60, 220))

    img = apply_glow(base, glow, blur_radius=11, intensity=1.4)
    frame_draw = ImageDraw.Draw(img)
    draw_ornate_boss_frame(frame_draw, "kromede", W, H)

    out_path = os.path.join(TARGET_DIR, "boss_kromede.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# BOSS 6: TAHABATA PYRELORD
# ==============================================================================
def render_tahabata():
    print("Rendering Tahabata Pyrelord of Dark Poeta...")
    bg_arr = create_radial_gradient(W, H, W//2, H//2 + 30, (70, 15, 5, 255), (12, 2, 2, 255))
    base = Image.fromarray(bg_arr.astype(np.uint8))
    draw = ImageDraw.Draw(base)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    for sx, sh in [(180, 420), (320, 520), (W - 320, 520), (W - 180, 420)]:
        spire = [(sx - 35, 750), (sx, 750 - sh), (sx + 35, 750)]
        draw.polygon(spire, fill=(20, 4, 4, 230), outline=(100, 25, 10, 230))
        glow_draw.line([(sx, 750 - sh), (sx, 750)], fill=(255, 60, 10, 120), width=2)

    random.seed(666)
    for _ in range(15):
        mx = random.randint(100, W - 100)
        my = random.randint(50, 300)
        glow_draw.line([(mx, my), (mx - 60, my + 140)], fill=(255, 120, 20, 240), width=4)
        glow_draw.line([(mx, my), (mx - 60, my + 140)], fill=(255, 230, 100, 255), width=1)

    torso = [
        (W//2 - 250, H), (W//2 - 200, 720), (W//2 - 120, 600),
        (W//2 + 120, 600), (W//2 + 200, 720), (W//2 + 250, H)
    ]
    draw.polygon(torso, fill=(28, 8, 4, 255), outline=(140, 35, 10, 255))

    for yb in range(630, 880, 50):
        plate = [
            (W//2 - 150, yb), (W//2, yb + 30), (W//2 + 150, yb),
            (W//2 + 140, yb + 42), (W//2, yb + 55), (W//2 - 140, yb + 42)
        ]
        draw.polygon(plate, fill=(38, 10, 6, 255), outline=(190, 50, 15, 255))
        glow_draw.line([(W//2 - 130, yb + 25), (W//2, yb + 40), (W//2 + 130, yb + 25)], fill=(255, 100, 10, 240), width=4)
        glow_draw.line([(W//2 - 130, yb + 25), (W//2, yb + 40), (W//2 + 130, yb + 25)], fill=(255, 230, 60, 255), width=1)

    neck = [(W//2 - 80, 480), (W//2 + 80, 480), (W//2 + 100, 620), (W//2 - 100, 620)]
    draw.polygon(neck, fill=(35, 10, 6, 255), outline=(120, 30, 10, 255))

    for side in [-1, 1]:
        h_pri = [
            (W//2 + side * 50, 410), (W//2 + side * 150, 330), (W//2 + side * 270, 230),
            (W//2 + side * 370, 100), (W//2 + side * 385, 70), (W//2 + side * 340, 130),
            (W//2 + side * 230, 250), (W//2 + side * 120, 360), (W//2 + side * 40, 420)
        ]
        draw.polygon(h_pri, fill=(35, 8, 4, 255), outline=(230, 70, 15, 255))
        glow_draw.polygon(h_pri, fill=(255, 90, 10, 160))
        h_core = [
            (W//2 + side * 60, 400), (W//2 + side * 150, 325), (W//2 + side * 260, 225),
            (W//2 + side * 360, 105), (W//2 + side * 335, 135), (W//2 + side * 225, 245)
        ]
        glow_draw.polygon(h_core, fill=(255, 220, 90, 220))
        glow_draw.line(h_pri[:5], fill=(255, 255, 220, 255), width=3)

        h_sec = [
            (W//2 + side * 70, 450), (W//2 + side * 170, 400), (W//2 + side * 250, 330),
            (W//2 + side * 230, 360), (W//2 + side * 150, 430), (W//2 + side * 60, 465)
        ]
        draw.polygon(h_sec, fill=(30, 6, 4, 255), outline=(200, 50, 10, 255))
        glow_draw.polygon(h_sec, fill=(255, 80, 10, 140))

    head = [
        (W//2, 350), (W//2 + 85, 420), (W//2 + 75, 490),
        (W//2 + 45, 550), (W//2, 580), (W//2 - 45, 550),
        (W//2 - 75, 490), (W//2 - 85, 420)
    ]
    draw.polygon(head, fill=(38, 10, 6, 255), outline=(160, 40, 10, 255))

    maw = [(W//2 - 40, 515), (W//2, 540), (W//2 + 40, 515), (W//2, 575)]
    draw.polygon(maw, fill=(15, 2, 2, 255), outline=(255, 90, 10, 255))
    glow_draw.polygon(maw, fill=(255, 120, 20, 220))
    for lx in range(W//2 - 30, W//2 + 30, 8):
        drop_len = random.randint(25, 65)
        glow_draw.line([(lx, 550), (lx, 550 + drop_len)], fill=(255, 140, 20, 255), width=3)
        glow_draw.line([(lx, 550), (lx, 550 + drop_len)], fill=(255, 240, 100, 255), width=1)
        glow_draw.ellipse([lx - 3, 550 + drop_len - 3, lx + 3, 550 + drop_len + 3], fill=(255, 240, 80, 255))

    for tx in range(W//2 - 35, W//2 + 35, 12):
        draw.line([(tx, 515), (tx + 4, 528)], fill=(255, 240, 180, 255), width=2)
        draw.line([(tx, 565), (tx + 4, 552)], fill=(255, 240, 180, 255), width=2)

    t_eye_l = [(W//2 - 50, 440), (W//2 - 25, 436), (W//2 - 30, 448), (W//2 - 50, 445)]
    t_eye_r = [(W//2 + 25, 436), (W//2 + 50, 440), (W//2 + 50, 445), (W//2 + 30, 448)]
    glow_draw.polygon(t_eye_l, fill=(255, 255, 200, 255))
    glow_draw.polygon(t_eye_r, fill=(255, 255, 200, 255))
    glow_draw.line([(W//2 - 75, 442), (W//2 - 15, 442)], fill=(255, 120, 15, 255), width=5)
    glow_draw.line([(W//2 + 15, 442), (W//2 + 75, 442)], fill=(255, 120, 15, 255), width=5)

    img = apply_glow(base, glow, blur_radius=14, intensity=1.5)
    frame_draw = ImageDraw.Draw(img)
    draw_ornate_boss_frame(frame_draw, "tahabata", W, H)

    out_path = os.path.join(TARGET_DIR, "boss_tahabata.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path} ({os.path.getsize(out_path)} bytes)")


def main():
    ensure_dir(TARGET_DIR)
    print(f"Target directory verified: {TARGET_DIR}")
    render_tiamat()
    render_stormwing()
    render_beritra()
    render_ereshkigal()
    render_kromede()
    render_tahabata()
    print("ALL 6 AION-2 BOSS PORTRAITS SUCCESSFULLY GENERATED.")

if __name__ == "__main__":
    main()
