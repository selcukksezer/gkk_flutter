"""
Aion-2 Empyrean Lords & Archdaeva Deity Portrait Generator
Worker: worker_art_4_npc_deities_portraits
Target: assets/images/portraits/npcs/
"""

import os
import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageEnhance

SIZE = 768
OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "images", "portraits", "npcs"))

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def create_radial_gradient(size, center, r_max, color_inner, color_outer):
    cx, cy = center
    x = np.arange(size)
    y = np.arange(size)
    xx, yy = np.meshgrid(x, y)
    dist = np.sqrt((xx - cx)**2 + (yy - cy)**2)
    t = np.clip(dist / r_max, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    
    r = (color_inner[0] * (1 - t) + color_outer[0] * t).astype(np.uint8)
    g = (color_inner[1] * (1 - t) + color_outer[1] * t).astype(np.uint8)
    b = (color_inner[2] * (1 - t) + color_outer[2] * t).astype(np.uint8)
    a = (color_inner[3] * (1 - t) + color_outer[3] * t).astype(np.uint8)
    return Image.fromarray(np.stack([r, g, b, a], axis=-1), 'RGBA')

def create_nebula_field(size, base_color, highlight_color, seed=42):
    np.random.seed(seed)
    x = np.linspace(0, 4 * math.pi, size)
    y = np.linspace(0, 4 * math.pi, size)
    xx, yy = np.meshgrid(x, y)
    
    noise = (
        np.sin(xx * 0.8 + np.cos(yy * 0.5)) +
        np.cos(yy * 0.7 - np.sin(xx * 0.6)) +
        0.5 * np.sin(xx * 1.5 + yy * 1.2) +
        0.25 * np.cos(xx * 3.0 - yy * 2.5)
    )
    noise = (noise - noise.min()) / (noise.max() - noise.min())
    cx, cy = size / 2, size / 2
    dist_map = np.sqrt((np.arange(size)[:, None] - cy)**2 + (np.arange(size)[None, :] - cx)**2) / (size * 0.6)
    falloff = np.clip(1.0 - dist_map * 0.7, 0.0, 1.0)
    noise = noise * falloff
    
    r = np.clip(base_color[0] + noise * (highlight_color[0] - base_color[0]), 0, 255).astype(np.uint8)
    g = np.clip(base_color[1] + noise * (highlight_color[1] - base_color[1]), 0, 255).astype(np.uint8)
    b = np.clip(base_color[2] + noise * (highlight_color[2] - base_color[2]), 0, 255).astype(np.uint8)
    alpha = np.clip(noise * 180, 0, 255).astype(np.uint8)
    img = Image.fromarray(np.stack([r, g, b, alpha], axis=-1), 'RGBA')
    return img.filter(ImageFilter.GaussianBlur(radius=8))

def draw_god_rays(canvas, center, num_rays, length, color, max_width=40, seed=100):
    cx, cy = center
    ray_img = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(ray_img)
    rng = random.Random(seed)
    
    for i in range(num_rays):
        angle = (2 * math.pi / num_rays) * i + rng.uniform(-0.1, 0.1)
        r_len = length * rng.uniform(0.7, 1.2)
        w = max_width * rng.uniform(0.5, 1.5)
        p1 = (cx, cy)
        p2 = (cx + r_len * math.cos(angle - 0.04 * w / 10), cy + r_len * math.sin(angle - 0.04 * w / 10))
        p3 = (cx + r_len * math.cos(angle + 0.04 * w / 10), cy + r_len * math.sin(angle + 0.04 * w / 10))
        alpha = int(color[3] * rng.uniform(0.4, 0.9))
        draw.polygon([p1, p2, p3], fill=(color[0], color[1], color[2], alpha))
    
    blurred = ray_img.filter(ImageFilter.GaussianBlur(radius=14))
    return Image.alpha_composite(canvas, blurred)

def draw_halo_mandala(canvas, center, radius, color_core, color_glow, style='solar'):
    halo_img = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(halo_img)
    cx, cy = center
    
    for r in [radius - 20, radius, radius + 25, radius + 35]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color_core, width=2)
    
    orbital_r = radius + 12
    num_dots = 48
    for i in range(num_dots):
        ang = (2 * math.pi / num_dots) * i
        dx = cx + orbital_r * math.cos(ang)
        dy = cy + orbital_r * math.sin(ang)
        dot_size = 3 if i % 4 == 0 else 1.5
        draw.ellipse([dx - dot_size, dy - dot_size, dx + dot_size, dy + dot_size], fill=color_core)
        
    if style in ['solar', 'justice', 'destruction']:
        spokes = 16 if style == 'solar' else 12
        for i in range(spokes):
            ang = (2 * math.pi / spokes) * i
            long_ray = (i % 2 == 0)
            ray_len = (radius + 80) if long_ray else (radius + 45)
            p_base_left = (cx + (radius - 5) * math.cos(ang - 0.04), cy + (radius - 5) * math.sin(ang - 0.04))
            p_tip = (cx + ray_len * math.cos(ang), cy + ray_len * math.sin(ang))
            p_base_right = (cx + (radius - 5) * math.cos(ang + 0.04), cy + (radius - 5) * math.sin(ang + 0.04))
            draw.polygon([p_base_left, p_tip, p_base_right], fill=color_core)
            if long_ray:
                tip_cx = cx + (ray_len + 8) * math.cos(ang)
                tip_cy = cy + (ray_len + 8) * math.sin(ang)
                draw.polygon([(tip_cx, tip_cy - 7), (tip_cx + 5, tip_cy), (tip_cx, tip_cy + 7), (tip_cx - 5, tip_cy)], fill=color_core)
    elif style in ['illusion', 'fate', 'shadow']:
        nodes = 8
        for i in range(nodes):
            ang = (2 * math.pi / nodes) * i
            nx = cx + radius * math.cos(ang)
            ny = cy + radius * math.sin(ang)
            draw.ellipse([nx - 9, ny - 9, nx + 9, ny + 9], outline=color_core, width=2)
            draw.ellipse([nx - 4, ny - 4, nx + 4, ny + 4], fill=color_glow)
            chord_r = 50
            draw.arc([nx - chord_r, ny - chord_r, nx + chord_r, ny + chord_r], 
                     start=math.degrees(ang)-45, end=math.degrees(ang)+45, fill=color_core, width=2)

    glow = halo_img.filter(ImageFilter.GaussianBlur(radius=10))
    glow2 = halo_img.filter(ImageFilter.GaussianBlur(radius=4))
    comp = Image.alpha_composite(canvas, glow)
    comp = Image.alpha_composite(comp, glow2)
    return Image.alpha_composite(comp, halo_img)

def draw_feather(draw, root, tip, width, color_base, color_highlight, color_edge):
    rx, ry = root
    tx, ty = tip
    dx = tx - rx
    dy = ty - ry
    length = math.hypot(dx, dy)
    if length < 1:
        return
    ux = dx / length
    uy = dy / length
    nx = -uy
    ny = ux
    mid_t = 0.45
    mx = rx + dx * mid_t
    my = ry + dy * mid_t
    p1 = (rx, ry)
    p2 = (mx + nx * width * 0.9, my + ny * width * 0.9)
    p3 = (tx, ty)
    p4 = (mx - nx * width * 0.7, my - ny * width * 0.7)
    draw.polygon([p1, p2, p3, p4], fill=color_base, outline=color_edge)
    draw.line([(rx, ry), (tx - ux * 5, ty - uy * 5)], fill=color_highlight, width=max(1, int(width * 0.15)))

def draw_divine_wings(canvas, center_anchor, wing_span, wing_height, color_base, color_highlight, color_rim):
    wing_layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(wing_layer)
    cx, cy = center_anchor
    
    for side in [-1, 1]:
        shoulder_x = cx + side * 90
        shoulder_y = cy + 40
        elbow_x = cx + side * (wing_span * 0.55)
        elbow_y = cy - (wing_height * 0.45)
        
        num_primaries = 14
        for i in range(num_primaries):
            t = i / float(num_primaries)
            root_x = elbow_x * (1 - t*0.8) + shoulder_x * (t*0.8)
            root_y = elbow_y * (1 - t*0.8) + (shoulder_y - 20) * (t*0.8) + i * 8
            spread_ang = (0.2 + t * 0.8) * math.pi * 0.5
            f_len = 160 + (1.0 - abs(t - 0.3)) * 120
            tip_x = root_x + side * f_len * math.cos(spread_ang)
            tip_y = root_y - f_len * math.sin(spread_ang) + (t * 60)
            f_width = 18 + i * 1.2
            draw_feather(draw, (root_x, root_y), (tip_x, tip_y), f_width, color_base, color_highlight, color_rim)

        num_secondaries = 10
        for i in range(num_secondaries):
            t = i / float(num_secondaries)
            root_x = shoulder_x + side * (t * 70)
            root_y = shoulder_y - 20 + (t * 40)
            spread_ang = (0.4 + t * 0.6) * math.pi * 0.4
            f_len = 110 + (1.0 - t) * 70
            tip_x = root_x + side * f_len * math.cos(spread_ang)
            tip_y = root_y - f_len * math.sin(spread_ang) + 40
            draw_feather(draw, (root_x, root_y), (tip_x, tip_y), 16, color_base, color_highlight, color_rim)

        for i in range(16):
            ang = (i / 16.0) * math.pi * 0.8
            root_x = shoulder_x + side * (math.cos(ang) * 45)
            root_y = shoulder_y - 30 + (math.sin(ang) * 40)
            tip_x = root_x + side * 40
            tip_y = root_y - 25
            draw_feather(draw, (root_x, root_y), (tip_x, tip_y), 12, color_highlight, color_rim, color_base)

    glow = wing_layer.filter(ImageFilter.GaussianBlur(radius=6))
    comp = Image.alpha_composite(canvas, glow)
    return Image.alpha_composite(comp, wing_layer)

def draw_deity_bust(canvas, center_anchor, skin_tone, hair_color, armor_colors, style='seraph'):
    bust_img = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(bust_img)
    cx, cy = center_anchor
    
    hair_base, hair_hi, hair_shadow = hair_color
    for i in range(-12, 13):
        curve_off = i * 8
        pts = [
            (cx + curve_off * 0.5, cy - 80),
            (cx + curve_off * 1.8, cy + 40),
            (cx + curve_off * 2.8 + math.sin(i) * 35, cy + 220),
            (cx + curve_off * 3.2, cy + 340)
        ]
        strand_w = 16 - abs(i)
        if strand_w > 2:
            draw.line(pts, fill=hair_shadow, width=strand_w + 4)
            draw.line(pts, fill=hair_base, width=strand_w)
            draw.line([(pts[0][0], pts[0][1]), (pts[1][0], pts[1][1])], fill=hair_hi, width=max(1, strand_w - 4))

    plate_dark, plate_mid, plate_light, plate_gold = armor_colors
    draw.polygon([(cx - 30, cy + 130), (cx - 180, cy + 180), (cx - 280, cy + 320), (cx - 260, cy + 380), (cx - 90, cy + 380), (cx, cy + 260)], fill=plate_dark, outline=plate_mid)
    draw.polygon([(cx + 30, cy + 130), (cx + 180, cy + 180), (cx + 280, cy + 320), (cx + 260, cy + 380), (cx + 90, cy + 380), (cx, cy + 260)], fill=plate_dark, outline=plate_mid)
    draw.polygon([(cx - 90, cy + 150), (cx + 90, cy + 150), (cx + 120, cy + 380), (cx - 120, cy + 380)], fill=plate_mid, outline=plate_gold)
    
    neck_w = 46 if style in ['seraph', 'illusion'] else 58
    skin_base, skin_hi, skin_shadow = skin_tone
    draw.polygon([(cx - neck_w, cy - 20), (cx + neck_w, cy - 20), (cx + neck_w + 12, cy + 120), (cx - neck_w - 12, cy + 120)], fill=skin_shadow)
    draw.polygon([(cx - neck_w * 0.4, cy - 10), (cx + neck_w * 0.4, cy - 10), (cx + neck_w * 0.5, cy + 100), (cx - neck_w * 0.5, cy + 100)], fill=skin_base)
    
    gorget = [(cx - neck_w - 16, cy + 100), (cx + neck_w + 16, cy + 100), (cx + neck_w + 35, cy + 160), (cx, cy + 195), (cx - neck_w - 35, cy + 160)]
    draw.polygon(gorget, fill=plate_dark, outline=plate_gold)
    draw.line([(cx - neck_w - 10, cy + 115), (cx, cy + 185), (cx + neck_w + 10, cy + 115)], fill=plate_light, width=2)
    
    head_cy = cy - 60
    head_w = 78 if style in ['seraph', 'illusion'] else 92
    head_h = 105
    jaw_pts = [(cx - head_w, head_cy - 40), (cx + head_w, head_cy - 40), (cx + head_w * 0.85, head_cy + 40), (cx + head_w * 0.42, head_cy + head_h * 0.85), (cx, head_cy + head_h), (cx - head_w * 0.42, head_cy + head_h * 0.85), (cx - head_w * 0.85, head_cy + 40)]
    draw.polygon(jaw_pts, fill=skin_base, outline=skin_shadow)
    
    draw.ellipse([cx - head_w * 0.75, head_cy + 5, cx - head_w * 0.15, head_cy + 45], fill=skin_hi)
    draw.ellipse([cx + head_w * 0.15, head_cy + 5, cx + head_w * 0.75, head_cy + 45], fill=skin_hi)
    draw.ellipse([cx - 15, head_cy + head_h - 22, cx + 15, head_cy + head_h - 4], fill=skin_hi)
    
    nose_y = head_cy + 30
    draw.line([(cx, head_cy - 5), (cx - 3, nose_y), (cx, nose_y + 6), (cx + 3, nose_y)], fill=skin_shadow, width=2)
    draw.line([(cx - 1, head_cy), (cx - 1, nose_y)], fill=skin_hi, width=2)
    
    lip_y = head_cy + 56
    lip_w = 22
    draw.polygon([(cx - lip_w, lip_y), (cx - 6, lip_y - 4), (cx, lip_y - 2), (cx + 6, lip_y - 4), (cx + lip_w, lip_y), (cx, lip_y + 3)], fill=skin_shadow)
    draw.polygon([(cx - lip_w * 0.75, lip_y + 2), (cx + lip_w * 0.75, lip_y + 2), (cx, lip_y + 10)], fill=skin_hi)
    
    eye_y = head_cy + 10
    eye_spacing = 38
    for eye_side in [-1, 1]:
        ex = cx + eye_side * eye_spacing
        brow_y = eye_y - 18
        draw.line([(ex - 22 * eye_side, brow_y + 5), (ex, brow_y), (ex + 20 * eye_side, brow_y - 2)], fill=hair_shadow, width=3)
        eye_pts = [(ex - 18, eye_y), (ex, eye_y - 8), (ex + 18, eye_y), (ex, eye_y + 6)]
        draw.polygon(eye_pts, fill=(240, 245, 255, 255), outline=skin_shadow)
        
        if style == 'seraph':
            iris_color = (255, 215, 0, 255)
            pupil_glow = (255, 255, 220, 255)
        elif style == 'shadow':
            iris_color = (0, 220, 255, 255)
            pupil_glow = (200, 255, 255, 255)
        elif style == 'justice':
            iris_color = (255, 225, 80, 255)
            pupil_glow = (255, 255, 255, 255)
        elif style == 'destruction':
            iris_color = (255, 60, 0, 255)
            pupil_glow = (255, 200, 50, 255)
        elif style == 'illusion':
            iris_color = (180, 100, 255, 255)
            pupil_glow = (255, 180, 255, 255)
        else:
            iris_color = (220, 20, 60, 255)
            pupil_glow = (255, 120, 120, 255)
            
        draw.ellipse([ex - 7, eye_y - 6, ex + 7, eye_y + 6], fill=iris_color)
        draw.ellipse([ex - 3, eye_y - 3, ex + 3, eye_y + 3], fill=pupil_glow)
        draw.ellipse([ex + 2, eye_y - 4, ex + 5, eye_y - 1], fill=(255, 255, 255, 255))

    for i in range(-8, 9):
        sx = cx + i * 11
        sy = head_cy - 75
        ex = cx + i * 14 + (20 if i > 0 else -20)
        ey = head_cy - 10 + abs(i) * 4
        ctrl_x = sx + (i * 5)
        ctrl_y = sy + 35
        draw.line([(sx, sy), (ctrl_x, ctrl_y), (ex, ey)], fill=hair_base, width=8)
        draw.line([(sx, sy), (ctrl_x, ctrl_y), (ex, ey)], fill=hair_hi, width=3)

    return bust_img

def apply_post_fx(img):
    w, h = img.size
    frame = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    f_draw = ImageDraw.Draw(frame)
    border_col = (212, 175, 55, 180)
    margin = 20
    f_draw.rectangle([margin, margin, w - margin, h - margin], outline=border_col, width=2)
    f_draw.rectangle([margin + 6, margin + 6, w - margin - 6, h - margin - 6], outline=border_col, width=1)
    
    corner_len = 50
    for cx_b, cy_b, sx, sy in [(margin + 6, margin + 6, 1, 1), (w - margin - 6, margin + 6, -1, 1), (margin + 6, h - margin - 6, 1, -1), (w - margin - 6, h - margin - 6, -1, -1)]:
        f_draw.line([(cx_b, cy_b), (cx_b + sx * corner_len, cy_b)], fill=border_col, width=3)
        f_draw.line([(cx_b, cy_b), (cx_b, cy_b + sy * corner_len)], fill=border_col, width=3)
        f_draw.polygon([(cx_b + sx * 15, cy_b), (cx_b, cy_b + sy * 15), (cx_b - sx * 5, cy_b + sy * 5)], fill=border_col)
        
    comp = Image.alpha_composite(img, frame)
    enhancer = ImageEnhance.Sharpness(comp)
    comp = enhancer.enhance(1.25)
    color_enhancer = ImageEnhance.Color(comp)
    return color_enhancer.enhance(1.15)

def generate_lord_ariel():
    bg = Image.new('RGBA', (SIZE, SIZE), (25, 20, 35, 255))
    grad = create_radial_gradient(SIZE, (SIZE // 2, 280), 480, (255, 240, 200, 255), (45, 30, 60, 255))
    bg = Image.alpha_composite(bg, grad)
    nebula = create_nebula_field(SIZE, (255, 215, 0), (255, 255, 240), seed=101)
    bg = Image.alpha_composite(bg, nebula)
    bg = draw_god_rays(bg, (SIZE // 2, 260), 28, 520, (255, 230, 140, 140), max_width=45)
    bg = draw_halo_mandala(bg, (SIZE // 2, 260), 160, (255, 220, 100, 255), (255, 255, 200, 180), style='solar')
    bg = draw_divine_wings(bg, (SIZE // 2, 360), 330, 260, (245, 245, 252, 255), (255, 255, 255, 255), (255, 215, 80, 220))
    
    skin_tone = ((255, 238, 225, 255), (255, 250, 245, 255), (230, 195, 175, 255))
    hair_color = ((255, 228, 140, 255), (255, 255, 210, 255), (200, 160, 70, 255))
    armor_colors = ((220, 225, 235, 255), (240, 245, 255, 255), (255, 255, 255, 255), (255, 215, 0, 255))
    bust = draw_deity_bust(bg, (SIZE // 2, 340), skin_tone, hair_color, armor_colors, style='seraph')
    bg = Image.alpha_composite(bg, bust)
    
    tiara_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(tiara_img)
    tcx, tcy = SIZE // 2, 215
    for i in range(-3, 4):
        ang_x = tcx + i * 22
        spike_h = 45 - abs(i) * 8
        t_draw.polygon([(ang_x - 8, tcy), (ang_x, tcy - spike_h), (ang_x + 8, tcy)], fill=(255, 215, 0, 255), outline=(255, 255, 220, 255))
        if i == 0:
            t_draw.ellipse([ang_x - 6, tcy - spike_h - 12, ang_x + 6, tcy - spike_h], fill=(220, 245, 255, 255), outline=(255, 255, 255, 255))
    t_draw.line([(tcx - 70, tcy), (tcx + 70, tcy)], fill=(255, 215, 0, 255), width=5)
    bg = Image.alpha_composite(bg, tiara_img)
    
    rng = random.Random(777)
    mote_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    m_draw = ImageDraw.Draw(mote_layer)
    for _ in range(80):
        mx = rng.randint(40, SIZE - 40)
        my = rng.randint(60, SIZE - 60)
        ms = rng.uniform(2, 6)
        m_draw.ellipse([mx - ms, my - ms, mx + ms, my + ms], fill=(255, 240, 180, rng.randint(120, 220)))
    bg = Image.alpha_composite(bg, mote_layer.filter(ImageFilter.GaussianBlur(radius=2)))
    return apply_post_fx(bg)

def generate_lord_azphel():
    bg = Image.new('RGBA', (SIZE, SIZE), (10, 8, 20, 255))
    grad = create_radial_gradient(SIZE, (SIZE // 2, 280), 450, (50, 20, 80, 255), (8, 6, 16, 255))
    bg = Image.alpha_composite(bg, grad)
    nebula = create_nebula_field(SIZE, (40, 10, 60), (0, 180, 220), seed=202)
    bg = Image.alpha_composite(bg, nebula)
    
    rng = random.Random(888)
    star_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(star_img)
    for _ in range(120):
        sx = rng.randint(20, SIZE - 20)
        sy = rng.randint(20, SIZE - 20)
        col = (200, 240, 255, rng.randint(100, 240)) if rng.random() > 0.3 else (255, 180, 240, rng.randint(100, 200))
        s_draw.ellipse([sx - 1.5, sy - 1.5, sx + 1.5, sy + 1.5], fill=col)
    bg = Image.alpha_composite(bg, star_img)
    
    bg = draw_halo_mandala(bg, (SIZE // 2, 260), 155, (120, 40, 180, 255), (0, 220, 255, 180), style='shadow')
    bg = draw_divine_wings(bg, (SIZE // 2, 360), 340, 270, (18, 16, 28, 255), (45, 40, 65, 255), (0, 200, 255, 190))
    
    skin_tone = ((220, 215, 225, 255), (240, 240, 250, 255), (140, 130, 155, 255))
    hair_color = ((20, 18, 28, 255), (55, 50, 80, 255), (10, 8, 16, 255))
    armor_colors = ((16, 14, 24, 255), (35, 30, 50, 255), (70, 65, 100, 255), (130, 60, 200, 255))
    bust = draw_deity_bust(bg, (SIZE // 2, 340), skin_tone, hair_color, armor_colors, style='shadow')
    bg = Image.alpha_composite(bg, bust)
    
    crown_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(crown_img)
    ccx, ccy = SIZE // 2, 205
    for dx, h in [(-45, 35), (-25, 55), (0, 70), (25, 55), (45, 35)]:
        c_draw.polygon([(ccx + dx - 8, ccy + 10), (ccx + dx, ccy + 10 - h), (ccx + dx + 8, ccy + 10)], fill=(25, 20, 35, 255), outline=(0, 200, 255, 220))
    c_draw.polygon([(ccx, ccy - 5), (ccx + 10, ccy + 10), (ccx, ccy + 25), (ccx - 10, ccy + 10)], fill=(160, 40, 240, 255), outline=(0, 255, 255, 255))
    bg = Image.alpha_composite(bg, crown_img)
    
    wisp_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wisp_img)
    for eye_side in [-1, 1]:
        ex = SIZE // 2 + eye_side * 38
        ey = 290
        w_draw.line([(ex, ey), (ex + eye_side * 35, ey - 15), (ex + eye_side * 60, ey - 40)], fill=(0, 220, 255, 160), width=3)
    bg = Image.alpha_composite(bg, wisp_img.filter(ImageFilter.GaussianBlur(radius=4)))
    return apply_post_fx(bg)

def generate_lord_nezekan():
    bg = Image.new('RGBA', (SIZE, SIZE), (15, 25, 45, 255))
    grad = create_radial_gradient(SIZE, (SIZE // 2, 270), 460, (70, 110, 170, 255), (12, 18, 32, 255))
    bg = Image.alpha_composite(bg, grad)
    bg = draw_god_rays(bg, (SIZE // 2, 250), 20, 500, (255, 235, 160, 120), max_width=50)
    bg = draw_halo_mandala(bg, (SIZE // 2, 250), 165, (240, 200, 70, 255), (255, 240, 180, 180), style='justice')
    bg = draw_divine_wings(bg, (SIZE // 2, 360), 330, 250, (160, 175, 195, 255), (235, 240, 250, 255), (255, 215, 0, 220))
    
    skin_tone = ((245, 220, 195, 255), (255, 240, 225, 255), (190, 155, 130, 255))
    hair_color = ((120, 90, 55, 255), (170, 135, 90, 255), (75, 50, 30, 255))
    armor_colors = ((60, 75, 95, 255), (130, 145, 170, 255), (220, 230, 245, 255), (235, 190, 45, 255))
    bust = draw_deity_bust(bg, (SIZE // 2, 340), skin_tone, hair_color, armor_colors, style='justice')
    bg = Image.alpha_composite(bg, bust)
    
    helm_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(helm_img)
    hcx, hcy = SIZE // 2, 210
    h_draw.polygon([(hcx - 72, hcy + 15), (hcx + 72, hcy + 15), (hcx + 80, hcy - 20), (hcx, hcy - 35), (hcx - 80, hcy - 20)], fill=(110, 125, 150, 255), outline=(235, 190, 45, 255))
    h_draw.polygon([(hcx, hcy - 32), (hcx + 18, hcy - 12), (hcx + 12, hcy + 5), (hcx, hcy + 12), (hcx - 12, hcy + 5), (hcx - 18, hcy - 12)], fill=(240, 200, 50, 255), outline=(255, 245, 180, 255))
    
    for side in [-1, 1]:
        for i in range(5):
            f_len = 50 + i * 8
            ang = math.pi * 0.5 - side * (0.2 + i * 0.12)
            px = hcx + side * (15 + i * 8)
            py = hcy - 30
            tx = px + side * f_len * math.cos(ang)
            ty = py - f_len * math.sin(ang)
            h_draw.line([(px, py), (tx, ty)], fill=(255, 215, 0, 255), width=5)
    bg = Image.alpha_composite(bg, helm_img)
    return apply_post_fx(bg)

def generate_lord_zikel():
    bg = Image.new('RGBA', (SIZE, SIZE), (25, 8, 8, 255))
    grad = create_radial_gradient(SIZE, (SIZE // 2, 270), 460, (160, 40, 10, 255), (18, 5, 5, 255))
    bg = Image.alpha_composite(bg, grad)
    nebula = create_nebula_field(SIZE, (100, 20, 5), (255, 90, 0), seed=404)
    bg = Image.alpha_composite(bg, nebula)
    bg = draw_halo_mandala(bg, (SIZE // 2, 250), 165, (255, 80, 0, 255), (255, 180, 20, 180), style='destruction')
    bg = draw_divine_wings(bg, (SIZE // 2, 360), 340, 260, (35, 20, 20, 255), (140, 40, 10, 255), (255, 120, 0, 220))
    
    skin_tone = ((225, 180, 160, 255), (245, 200, 180, 255), (150, 95, 80, 255))
    hair_color = ((160, 30, 15, 255), (240, 80, 20, 255), (90, 15, 5, 255))
    armor_colors = ((25, 18, 18, 255), (55, 40, 40, 255), (95, 75, 75, 255), (230, 70, 10, 255))
    bust = draw_deity_bust(bg, (SIZE // 2, 340), skin_tone, hair_color, armor_colors, style='destruction')
    bg = Image.alpha_composite(bg, bust)
    
    sword_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(sword_img)
    sword_pts = [(SIZE // 2 + 130, 440), (SIZE // 2 + 175, 455), (SIZE // 2 + 270, 120), (SIZE // 2 + 250, 90), (SIZE // 2 + 215, 140)]
    s_draw.polygon(sword_pts, fill=(40, 35, 40, 255), outline=(255, 100, 20, 255))
    s_draw.line([(SIZE // 2 + 155, 440), (SIZE // 2 + 242, 115)], fill=(255, 180, 40, 255), width=4)
    s_draw.polygon([(SIZE // 2 + 115, 430), (SIZE // 2 + 195, 460), (SIZE // 2 + 175, 490), (SIZE // 2 + 95, 460)], fill=(80, 20, 10, 255), outline=(255, 120, 0, 255))
    
    rng = random.Random(999)
    for _ in range(90):
        ex = rng.randint(40, SIZE - 40)
        ey = rng.randint(60, SIZE - 60)
        es = rng.uniform(2, 5.5)
        ecol = (255, rng.randint(80, 220), 20, rng.randint(140, 240))
        s_draw.ellipse([ex - es, ey - es, ex + es, ey + es], fill=ecol)
    bg = Image.alpha_composite(bg, sword_img)
    return apply_post_fx(bg)

def generate_lord_kaisinel():
    bg = Image.new('RGBA', (SIZE, SIZE), (16, 12, 32, 255))
    grad = create_radial_gradient(SIZE, (SIZE // 2, 275), 450, (75, 45, 110, 255), (12, 8, 24, 255))
    bg = Image.alpha_composite(bg, grad)
    nebula = create_nebula_field(SIZE, (80, 30, 120), (30, 220, 180), seed=505)
    bg = Image.alpha_composite(bg, nebula)
    bg = draw_halo_mandala(bg, (SIZE // 2, 255), 165, (190, 120, 255, 255), (0, 250, 210, 180), style='illusion')
    bg = draw_divine_wings(bg, (SIZE // 2, 360), 335, 260, (50, 35, 75, 255), (140, 95, 210, 255), (0, 240, 220, 200))
    
    skin_tone = ((235, 225, 245, 255), (250, 245, 255, 255), (165, 150, 185, 255))
    hair_color = ((150, 140, 190, 255), (220, 210, 255, 255), (85, 75, 120, 255))
    armor_colors = ((35, 25, 55, 255), (65, 50, 95, 255), (130, 110, 180, 255), (0, 230, 210, 255))
    bust = draw_deity_bust(bg, (SIZE // 2, 340), skin_tone, hair_color, armor_colors, style='illusion')
    bg = Image.alpha_composite(bg, bust)
    
    mirror_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    m_draw = ImageDraw.Draw(mirror_img)
    mcx, mcy = SIZE // 2, 300
    for ang_mult in [0.15, 0.5, 0.85, 1.15, 1.5, 1.85]:
        ang = math.pi * ang_mult
        dist = 220
        mx = mcx + dist * math.cos(ang)
        my = mcy + dist * math.sin(ang) * 0.75
        mw, mh = 24, 38
        pts = [(mx, my - mh), (mx + mw, my), (mx, my + mh), (mx - mw, my)]
        m_draw.polygon(pts, fill=(180, 240, 255, 160), outline=(255, 255, 255, 240))
        m_draw.line([(mx - mw * 0.5, my + mh * 0.3), (mx + mw * 0.5, my - mh * 0.3)], fill=(255, 150, 255, 200), width=2)
        m_draw.polygon(pts, outline=(0, 255, 220, 220), width=2)
    bg = Image.alpha_composite(bg, mirror_img)
    return apply_post_fx(bg)

def generate_lord_marchutan():
    bg = Image.new('RGBA', (SIZE, SIZE), (12, 10, 16, 255))
    grad = create_radial_gradient(SIZE, (SIZE // 2, 275), 450, (50, 25, 35, 255), (10, 8, 14, 255))
    bg = Image.alpha_composite(bg, grad)
    nebula = create_nebula_field(SIZE, (35, 15, 25), (180, 20, 40), seed=606)
    bg = Image.alpha_composite(bg, nebula)
    bg = draw_halo_mandala(bg, (SIZE // 2, 255), 165, (180, 30, 45, 255), (240, 60, 80, 180), style='fate')
    bg = draw_divine_wings(bg, (SIZE // 2, 360), 335, 265, (20, 18, 24, 255), (50, 35, 45, 255), (180, 30, 50, 200))
    
    skin_tone = ((210, 200, 205, 255), (230, 225, 230, 255), (130, 115, 125, 255))
    hair_color = ((40, 38, 45, 255), (75, 70, 85, 255), (20, 18, 25, 255))
    armor_colors = ((18, 16, 22, 255), (40, 35, 45, 255), (80, 70, 85, 255), (160, 40, 50, 255))
    bust = draw_deity_bust(bg, (SIZE // 2, 340), skin_tone, hair_color, armor_colors, style='fate')
    bg = Image.alpha_composite(bg, bust)
    
    cowl_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(cowl_img)
    ccx, ccy = SIZE // 2, 215
    cowl_pts = [(ccx, ccy - 35), (ccx + 85, ccy + 15), (ccx + 75, ccy + 85), (ccx + 55, ccy + 65), (ccx, ccy + 45), (ccx - 55, ccy + 65), (ccx - 75, ccy + 85), (ccx - 85, ccy + 15)]
    c_draw.polygon(cowl_pts, fill=(18, 16, 24, 255), outline=(140, 30, 45, 255))
    c_draw.polygon([(ccx - 65, ccy + 30), (ccx + 65, ccy + 30), (ccx + 45, ccy + 75), (ccx - 45, ccy + 75)], fill=(5, 4, 8, 240))
    for eye_side in [-1, 1]:
        ex = ccx + eye_side * 36
        ey = ccy + 52
        c_draw.ellipse([ex - 5, ey - 3, ex + 5, ey + 3], fill=(220, 20, 50, 255))
        c_draw.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=(255, 140, 140, 255))
        c_draw.line([(ex, ey), (ex + eye_side * 22, ey - 8)], fill=(220, 20, 50, 160), width=2)
    bg = Image.alpha_composite(bg, cowl_img)
    
    hg_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(hg_img)
    hgcx, hgcy = SIZE // 2, 490
    h_draw.rectangle([hgcx - 35, hgcy - 50, hgcx + 35, hgcy - 40], fill=(130, 85, 40, 255), outline=(220, 160, 60, 255))
    h_draw.rectangle([hgcx - 35, hgcy + 40, hgcx + 35, hgcy + 50], fill=(130, 85, 40, 255), outline=(220, 160, 60, 255))
    h_draw.line([(hgcx - 30, hgcy - 40), (hgcx - 30, hgcy + 40)], fill=(200, 140, 50, 255), width=3)
    h_draw.line([(hgcx + 30, hgcy - 40), (hgcx + 30, hgcy + 40)], fill=(200, 140, 50, 255), width=3)
    h_draw.polygon([(hgcx - 26, hgcy - 40), (hgcx + 26, hgcy - 40), (hgcx + 5, hgcy - 3), (hgcx - 5, hgcy - 3)], fill=(180, 20, 40, 120), outline=(255, 100, 120, 200))
    h_draw.polygon([(hgcx - 5, hgcy + 3), (hgcx + 5, hgcy + 3), (hgcx + 26, hgcy + 40), (hgcx - 26, hgcy + 40)], fill=(180, 20, 40, 120), outline=(255, 100, 120, 200))
    h_draw.line([(hgcx, hgcy - 10), (hgcx, hgcy + 25)], fill=(255, 100, 120, 255), width=2)
    h_draw.polygon([(hgcx - 22, hgcy + 40), (hgcx + 22, hgcy + 40), (hgcx, hgcy + 25)], fill=(240, 40, 60, 220))
    
    hg_blur = hg_img.filter(ImageFilter.GaussianBlur(radius=6))
    bg = Image.alpha_composite(bg, hg_blur)
    bg = Image.alpha_composite(bg, hg_img)
    return apply_post_fx(bg)

def main():
    ensure_dir(OUTPUT_DIR)
    print(f"Target Directory: {OUTPUT_DIR}")
    
    deities = [
        ("lord_ariel.png", generate_lord_ariel),
        ("lord_azphel.png", generate_lord_azphel),
        ("lord_nezekan.png", generate_lord_nezekan),
        ("lord_zikel.png", generate_lord_zikel),
        ("lord_kaisinel.png", generate_lord_kaisinel),
        ("lord_marchutan.png", generate_lord_marchutan),
    ]
    
    for filename, gen_func in deities:
        out_path = os.path.join(OUTPUT_DIR, filename)
        img = gen_func()
        img.save(out_path, format="PNG", optimize=True)
        size_kb = os.path.getsize(out_path) / 1024
        print(f"Saved: {filename} [{img.size[0]}x{img.size[1]}] ({size_kb:.1f} KB)")
        
    print("\nAll 6 Aion-2 Empyrean Lord portraits synthesized successfully.")

if __name__ == "__main__":
    main()
