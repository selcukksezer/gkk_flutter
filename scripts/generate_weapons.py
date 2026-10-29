"""
High-detail, production-grade Aion-2 Legendary Weapon Icon Generator.
Generates 16 distinct 256x256 mythic equipment icons with ornate metallic frames,
weapon silhouettes, metallic gradients, elemental glows, runes, and particle effects.
"""

import os
import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

TARGET_DIR = os.path.abspath("assets/images/icons/weapons")
CANVAS_SIZE = 512
OUTPUT_SIZE = 256

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def create_base_canvas(bg_inner, bg_outer, noise_amount=12):
    """Creates a 512x512 atmospheric dark fantasy icon backdrop."""
    y, x = np.ogrid[:CANVAS_SIZE, :CANVAS_SIZE]
    cx, cy = CANVAS_SIZE / 2.0, CANVAS_SIZE / 2.0
    dist = np.hypot(x - cx, y - cy)
    radius = CANVAS_SIZE * 0.72
    t = np.clip(dist / radius, 0.0, 1.0)
    t = t * t * (3 - 2 * t)  # smoothstep
    
    img = np.zeros((CANVAS_SIZE, CANVAS_SIZE, 4), dtype=np.float32)
    for c in range(4):
        img[..., c] = bg_inner[c] * (1.0 - t) + bg_outer[c] * t
        
    if noise_amount > 0:
        noise = np.random.normal(0, noise_amount, (CANVAS_SIZE, CANVAS_SIZE, 1))
        img[..., :3] = np.clip(img[..., :3] + noise, 0, 255)
        
    return Image.fromarray(np.uint8(img), "RGBA")

def apply_glow_layer(base_img, glow_draw_func, blur_radius=16, blend_strength=1.4):
    """Renders a glow layer, blurs it, and composites it additively."""
    glow_img = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    glow_draw_func(glow_draw)
    
    blurred_glow = glow_img.filter(ImageFilter.GaussianBlur(blur_radius))
    
    # Additive blend via numpy
    base_arr = np.array(base_img, dtype=np.float32)
    glow_arr = np.array(blurred_glow, dtype=np.float32) * blend_strength
    
    alpha_factor = glow_arr[..., 3:4] / 255.0
    base_arr[..., :3] = np.clip(base_arr[..., :3] + glow_arr[..., :3] * alpha_factor, 0, 255)
    
    result = Image.fromarray(np.uint8(base_arr), "RGBA")
    result.alpha_composite(glow_img)
    return result

def draw_ornate_border(img, border_theme="gold"):
    """
    Renders an MMO legendary weapon icon border (beveled metal, corner filigree,
    rivets, and an inner rarity glow rim).
    """
    overlay = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    
    if border_theme == "gold":
        c_outer = (18, 14, 10, 255)
        c_metal_dark = (140, 95, 25, 255)
        c_metal_mid = (215, 160, 50, 255)
        c_metal_light = (255, 225, 130, 255)
        c_gem = (255, 60, 40, 255)
        c_inner_glow = (255, 190, 60, 100)
    elif border_theme == "obsidian":
        c_outer = (12, 10, 15, 255)
        c_metal_dark = (50, 45, 65, 255)
        c_metal_mid = (110, 85, 145, 255)
        c_metal_light = (190, 160, 235, 255)
        c_gem = (160, 40, 255, 255)
        c_inner_glow = (180, 80, 255, 100)
    elif border_theme == "frost":
        c_outer = (8, 15, 25, 255)
        c_metal_dark = (40, 80, 120, 255)
        c_metal_mid = (90, 160, 210, 255)
        c_metal_light = (200, 240, 255, 255)
        c_gem = (80, 220, 255, 255)
        c_inner_glow = (100, 200, 255, 100)
    elif border_theme == "crimson":
        c_outer = (20, 8, 8, 255)
        c_metal_dark = (90, 30, 25, 255)
        c_metal_mid = (175, 55, 45, 255)
        c_metal_light = (255, 140, 110, 255)
        c_gem = (255, 220, 80, 255)
        c_inner_glow = (255, 70, 40, 100)
    else: # silver / steel
        c_outer = (15, 16, 20, 255)
        c_metal_dark = (70, 75, 85, 255)
        c_metal_mid = (140, 150, 165, 255)
        c_metal_light = (230, 235, 245, 255)
        c_gem = (100, 180, 255, 255)
        c_inner_glow = (140, 170, 210, 100)
        
    pad = 12
    # Outer dark beveled rim
    draw.rectangle([pad, pad, CANVAS_SIZE - pad, CANVAS_SIZE - pad], outline=c_outer, width=10)
    
    # Main metallic band
    draw.rectangle([pad + 8, pad + 8, CANVAS_SIZE - pad - 8, CANVAS_SIZE - pad - 8], outline=c_metal_dark, width=7)
    draw.rectangle([pad + 12, pad + 12, CANVAS_SIZE - pad - 12, CANVAS_SIZE - pad - 12], outline=c_metal_mid, width=4)
    # Highlight rim
    draw.rectangle([pad + 15, pad + 15, CANVAS_SIZE - pad - 15, CANVAS_SIZE - pad - 15], outline=c_metal_light, width=2)
    # Inner dark shadow line
    draw.rectangle([pad + 18, pad + 18, CANVAS_SIZE - pad - 18, CANVAS_SIZE - pad - 18], outline=(10, 10, 15, 200), width=3)
    
    # Ornate corner brackets
    c_size = 46
    for cx, cy, flip_x, flip_y in [
        (pad + 6, pad + 6, 1, 1),
        (CANVAS_SIZE - pad - 6, pad + 6, -1, 1),
        (pad + 6, CANVAS_SIZE - pad - 6, 1, -1),
        (CANVAS_SIZE - pad - 6, CANVAS_SIZE - pad - 6, -1, -1)
    ]:
        poly = [
            (cx, cy),
            (cx + flip_x * c_size, cy),
            (cx + flip_x * (c_size - 14), cy + flip_y * 14),
            (cx + flip_x * 14, cy + flip_y * (c_size - 14)),
            (cx, cy + flip_y * c_size)
        ]
        draw.polygon(poly, fill=c_metal_mid, outline=c_metal_light)
        
        # Corner gem cabochon
        gx, gy = cx + flip_x * 16, cy + flip_y * 16
        draw.ellipse([gx - 6, gy - 6, gx + 6, gy + 6], fill=c_gem, outline=(255, 255, 255, 220))
        draw.ellipse([gx - 2, gy - 2, gx + 1, gy + 1], fill=(255, 255, 255, 240))
        
    # Inner soft glow margin
    glow_rim = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_rim)
    glow_draw.rectangle([pad + 20, pad + 20, CANVAS_SIZE - pad - 20, CANVAS_SIZE - pad - 20], outline=c_inner_glow, width=6)
    glow_rim = glow_rim.filter(ImageFilter.GaussianBlur(6))
    
    img.alpha_composite(glow_rim)
    img.alpha_composite(overlay)
    return img

def render_weapon_tiamat_greatsword():
    """Molten jagged colossal sword with pulsing dragon eye."""
    base = create_base_canvas((45, 12, 8, 255), (10, 5, 5, 255))
    draw = ImageDraw.Draw(base)
    
    # Background volcanic embers
    for _ in range(60):
        ex = random.randint(30, 480)
        ey = random.randint(30, 480)
        er = random.uniform(1.5, 4.5)
        c = random.choice([(255, 80, 20, 200), (255, 160, 40, 220), (255, 220, 80, 240)])
        draw.ellipse([ex - er, ey - er, ex + er, ey + er], fill=c)
        
    # Weapon angle: diagonal from bottom-left (120, 420) to top-right (390, 90)
    blade_poly = [
        (390, 80),   # Tip
        (405, 120),  # Right serration 1
        (380, 140),  # Inset 1
        (400, 180),  # Serration 2
        (365, 210),  # Inset 2
        (385, 260),  # Serration 3
        (345, 300),  # Blade base right
        (300, 340),  # Blade base left
        (260, 290),  # Serration left 3
        (290, 250),  # Inset left 2
        (245, 200),  # Serration left 2
        (280, 160),  # Inset left 1
        (240, 115),  # Serration left 1
        (320, 95)    # Upper left near tip
    ]
    draw.polygon(blade_poly, fill=(28, 24, 25, 255), outline=(75, 25, 15, 255))
    
    # Molten inner core & veins
    vein_poly = [
        (385, 95), (370, 150), (360, 220), (330, 280), (315, 320),
        (305, 320), (315, 270), (330, 210), (350, 140), (380, 95)
    ]
    draw.polygon(vein_poly, fill=(230, 65, 15, 255))
    
    # Dragon Bone Crossguard
    guard_poly = [
        (340, 310), (385, 320), (410, 350), (370, 360),
        (310, 350), (280, 385), (250, 415), (240, 380),
        (265, 340), (300, 325)
    ]
    draw.polygon(guard_poly, fill=(55, 35, 28, 255), outline=(180, 90, 30, 255))
    
    # Hilt and pommel
    draw.line([(285, 365), (200, 435)], fill=(35, 25, 20, 255), width=18)
    draw.line([(285, 365), (200, 435)], fill=(190, 110, 35, 255), width=8)
    # Dragon skull pommel
    draw.ellipse([180, 420, 215, 455], fill=(50, 35, 30, 255), outline=(220, 120, 40, 255), width=3)
    
    # Dragon Eye in crossguard center
    eye_cx, eye_cy = 315, 345
    draw.ellipse([eye_cx - 20, eye_cy - 14, eye_cx + 20, eye_cy + 14], fill=(20, 5, 0, 255))
    draw.ellipse([eye_cx - 16, eye_cy - 10, eye_cx + 16, eye_cy + 10], fill=(255, 170, 20, 255))
    draw.ellipse([eye_cx - 10, eye_cy - 6, eye_cx + 10, eye_cy + 6], fill=(255, 240, 80, 255))
    # Vertical dragon pupil
    draw.polygon([(eye_cx - 3, eye_cy - 10), (eye_cx + 3, eye_cy - 10), (eye_cx + 1, eye_cy + 10), (eye_cx - 1, eye_cy + 10)], fill=(0, 0, 0, 255))
    
    # Molten glow effect
    def draw_glow(g):
        g.line([(385, 95), (320, 310)], fill=(255, 110, 20, 255), width=12)
        g.ellipse([eye_cx - 28, eye_cy - 22, eye_cx + 28, eye_cy + 22], fill=(255, 140, 30, 220))
        for p in [(400, 120), (395, 180), (380, 250), (255, 130), (275, 210)]:
            g.ellipse([p[0]-15, p[1]-15, p[0]+15, p[1]+15], fill=(255, 80, 10, 190))
            
    base = apply_glow_layer(base, draw_glow, blur_radius=20, blend_strength=1.6)
    return draw_ornate_border(base, "crimson")

def render_weapon_stormwing_dagger():
    """Lightning-crackling curved dagger forged from blue dragon scales."""
    base = create_base_canvas((15, 25, 55, 255), (5, 8, 18, 255))
    draw = ImageDraw.Draw(base)
    
    blade_poly = [
        (380, 100),
        (385, 140), (370, 160), (380, 200), (360, 230), (370, 275), (345, 310),
        (300, 335),
        (265, 300), (290, 250), (305, 195), (330, 145), (380, 100)
    ]
    draw.polygon(blade_poly, fill=(25, 75, 130, 255), outline=(70, 160, 230, 255))
    
    for sy in range(140, 300, 25):
        draw.arc([310, sy, 360, sy + 30], start=0, end=180, fill=(100, 200, 255, 200), width=3)
        
    draw.polygon([(300, 335), (330, 325), (345, 355), (290, 375)], fill=(15, 35, 65, 255), outline=(60, 130, 210, 255))
    draw.line([(290, 360), (210, 425)], fill=(20, 40, 70, 255), width=16)
    for t in np.linspace(0, 1, 7):
        gx = int(290 * (1-t) + 210 * t)
        gy = int(360 * (1-t) + 425 * t)
        draw.line([(gx - 8, gy - 6), (gx + 8, gy + 6)], fill=(120, 210, 255, 255), width=3)
    draw.polygon([(210, 425), (180, 440), (195, 465), (225, 445)], fill=(30, 70, 120, 255), outline=(130, 220, 255, 255))
    
    def draw_lightning(g):
        points = [(380, 100), (360, 150), (395, 175), (345, 220), (380, 260), (315, 310), (335, 370)]
        for i in range(len(points)-1):
            g.line([points[i], points[i+1]], fill=(140, 230, 255, 255), width=4)
        g.line([(360, 150), (310, 160)], fill=(180, 240, 255, 220), width=2)
        g.line([(345, 220), (270, 230)], fill=(180, 240, 255, 220), width=2)
        g.line([(380, 260), (430, 275)], fill=(180, 240, 255, 220), width=2)
        for _ in range(40):
            sx = random.randint(220, 430)
            sy = random.randint(90, 380)
            g.ellipse([sx-3, sy-3, sx+3, sy+3], fill=(220, 250, 255, 255))
            
    base = apply_glow_layer(base, draw_lightning, blur_radius=15, blend_strength=1.8)
    return draw_ornate_border(base, "frost")

def render_weapon_empyrean_longbow():
    """Gilded recurve bow adorned with angelic wings and radiant string."""
    base = create_base_canvas((35, 28, 12, 255), (10, 8, 5, 255))
    draw = ImageDraw.Draw(base)
    
    for i in range(6):
        fx = 160 + i * 32
        fy = 80 + i * 28
        draw.polygon([(fx, fy), (fx + 40, fy - 15), (fx + 65, fy + 10), (fx + 20, fy + 25)],
                     fill=(240, 220, 160, 255), outline=(180, 140, 40, 255))
    for i in range(6):
        fx = 160 + i * 32
        fy = 432 - i * 28
        draw.polygon([(fx, fy), (fx + 40, fy + 15), (fx + 65, fy - 10), (fx + 20, fy - 25)],
                     fill=(240, 220, 160, 255), outline=(180, 140, 40, 255))
        
    points = [
        (150, 80), (220, 120), (280, 175), (330, 230), (345, 256),
        (330, 282), (280, 337), (220, 392), (150, 432)
    ]
    for i in range(len(points)-1):
        draw.line([points[i], points[i+1]], fill=(255, 205, 75, 255), width=16)
        draw.line([points[i], points[i+1]], fill=(255, 245, 180, 255), width=6)
        
    draw.rectangle([330, 235, 355, 277], fill=(160, 100, 25, 255), outline=(255, 220, 90, 255), width=3)
    draw.ellipse([335, 248, 350, 264], fill=(40, 130, 240, 255), outline=(255, 255, 255, 255))
    
    draw.ellipse([140, 70, 160, 90], fill=(255, 220, 80, 255), outline=(255, 255, 255, 255))
    draw.ellipse([140, 422, 160, 442], fill=(255, 220, 80, 255), outline=(255, 255, 255, 255))
    
    def draw_string_glow(g):
        g.line([(150, 80), (150, 432)], fill=(255, 250, 210, 255), width=4)
        g.line([(130, 256), (380, 256)], fill=(255, 240, 160, 255), width=6)
        g.polygon([(380, 256), (360, 246), (360, 266)], fill=(255, 255, 230, 255))
        for flare_pos in [(345, 256), (150, 80), (150, 432)]:
            cx, cy = flare_pos
            g.ellipse([cx-25, cy-25, cx+25, cy+25], fill=(255, 220, 90, 160))
            g.line([(cx-40, cy), (cx+40, cy)], fill=(255, 255, 240, 240), width=3)
            g.line([(cx, cy-40), (cx, cy+40)], fill=(255, 255, 240, 240), width=3)
            
    base = apply_glow_layer(base, draw_string_glow, blur_radius=18, blend_strength=1.7)
    return draw_ornate_border(base, "gold")

def render_weapon_abyssal_orb():
    """Dark swirling void sphere bound by spiked obsidian rings."""
    base = create_base_canvas((25, 10, 40, 255), (5, 3, 10, 255))
    draw = ImageDraw.Draw(base)
    
    cx, cy = 256, 256
    
    for r in range(160, 90, -8):
        alpha = int(140 * (1 - (r - 90)/70.0))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(120, 40, 190, alpha), width=5)
        
    core_rad = 85
    draw.ellipse([cx - core_rad, cy - core_rad, cx + core_rad, cy + core_rad], fill=(12, 6, 20, 255), outline=(160, 60, 240, 255), width=4)
    draw.ellipse([cx - 55, cy - 55, cx + 55, cy + 55], fill=(45, 12, 75, 255))
    draw.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=(5, 2, 10, 255))
    
    ring_img = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(ring_img)
    r_draw.ellipse([cx - 150, cy - 55, cx + 150, cy + 55], outline=(90, 75, 110, 255), width=14)
    r_draw.ellipse([cx - 148, cy - 53, cx + 148, cy + 53], outline=(190, 140, 240, 255), width=3)
    for sp_x, sp_y in [(-150, 0), (150, 0), (-90, -42), (90, 42), (0, -55), (0, 55)]:
        px, py = cx + sp_x, cy + sp_y
        r_draw.polygon([(px-12, py-10), (px, py-30), (px+12, py-10)], fill=(40, 32, 50, 255), outline=(170, 120, 230, 255))
        
    ring1 = ring_img.rotate(35, center=(cx, cy))
    ring2 = ring_img.rotate(-45, center=(cx, cy))
    
    base.alpha_composite(ring1)
    base.alpha_composite(ring2)
    
    def draw_void_glow(g):
        g.ellipse([cx - 95, cy - 95, cx + 95, cy + 95], outline=(200, 80, 255, 220), width=6)
        g.ellipse([cx - 130, cy - 130, cx + 130, cy + 130], outline=(140, 40, 210, 140), width=10)
        for angle in [0, 60, 120, 180, 240, 300]:
            rad = math.radians(angle)
            gx = cx + int(115 * math.cos(rad))
            gy = cy + int(115 * math.sin(rad))
            g.ellipse([gx-8, gy-8, gx+8, gy+8], fill=(230, 120, 255, 240))
        for _ in range(50):
            px = cx + random.randint(-160, 160)
            py = cy + random.randint(-160, 160)
            g.ellipse([px-3, py-3, px+3, py+3], fill=(210, 100, 255, 200))
            
    base = apply_glow_layer(base, draw_void_glow, blur_radius=18, blend_strength=1.8)
    return draw_ornate_border(base, "obsidian")

def render_weapon_beritra_spellbook():
    """Tome bound in dragon leather with glowing purple runes."""
    base = create_base_canvas((30, 12, 45, 255), (8, 4, 12, 255))
    draw = ImageDraw.Draw(base)
    
    draw.polygon([(110, 120), (145, 100), (370, 125), (325, 410), (110, 375)],
                 fill=(40, 18, 55, 255), outline=(85, 35, 115, 255))
    
    for bx, by, dx, dy in [(145, 100, 1, 1), (370, 125, -1, 1), (110, 375, 1, -1), (325, 410, -1, -1)]:
        draw.polygon([(bx, by), (bx + dx * 40, by), (bx + dx * 30, by + dy * 30), (bx, by + dy * 40)],
                     fill=(210, 160, 60, 255), outline=(255, 230, 140, 255))
        
    draw.polygon([(370, 125), (400, 140), (355, 425), (325, 410)], fill=(210, 195, 165, 255), outline=(130, 110, 85, 255))
    for py in range(145, 415, 10):
        draw.line([(365, py), (395, py + 12)], fill=(160, 145, 120, 200), width=2)
        
    cx, cy = 230, 255
    draw.ellipse([cx - 55, cy - 55, cx + 55, cy + 55], fill=(30, 10, 45, 255), outline=(190, 130, 50, 255), width=5)
    draw.polygon([(cx, cy - 35), (cx + 30, cy + 20), (cx, cy + 10), (cx - 30, cy + 20)],
                 fill=(160, 40, 210, 255), outline=(255, 180, 255, 255), width=2)
    draw.ellipse([cx - 14, cy - 10, cx + 14, cy + 10], fill=(255, 50, 200, 255), outline=(255, 255, 255, 255))
    draw.line([(cx, cy - 10), (cx, cy + 10)], fill=(10, 0, 20, 255), width=3)
    
    def draw_spell_runes(g):
        g.ellipse([cx - 65, cy - 65, cx + 65, cy + 65], outline=(220, 80, 255, 180), width=6)
        rune_spots = [(360, 180), (390, 220), (410, 270), (380, 320), (250, 130), (290, 105)]
        for rx, ry in rune_spots:
            g.ellipse([rx-10, ry-10, rx+10, ry+10], outline=(230, 120, 255, 230), width=3)
            g.line([(rx-6, ry), (rx+6, ry)], fill=(255, 200, 255, 255), width=2)
            g.line([(rx, ry-6), (rx, ry+6)], fill=(255, 200, 255, 255), width=2)
        for _ in range(40):
            ax = random.randint(180, 420)
            ay = random.randint(90, 360)
            g.ellipse([ax-3, ay-3, ax+3, ay+3], fill=(240, 140, 255, 200))
            
    base = apply_glow_layer(base, draw_spell_runes, blur_radius=16, blend_strength=1.8)
    return draw_ornate_border(base, "obsidian")

def render_weapon_archdaeva_staff():
    """Crystalline lotus top staff radiating harmonic aether waves."""
    base = create_base_canvas((15, 30, 45, 255), (4, 10, 18, 255))
    draw = ImageDraw.Draw(base)
    
    draw.line([(150, 440), (340, 180)], fill=(210, 175, 75, 255), width=18)
    draw.line([(150, 440), (340, 180)], fill=(255, 235, 150, 255), width=6)
    
    for t in np.linspace(0.1, 0.9, 10):
        sx = int(150 * (1-t) + 340 * t)
        sy = int(440 * (1-t) + 180 * t)
        draw.ellipse([sx - 12, sy - 12, sx + 12, sy + 12], outline=(100, 220, 255, 220), width=3)
        
    draw.polygon([(140, 430), (130, 455), (155, 465), (165, 440)], fill=(80, 220, 255, 255), outline=(255, 255, 255, 255))
    
    lx, ly = 360, 150
    draw.polygon([(lx - 45, ly + 25), (lx + 25, ly + 45), (lx + 45, ly + 15), (lx - 15, ly - 20)],
                 fill=(225, 180, 60, 255), outline=(255, 230, 120, 255))
    
    petals = [
        [(lx, ly), (lx - 40, ly - 50), (lx - 10, ly - 70), (lx + 15, ly - 35)],
        [(lx, ly), (lx + 10, ly - 70), (lx + 50, ly - 60), (lx + 35, ly - 20)],
        [(lx, ly), (lx - 60, ly - 15), (lx - 65, ly + 15), (lx - 25, ly + 10)],
        [(lx, ly), (lx + 40, ly - 15), (lx + 65, ly + 10), (lx + 30, ly + 25)],
        [(lx, ly), (lx - 15, ly - 85), (lx + 20, ly - 85), (lx + 10, ly - 40)],
    ]
    for p in petals:
        draw.polygon(p, fill=(90, 215, 255, 240), outline=(220, 250, 255, 255), width=2)
        
    draw.ellipse([lx - 18, ly - 18, lx + 18, ly + 18], fill=(255, 255, 255, 255), outline=(80, 200, 255, 255), width=4)
    
    def draw_aether_waves(g):
        for rad in [45, 75, 105, 140]:
            g.ellipse([lx - rad, ly - rad, lx + rad, ly + rad], outline=(100, 230, 255, 170), width=4)
        for _ in range(45):
            sx = lx + random.randint(-140, 140)
            sy = ly + random.randint(-140, 140)
            g.ellipse([sx-3, sy-3, sx+3, sy+3], fill=(200, 250, 255, 220))
            
    base = apply_glow_layer(base, draw_aether_waves, blur_radius=18, blend_strength=1.8)
    return draw_ornate_border(base, "gold")

def render_weapon_tahabata_spear():
    """Brimstone halberd wreathed in roaring dragon fire."""
    base = create_base_canvas((40, 12, 6, 255), (10, 4, 3, 255))
    draw = ImageDraw.Draw(base)
    
    draw.line([(120, 430), (340, 190)], fill=(45, 30, 25, 255), width=18)
    draw.line([(120, 430), (340, 190)], fill=(180, 60, 20, 255), width=6)
    
    hx, hy = 360, 160
    spear_tip = [(hx - 15, hy + 30), (hx + 40, hy - 40), (hx + 55, hy - 80), (hx + 30, hy - 70), (hx - 30, hy + 15)]
    draw.polygon(spear_tip, fill=(35, 30, 32, 255), outline=(255, 120, 30, 255), width=3)
    
    axe_blade = [
        (hx - 20, hy + 20), (hx - 90, hy + 60), (hx - 140, hy + 10),
        (hx - 120, hy - 60), (hx - 60, hy - 40), (hx - 10, hy)
    ]
    draw.polygon(axe_blade, fill=(28, 25, 28, 255), outline=(240, 80, 20, 255), width=3)
    
    spike = [(hx + 10, hy + 20), (hx + 75, hy + 75), (hx + 85, hy + 55), (hx + 20, hy)]
    draw.polygon(spike, fill=(30, 28, 30, 255), outline=(220, 90, 25, 255), width=2)
    
    draw.line([(hx - 120, hy - 40), (hx - 40, hy + 10)], fill=(255, 180, 40, 255), width=4)
    draw.line([(hx - 90, hy + 30), (hx - 30, hy + 15)], fill=(255, 210, 60, 255), width=3)
    draw.line([(hx + 40, hy - 50), (hx - 10, hy + 15)], fill=(255, 160, 30, 255), width=4)
    
    def draw_tahabata_fire(g):
        flames = [
            [(hx - 140, hy + 10), (hx - 170, hy + 20), (hx - 150, hy - 20)],
            [(hx - 120, hy - 60), (hx - 150, hy - 90), (hx - 100, hy - 80)],
            [(hx + 55, hy - 80), (hx + 75, hy - 120), (hx + 40, hy - 100)],
            [(hx + 85, hy + 55), (hx + 120, hy + 75), (hx + 95, hy + 35)]
        ]
        for f in flames:
            g.polygon(f, fill=(255, 120, 20, 230))
        for _ in range(70):
            fx = hx + random.randint(-150, 90)
            fy = hy + random.randint(-110, 100)
            fr = random.uniform(2.0, 6.0)
            c = random.choice([(255, 60, 10, 230), (255, 160, 20, 255), (255, 240, 90, 255)])
            g.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=c)
            
    base = apply_glow_layer(base, draw_tahabata_fire, blur_radius=20, blend_strength=1.8)
    return draw_ornate_border(base, "crimson")

def render_weapon_divine_mace():
    """Heavy flanged morningstar inlaid with glowing yellow godstones."""
    base = create_base_canvas((35, 30, 10, 255), (10, 8, 4, 255))
    draw = ImageDraw.Draw(base)
    
    draw.line([(140, 420), (330, 190)], fill=(70, 70, 80, 255), width=22)
    draw.line([(140, 420), (330, 190)], fill=(225, 190, 80, 255), width=8)
    
    mx, my = 350, 165
    head_rad = 50
    draw.ellipse([mx - head_rad, my - head_rad, mx + head_rad, my + head_rad], fill=(60, 62, 70, 255), outline=(220, 180, 60, 255), width=5)
    
    for deg in range(0, 360, 60):
        rad = math.radians(deg)
        f_tip_x = mx + int(85 * math.cos(rad))
        f_tip_y = my + int(85 * math.sin(rad))
        f_b1_x = mx + int(45 * math.cos(rad - 0.35))
        f_b1_y = my + int(45 * math.sin(rad - 0.35))
        f_b2_x = mx + int(45 * math.cos(rad + 0.35))
        f_b2_y = my + int(45 * math.sin(rad + 0.35))
        draw.polygon([(f_b1_x, f_b1_y), (f_tip_x, f_tip_y), (f_b2_x, f_b2_y)], fill=(180, 140, 45, 255), outline=(255, 220, 110, 255), width=2)
        
    for deg in [30, 120, 210, 300]:
        rad = math.radians(deg)
        gx = mx + int(32 * math.cos(rad))
        gy = my + int(32 * math.sin(rad))
        draw.polygon([(gx, gy - 12), (gx + 12, gy), (gx, gy + 12), (gx - 12, gy)], fill=(255, 240, 70, 255), outline=(255, 255, 255, 255), width=2)
        
    def draw_godstone_glow(g):
        g.ellipse([mx - 65, my - 65, mx + 65, my + 65], outline=(255, 230, 90, 210), width=8)
        for deg in [0, 45, 90, 135]:
            rad = math.radians(deg)
            dx = int(120 * math.cos(rad))
            dy = int(120 * math.sin(rad))
            g.line([(mx - dx, my - dy), (mx + dx, my + dy)], fill=(255, 245, 160, 220), width=4)
        for _ in range(40):
            sx = mx + random.randint(-110, 110)
            sy = my + random.randint(-110, 110)
            g.ellipse([sx-3, sy-3, sx+3, sy+3], fill=(255, 255, 180, 240))
            
    base = apply_glow_layer(base, draw_godstone_glow, blur_radius=18, blend_strength=1.8)
    return draw_ornate_border(base, "gold")

def render_weapon_kallida_shield():
    """Heavy dragon-scale tower shield with golden Daevic emblem."""
    base = create_base_canvas((35, 15, 15, 255), (8, 4, 5, 255))
    draw = ImageDraw.Draw(base)
    
    cx, cy = 256, 256
    
    shield_poly = [
        (cx - 120, cy - 145), (cx + 120, cy - 145),
        (cx + 140, cy - 60),
        (cx + 125, cy + 60),
        (cx + 60, cy + 145),
        (cx, cy + 175),
        (cx - 60, cy + 145),
        (cx - 125, cy + 60),
        (cx - 140, cy - 60)
    ]
    draw.polygon(shield_poly, fill=(28, 20, 22, 255), outline=(170, 120, 40, 255), width=8)
    
    for row in range(-120, 140, 24):
        offset = 14 if (row // 24) % 2 == 0 else 0
        for col in range(-100 + offset, 110 - offset, 28):
            sx, sy = cx + col, cy + row
            scale_poly = [(sx, sy), (sx + 14, sy + 16), (sx, sy + 32), (sx - 14, sy + 16)]
            draw.polygon(scale_poly, fill=(80, 25, 22, 255), outline=(130, 45, 35, 255), width=2)
            
    draw.polygon([(cx, cy - 40), (cx + 80, cy - 90), (cx + 60, cy - 20), (cx + 25, cy + 10)],
                 fill=(235, 185, 60, 255), outline=(255, 240, 140, 255), width=3)
    draw.polygon([(cx, cy - 40), (cx - 80, cy - 90), (cx - 60, cy - 20), (cx - 25, cy + 10)],
                 fill=(235, 185, 60, 255), outline=(255, 240, 140, 255), width=3)
    draw.ellipse([cx - 28, cy - 20, cx + 28, cy + 36], fill=(210, 40, 30, 255), outline=(255, 220, 90, 255), width=4)
    draw.polygon([(cx, cy - 10), (cx + 14, cy + 10), (cx, cy + 25), (cx - 14, cy + 10)], fill=(255, 225, 100, 255))
    
    def draw_shield_aura(g):
        g.polygon(shield_poly, outline=(255, 190, 60, 200), width=6)
        g.ellipse([cx - 45, cy - 10, cx + 45, cy + 45], fill=(255, 110, 40, 180))
        for _ in range(40):
            px = cx + random.randint(-120, 120)
            py = cy + random.randint(-120, 140)
            g.ellipse([px-3, py-3, px+3, py+3], fill=(255, 230, 140, 220))
            
    base = apply_glow_layer(base, draw_shield_aura, blur_radius=16, blend_strength=1.6)
    return draw_ornate_border(base, "crimson")

def render_weapon_aether_cannon():
    """Magitech steampunk heavy cannon with glowing mana chamber."""
    base = create_base_canvas((20, 28, 40, 255), (6, 8, 14, 255))
    draw = ImageDraw.Draw(base)
    
    b_pts = [(180, 400), (390, 170), (410, 190), (200, 420)]
    draw.polygon(b_pts, fill=(50, 55, 65, 255), outline=(130, 140, 160, 255), width=3)
    
    draw.ellipse([375, 145, 425, 195], fill=(160, 115, 45, 255), outline=(245, 200, 85, 255), width=5)
    draw.ellipse([385, 155, 415, 185], fill=(15, 20, 30, 255), outline=(80, 210, 255, 255), width=3)
    
    for py in range(250, 380, 35):
        draw.line([(py - 50, py + 30), (py + 10, py - 30)], fill=(195, 145, 55, 255), width=6)
    draw.line([(150, 330), (280, 200)], fill=(185, 95, 50, 255), width=8)
    
    cx, cy = 270, 270
    draw.rectangle([cx - 40, cy - 25, cx + 40, cy + 25], fill=(10, 40, 70, 255), outline=(210, 165, 60, 255), width=4)
    draw.rectangle([cx - 32, cy - 18, cx + 32, cy + 18], fill=(60, 190, 255, 255), outline=(255, 255, 255, 255), width=2)
    draw.ellipse([cx - 45, cy + 30, cx - 15, cy + 60], fill=(200, 160, 60, 255), outline=(60, 45, 20, 255), width=2)
    
    def draw_mana_glow(g):
        g.rectangle([cx - 35, cy - 20, cx + 35, cy + 20], fill=(120, 230, 255, 230))
        g.ellipse([385, 155, 415, 185], fill=(100, 230, 255, 240))
        g.line([(400, 170), (455, 115)], fill=(150, 240, 255, 255), width=8)
        for _ in range(45):
            px = random.randint(220, 440)
            py = random.randint(110, 320)
            g.ellipse([px-3, py-3, px+3, py+3], fill=(140, 240, 255, 220))
            
    base = apply_glow_layer(base, draw_mana_glow, blur_radius=16, blend_strength=1.8)
    return draw_ornate_border(base, "gold")

def render_weapon_shadow_pistol():
    """Revolver infused with dark aether and glowing cyan sights."""
    base = create_base_canvas((15, 18, 25, 255), (4, 5, 8, 255))
    draw = ImageDraw.Draw(base)
    
    draw.polygon([(150, 400), (175, 415), (220, 340), (190, 320)], fill=(30, 25, 35, 255), outline=(65, 60, 75, 255), width=3)
    draw.arc([190, 320, 240, 370], start=45, end=225, fill=(110, 115, 130, 255), width=4)
    draw.line([(205, 335), (212, 350)], fill=(160, 170, 185, 255), width=4)
    
    draw.rectangle([210, 260, 280, 325], fill=(38, 42, 50, 255), outline=(90, 95, 110, 255), width=3)
    for cy_i in range(270, 320, 16):
        draw.rectangle([220, cy_i, 270, cy_i + 10], fill=(10, 70, 95, 255), outline=(40, 220, 255, 255), width=2)
        
    barrel_poly = [(275, 270), (410, 170), (425, 190), (285, 290)]
    draw.polygon(barrel_poly, fill=(28, 30, 36, 255), outline=(85, 90, 105, 255), width=3)
    draw.line([(285, 292), (420, 195)], fill=(50, 55, 65, 255), width=6)
    
    draw.rectangle([405, 160, 415, 170], fill=(80, 245, 255, 255), outline=(255, 255, 255, 255))
    draw.rectangle([275, 255, 285, 265], fill=(80, 245, 255, 255), outline=(255, 255, 255, 255))
    
    def draw_shadow_glow(g):
        for cy_i in range(270, 320, 16):
            g.rectangle([225, cy_i + 2, 265, cy_i + 8], fill=(50, 240, 255, 240))
        g.ellipse([405, 160, 435, 190], fill=(60, 240, 255, 230))
        for _ in range(35):
            sx = random.randint(300, 440)
            sy = random.randint(130, 220)
            g.ellipse([sx-4, sy-4, sx+4, sy+4], fill=(80, 230, 255, 180))
            
    base = apply_glow_layer(base, draw_shadow_glow, blur_radius=15, blend_strength=1.8)
    return draw_ornate_border(base, "silver")

def render_weapon_kromede_rapier():
    """Slender silver rapier with blood-red ruby pommel."""
    base = create_base_canvas((25, 12, 18, 255), (8, 4, 6, 255))
    draw = ImageDraw.Draw(base)
    
    draw.line([(240, 280), (410, 100)], fill=(235, 240, 250, 255), width=7)
    draw.line([(240, 280), (410, 100)], fill=(255, 255, 255, 255), width=3)
    draw.polygon([(410, 100), (420, 90), (405, 105)], fill=(255, 255, 255, 255))
    
    cx, cy = 230, 290
    for r in [25, 45, 60]:
        draw.arc([cx - r, cy - r, cx + r, cy + r], start=30, end=240, fill=(200, 210, 225, 255), width=5)
    draw.line([(cx - 35, cy - 25), (cx + 35, cy + 25)], fill=(225, 230, 240, 255), width=8)
    
    draw.line([(cx - 10, cy + 10), (160, 370)], fill=(120, 130, 145, 255), width=12)
    for t in np.linspace(0, 1, 8):
        gx = int((cx - 10) * (1-t) + 160 * t)
        gy = int((cy + 10) * (1-t) + 370 * t)
        draw.line([(gx - 6, gy - 4), (gx + 6, gy + 4)], fill=(240, 245, 255, 255), width=2)
        
    px, py = 150, 380
    draw.ellipse([px - 18, py - 18, px + 18, py + 18], fill=(160, 15, 25, 255), outline=(225, 230, 240, 255), width=4)
    draw.polygon([(px, py - 12), (px + 12, py), (px, py + 12), (px - 12, py)], fill=(255, 40, 50, 255))
    draw.ellipse([px - 5, py - 5, px + 2, py + 2], fill=(255, 180, 190, 255))
    
    def draw_kromede_glint(g):
        g.ellipse([px - 25, py - 25, px + 25, py + 25], fill=(255, 30, 50, 180))
        tx, ty = 415, 95
        g.ellipse([tx - 15, ty - 15, tx + 15, ty + 15], fill=(255, 255, 255, 230))
        g.line([(tx - 25, ty), (tx + 25, ty)], fill=(255, 255, 255, 255), width=2)
        g.line([(tx, ty - 25), (tx, ty + 25)], fill=(255, 255, 255, 255), width=2)
        for _ in range(30):
            rx = random.randint(130, 420)
            ry = random.randint(90, 390)
            g.ellipse([rx-2, ry-2, rx+2, ry+2], fill=(255, 80, 100, 200))
            
    base = apply_glow_layer(base, draw_kromede_glint, blur_radius=14, blend_strength=1.7)
    return draw_ornate_border(base, "silver")

def render_weapon_flame_chakram():
    """Circular bladed throwing ring spinning with fire."""
    base = create_base_canvas((40, 18, 10, 255), (10, 5, 3, 255))
    draw = ImageDraw.Draw(base)
    
    cx, cy = 256, 256
    ring_r_out = 125
    ring_r_in = 80
    draw.ellipse([cx - ring_r_out, cy - ring_r_out, cx + ring_r_out, cy + ring_r_out],
                 fill=(40, 30, 30, 255), outline=(215, 140, 40, 255), width=6)
    draw.ellipse([cx - ring_r_in, cy - ring_r_in, cx + ring_r_in, cy + ring_r_in],
                 fill=(20, 8, 5, 255), outline=(230, 90, 20, 255), width=5)
    
    for deg in [0, 90, 180, 270]:
        rad = math.radians(deg)
        bx = cx + int(ring_r_out * math.cos(rad))
        by = cy + int(ring_r_out * math.sin(rad))
        tip_x = cx + int((ring_r_out + 45) * math.cos(rad + 0.45))
        tip_y = cy + int((ring_r_out + 45) * math.sin(rad + 0.45))
        base2_x = cx + int(ring_r_out * math.cos(rad + 0.6))
        base2_y = cy + int(ring_r_out * math.sin(rad + 0.6))
        draw.polygon([(bx, by), (tip_x, tip_y), (base2_x, base2_y)], fill=(225, 210, 200, 255), outline=(255, 140, 30, 255), width=2)
        
    def draw_chakram_fire(g):
        for r in range(ring_r_in, 10, -12):
            g.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 140, 30, 190), width=6)
        for deg in range(0, 360, 45):
            rad = math.radians(deg)
            for step in range(8):
                dist = step * 18
                rot = rad + step * 0.2
                fx = cx + int(dist * math.cos(rot))
                fy = cy + int(dist * math.sin(rot))
                g.ellipse([fx - 8, fy - 8, fx + 8, fy + 8], fill=(255, 80 + step*20, 20, 200))
        for _ in range(60):
            fx = cx + random.randint(-160, 160)
            fy = cy + random.randint(-160, 160)
            g.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=(255, 180, 40, 220))
            
    base = apply_glow_layer(base, draw_chakram_fire, blur_radius=18, blend_strength=1.8)
    return draw_ornate_border(base, "crimson")

def render_weapon_frost_polearm():
    """Crystalline ice glaive that leaves a freezing trail."""
    base = create_base_canvas((15, 30, 50, 255), (4, 8, 16, 255))
    draw = ImageDraw.Draw(base)
    
    draw.line([(120, 430), (330, 200)], fill=(30, 60, 90, 255), width=18)
    draw.line([(120, 430), (330, 200)], fill=(140, 210, 255, 255), width=6)
    
    gx, gy = 350, 160
    glaive_pts = [
        (gx - 20, gy + 35), (gx + 60, gy - 60), (gx + 75, gy - 110),
        (gx + 30, gy - 85), (gx - 50, gy - 30), (gx - 100, gy + 20),
        (gx - 45, gy + 45)
    ]
    draw.polygon(glaive_pts, fill=(80, 180, 240, 240), outline=(225, 250, 255, 255), width=3)
    
    for i in range(5):
        kx = gx - 80 + i * 28
        ky = gy + 10 - i * 22
        draw.polygon([(kx, ky), (kx - 15, ky - 20), (kx + 10, ky - 10)], fill=(160, 230, 255, 255), outline=(255, 255, 255, 255))
        
    def draw_frost_trail(g):
        g.polygon(glaive_pts, outline=(160, 240, 255, 240), width=6)
        for _ in range(55):
            ix = gx + random.randint(-140, 90)
            iy = gy + random.randint(-120, 110)
            ir = random.uniform(2.0, 5.0)
            g.polygon([(ix, iy - ir*2), (ix + ir, iy), (ix, iy + ir*2), (ix - ir, iy)], fill=(220, 250, 255, 240))
        for _ in range(8):
            fx = gx + random.randint(-90, 40)
            fy = gy + random.randint(-60, 40)
            g.ellipse([fx - 35, fy - 35, fx + 35, fy + 35], fill=(120, 210, 255, 90))
            
    base = apply_glow_layer(base, draw_frost_trail, blur_radius=18, blend_strength=1.8)
    return draw_ornate_border(base, "frost")

def render_weapon_sun_blade():
    """Pure forged sunlight blade without physical steel."""
    base = create_base_canvas((40, 32, 12, 255), (10, 8, 4, 255))
    draw = ImageDraw.Draw(base)
    
    hx, hy = 200, 350
    draw.line([(hx - 40, hy + 50), (hx, hy)], fill=(215, 160, 40, 255), width=16)
    draw.line([(hx - 40, hy + 50), (hx, hy)], fill=(255, 235, 150, 255), width=6)
    draw.ellipse([hx - 55, hy + 40, hx - 30, hy + 65], fill=(255, 210, 60, 255), outline=(255, 255, 255, 255), width=3)
    
    draw.polygon([(hx - 35, hy - 35), (hx + 35, hy + 35), (hx + 45, hy + 15), (hx - 15, hy - 45)],
                 fill=(230, 180, 50, 255), outline=(255, 240, 140, 255), width=3)
    draw.ellipse([hx - 14, hy - 14, hx + 14, hy + 14], fill=(255, 245, 180, 255), outline=(255, 160, 30, 255), width=3)
    
    draw.line([(hx, hy), (400, 100)], fill=(255, 240, 140, 255), width=22)
    draw.line([(hx, hy), (400, 100)], fill=(255, 255, 240, 255), width=10)
    
    def draw_sun_blade_radiance(g):
        g.line([(hx, hy), (400, 100)], fill=(255, 255, 255, 255), width=16)
        for t in np.linspace(0.1, 0.9, 12):
            bx = int(hx * (1-t) + 400 * t)
            by = int(hy * (1-t) + 100 * t)
            g.ellipse([bx - 30, by - 30, bx + 30, by + 30], fill=(255, 210, 60, 180))
        tx, ty = 400, 100
        for deg in range(0, 360, 30):
            rad = math.radians(deg)
            rx = tx + int(60 * math.cos(rad))
            ry = ty + int(60 * math.sin(rad))
            g.line([(tx, ty), (rx, ry)], fill=(255, 245, 180, 220), width=3)
        for _ in range(50):
            sx = random.randint(160, 440)
            sy = random.randint(70, 380)
            g.ellipse([sx-3, sy-3, sx+3, sy+3], fill=(255, 255, 200, 240))
            
    base = apply_glow_layer(base, draw_sun_blade_radiance, blur_radius=22, blend_strength=1.9)
    return draw_ornate_border(base, "gold")

def render_weapon_void_scythe():
    """Grim reaper scythe carved from a black hole's singularity."""
    base = create_base_canvas((20, 8, 30, 255), (4, 2, 8, 255))
    draw = ImageDraw.Draw(base)
    
    draw.line([(120, 440), (220, 310), (320, 160)], fill=(25, 20, 32, 255), width=18)
    draw.line([(120, 440), (220, 310), (320, 160)], fill=(120, 60, 170, 255), width=6)
    
    sx, sy = 320, 160
    scythe_poly = [
        (sx - 10, sy + 30), (sx + 35, sy - 15), (sx + 20, sy - 55),
        (sx - 70, sy - 85), (sx - 170, sy - 65), (120, 130),
        (sx - 140, sy - 30), (sx - 60, sy - 20), (sx - 10, sy + 15)
    ]
    draw.polygon(scythe_poly, fill=(15, 10, 20, 255), outline=(180, 70, 240, 255), width=3)
    
    draw.ellipse([sx - 28, sy - 28, sx + 28, sy + 28], fill=(0, 0, 0, 255), outline=(210, 100, 255, 255), width=4)
    draw.ellipse([sx - 12, sy - 12, sx + 12, sy + 12], fill=(0, 0, 0, 255), outline=(255, 255, 255, 255), width=2)
    
    def draw_void_singularity(g):
        g.polygon(scythe_poly, outline=(220, 90, 255, 230), width=6)
        g.ellipse([sx - 48, sy - 48, sx + 48, sy + 48], outline=(170, 50, 230, 200), width=8)
        for rad in [65, 95, 130]:
            g.ellipse([sx - rad, sy - rad, sx + rad, sy + rad], outline=(130, 35, 190, 120), width=4)
        for _ in range(50):
            vx = random.randint(100, 360)
            vy = random.randint(70, 240)
            g.ellipse([vx-3, vy-3, vx+3, vy+3], fill=(220, 130, 255, 220))
            
    base = apply_glow_layer(base, draw_void_singularity, blur_radius=18, blend_strength=1.8)
    return draw_ornate_border(base, "obsidian")

WEAPONS_CATALOG = [
    ("weapon_tiamat_greatsword.png", render_weapon_tiamat_greatsword),
    ("weapon_stormwing_dagger.png", render_weapon_stormwing_dagger),
    ("weapon_empyrean_longbow.png", render_weapon_empyrean_longbow),
    ("weapon_abyssal_orb.png", render_weapon_abyssal_orb),
    ("weapon_beritra_spellbook.png", render_weapon_beritra_spellbook),
    ("weapon_archdaeva_staff.png", render_weapon_archdaeva_staff),
    ("weapon_tahabata_spear.png", render_weapon_tahabata_spear),
    ("weapon_divine_mace.png", render_weapon_divine_mace),
    ("weapon_kallida_shield.png", render_weapon_kallida_shield),
    ("weapon_aether_cannon.png", render_weapon_aether_cannon),
    ("weapon_shadow_pistol.png", render_weapon_shadow_pistol),
    ("weapon_kromede_rapier.png", render_weapon_kromede_rapier),
    ("weapon_flame_chakram.png", render_weapon_flame_chakram),
    ("weapon_frost_polearm.png", render_weapon_frost_polearm),
    ("weapon_sun_blade.png", render_weapon_sun_blade),
    ("weapon_void_scythe.png", render_weapon_void_scythe),
]

def main():
    ensure_dir(TARGET_DIR)
    random.seed(42)
    np.random.seed(42)
    
    print(f"Generating {len(WEAPONS_CATALOG)} Aion-2 Legendary Weapon Icons into {TARGET_DIR}...")
    
    generated_files = []
    for filename, renderer in WEAPONS_CATALOG:
        print(f" -> Rendering {filename}...")
        img_512 = renderer()
        img_256 = img_512.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
        out_path = os.path.join(TARGET_DIR, filename)
        img_256.save(out_path, format="PNG", optimize=True)
        generated_files.append(out_path)
        print(f"    Saved: {out_path} ({os.path.getsize(out_path)} bytes)")
        
    print(f"\nSuccessfully generated {len(generated_files)} weapon icons.")

if __name__ == "__main__":
    main()
