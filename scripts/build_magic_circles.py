import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
SIZE = 2048
CX, CY = 1024, 1024
def polar(cx, cy, r, a): return (cx + r * math.cos(a), cy + r * math.sin(a))
def draw_circle_ring(d, cx, cy, r, outline, width=3): d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=outline, width=width)
def draw_dashed_ring(d, cx, cy, r, count=48, ratio=0.5, outline=(255,255,255,255), width=3):
    step = 2 * math.pi / count
    for i in range(count):
        d.arc([cx-r, cy-r, cx+r, cy+r], start=math.degrees(i*step), end=math.degrees(i*step + step*ratio), fill=outline, width=width)
def draw_radial_ticks(d, cx, cy, r_in, r_out, count=48, rot=0, outline=(255,255,255,255), width=2):
    step = 2 * math.pi / count
    for i in range(count): d.line([polar(cx, cy, r_in, rot+i*step), polar(cx, cy, r_out, rot+i*step)], fill=outline, width=width)
def draw_star_polygon(d, cx, cy, r, n=5, step=2, rot=0, outline=(255,255,255,255), width=3):
    pts = [polar(cx, cy, r, rot + i * (2*math.pi/n)) for i in range(n)]
    vis = set()
    for s_idx in range(n):
        if s_idx in vis: continue
        cur, path = s_idx, []
        while cur not in vis:
            vis.add(cur); path.append(pts[cur]); cur = (cur + step) % n
        path.append(pts[s_idx]); d.line(path, fill=outline, width=width)
def draw_star_burst(d, cx, cy, r_out, r_in, n=12, rot=0, outline=(255,255,255,255), fill=None, width=3):
    pts = [polar(cx, cy, r_out if (i%2==0) else r_in, rot + i*(math.pi/n)) for i in range(n*2)]
    pts.append(pts[0])
    if fill: d.polygon(pts, fill=fill, outline=outline)
    else: d.line(pts, fill=outline, width=width)
def draw_regular_polygon(d, cx, cy, r, n=6, rot=0, outline=(255,255,255,255), width=3):
    pts = [polar(cx, cy, r, rot + i*(2*math.pi/n)) for i in range(n)]
    pts.append(pts[0]); d.line(pts, fill=outline, width=width)
def draw_arcane_rune(d, cx, cy, size, seed, rot=0, outline=(255,255,255,255), width=3):
    s = size * 0.5
    cr, sr = math.cos(rot), math.sin(rot)
    def pt(x, y): return (cx + x*cr - y*sr, cy + x*sr + y*cr)
    v = seed % 16
    d.line([pt(0, -s), pt(0, s)], fill=outline, width=width)
    if v == 0:
        d.line([pt(-s*0.8, -s), pt(0, 0)], fill=outline, width=width)
        d.line([pt(s*0.8, -s), pt(0, 0)], fill=outline, width=width)
        d.line([pt(-s*0.5, s*0.5), pt(s*0.5, s*0.5)], fill=outline, width=width)
    elif v == 1:
        d.line([pt(-s*0.7, -s*0.3), pt(s*0.7, -s*0.3)], fill=outline, width=width)
        d.line([pt(-s*0.5, s*0.6), pt(s*0.5, s*0.6)], fill=outline, width=width)
        p = pt(0, -s); d.ellipse([p[0]-4, p[1]-4, p[0]+4, p[1]+4], fill=outline)
    elif v == 2:
        d.line([pt(0, -s*0.6), pt(s*0.8, -s*0.9)], fill=outline, width=width)
        d.line([pt(0, -s*0.1), pt(s*0.8, -s*0.4)], fill=outline, width=width)
    elif v == 3:
        d.line([pt(0, -s), pt(s*0.7, -s*0.3), pt(0, s*0.3)], fill=outline, width=width)
        d.line([pt(0, -s), pt(-s*0.7, -s*0.3), pt(0, s*0.3)], fill=outline, width=width)
        d.line([pt(0, s*0.3), pt(-s*0.6, s)], fill=outline, width=width)
        d.line([pt(0, s*0.3), pt(s*0.6, s)], fill=outline, width=width)
    elif v == 4:
        d.line([pt(0, -s), pt(-s*0.7, -s*0.4)], fill=outline, width=width)
        d.line([pt(0, -s), pt(s*0.7, -s*0.4)], fill=outline, width=width)
        d.line([pt(-s*0.6, 0), pt(s*0.6, 0)], fill=outline, width=width)
        p = pt(0, s*0.7); d.ellipse([p[0]-5, p[1]-5, p[0]+5, p[1]+5], fill=outline)
    elif v == 5:
        d.line([pt(-s*0.7, -s*0.8), pt(0, -s*0.2), pt(s*0.7, -s)], fill=outline, width=width)
        d.line([pt(-s*0.7, s*0.8), pt(0, s*0.2), pt(s*0.7, s)], fill=outline, width=width)
    elif v == 6:
        d.line([pt(-s*0.6, -s), pt(s*0.6, -s*0.4), pt(-s*0.6, 0)], fill=outline, width=width)
        d.line([pt(-s*0.6, 0), pt(s*0.6, s*0.4), pt(-s*0.6, s)], fill=outline, width=width)
    elif v == 7:
        d.line([pt(-s*0.7, -s), pt(s*0.7, s)], fill=outline, width=width)
        d.line([pt(s*0.7, -s), pt(-s*0.7, s)], fill=outline, width=width)
        for p in [pt(0, -s*0.7), pt(0, s*0.7)]: d.ellipse([p[0]-3, p[1]-3, p[0]+3, p[1]+3], fill=outline)
    elif v == 8:
        for dy in [-s*0.5, 0, s*0.5]: d.line([pt(-s*0.6, dy-s*0.2), pt(0, dy), pt(s*0.6, dy-s*0.2)], fill=outline, width=width)
    elif v == 9:
        p0 = pt(0, -s*0.3)
        d.arc([p0[0]-s*0.6, p0[1]-s*0.6, p0[0]+s*0.6, p0[1]+s*0.6], start=0, end=180, fill=outline, width=width)
        d.line([pt(-s*0.5, s*0.4), pt(s*0.5, s*0.4)], fill=outline, width=width)
    elif v == 10:
        d.arc([cx-s*0.7, cy-s*0.7, cx+s*0.7, cy+s*0.7], start=45, end=315, fill=outline, width=width)
        d.line([pt(-s*0.4, 0), pt(s*0.4, 0)], fill=outline, width=width)
    elif v == 11:
        for a_deg in [0, 120, 240]:
            rad = math.radians(a_deg); p = pt(s*0.7*math.cos(rad), s*0.7*math.sin(rad))
            d.line([pt(0, 0), p], fill=outline, width=width)
            d.ellipse([p[0]-4, p[1]-4, p[0]+4, p[1]+4], fill=outline)
    elif v == 12:
        d.polygon([pt(0, -s), pt(s*0.6, -s*0.2), pt(-s*0.6, -s*0.2)], outline=outline)
        d.polygon([pt(0, s), pt(s*0.6, s*0.2), pt(-s*0.6, s*0.2)], outline=outline)
    elif v == 13:
        d.arc([cx-s, cy-s*0.8, cx+s, cy+s*0.8], start=180, end=360, fill=outline, width=width)
        d.line([pt(-s*0.6, s*0.5), pt(0, s*0.8), pt(s*0.6, s*0.5)], fill=outline, width=width)
    elif v == 14:
        d.line([pt(-s*0.7, -s*0.5), pt(0, -s), pt(s*0.7, -s*0.5)], fill=outline, width=width)
        d.line([pt(-s*0.7, s*0.5), pt(0, s), pt(s*0.7, s*0.5)], fill=outline, width=width)
        d.line([pt(-s*0.8, 0), pt(s*0.8, 0)], fill=outline, width=width)
    else:
        d.polygon([pt(0, -s), pt(s*0.5, 0), pt(0, s), pt(-s*0.5, 0)], outline=outline)
        d.line([pt(-s*0.7, 0), pt(s*0.7, 0)], fill=outline, width=width)
        d.line([pt(0, -s), pt(0, s)], fill=outline, width=width)

def apply_vfx_bloom(base_img, glow_color_rgb, blur_levels=[(6, 1.2), (18, 0.8), (48, 0.5), (96, 0.25)]):
    w, h = base_img.size
    alpha = base_img.split()[3]
    base_arr = np.array(base_img, dtype=np.float32)
    glow_accum = np.zeros((h, w, 4), dtype=np.float32)
    rc, gc, bc = glow_color_rgb
    for radius, weight in blur_levels:
        b_alpha = alpha.filter(ImageFilter.GaussianBlur(radius))
        ba = np.array(b_alpha, dtype=np.float32) * weight
        glow_accum[:, :, 0] += ba * (rc / 255.0)
        glow_accum[:, :, 1] += ba * (gc / 255.0)
        glow_accum[:, :, 2] += ba * (bc / 255.0)
        glow_accum[:, :, 3] += ba
    glow_accum = np.clip(glow_accum, 0, 255)
    ba_norm = base_arr[:, :, 3:4] / 255.0
    ga_norm = glow_accum[:, :, 3:4] / 255.0
    final_rgb = base_arr[:, :, :3] * ba_norm + glow_accum[:, :, :3] * ga_norm * (1.0 - ba_norm * 0.5)
    final_rgb = np.clip(final_rgb, 0, 255)
    final_alpha = 1.0 - (1.0 - ba_norm) * (1.0 - ga_norm)
    final_alpha = np.clip(final_alpha * 255.0, 0, 255)
    final_arr = np.dstack((final_rgb, final_alpha)).astype(np.uint8)
    final_img = Image.fromarray(final_arr, mode='RGBA')
    return final_img.resize((1024, 1024), resample=Image.Resampling.LANCZOS)

def gen_divine_light():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    gold, amb, wht = (255, 215, 60, 255), (255, 175, 20, 255), (255, 255, 240, 255)
    for r, w, c in [(950, 5, amb), (920, 3, gold), (880, 4, gold), (820, 2, amb), (780, 4, gold), (680, 3, gold), (640, 3, amb), (500, 4, gold), (460, 2, amb), (320, 4, gold), (160, 4, wht), (80, 5, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    draw_radial_ticks(d, CX, CY, 920, 950, 72, 0, gold, 3)
    draw_radial_ticks(d, CX, CY, 460, 500, 48, 0, amb, 2)
    draw_dashed_ring(d, CX, CY, 900, 48, 0.6, gold, 3)
    draw_dashed_ring(d, CX, CY, 660, 36, 0.5, amb, 3)
    for i in range(24):
        a = i * (2*math.pi / 24); p = polar(CX, CY, 850, a)
        draw_arcane_rune(d, p[0], p[1], 44, i, a + math.pi/2, gold, 3)
    for i in range(12):
        a = i * (2*math.pi / 12)
        d.line([polar(CX, CY, 880, a), polar(CX, CY, 940, a + 0.1)], fill=wht, width=3)
        d.line([polar(CX, CY, 880, a), polar(CX, CY, 940, a - 0.1)], fill=wht, width=3)
    for rot in [0, math.pi/6, math.pi/3, math.pi/2]:
        draw_star_polygon(d, CX, CY, 780, 3, 1, rot, gold, 3)
    draw_star_burst(d, CX, CY, 780, 500, 12, 0, wht, None, 4)
    draw_star_burst(d, CX, CY, 460, 320, 12, math.pi/12, gold, None, 3)
    for i in range(12):
        a = i * (2*math.pi / 12); p = polar(CX, CY, 570, a)
        draw_circle_ring(d, p[0], p[1], 35, amb, 2)
        draw_star_burst(d, p[0], p[1], 28, 12, 8, a, gold, None, 2)
        draw_circle_ring(d, p[0], p[1], 6, wht, 3)
    for i in range(4):
        a = i * (math.pi/2)
        d.line([polar(CX, CY, 0, a), polar(CX, CY, 320, a)], fill=wht, width=5)
        d.line([polar(CX, CY, 160, a - 0.15), polar(CX, CY, 320, a), polar(CX, CY, 160, a + 0.15)], fill=gold, width=3)
    d.ellipse([CX-60, CY-60, CX+60, CY+60], fill=wht, outline=gold, width=4)
    return apply_vfx_bloom(img, (255, 200, 40))

def gen_inferno_flame():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    org, red, wht = (255, 130, 10, 255), (220, 40, 0, 255), (255, 250, 200, 255)
    for r, w, c in [(950, 5, red), (900, 3, org), (840, 4, org), (750, 4, red), (700, 3, org), (520, 4, red), (480, 3, org), (300, 4, red), (160, 4, org), (70, 5, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    for i in range(16):
        a = i * (2*math.pi / 16)
        p1 = polar(CX, CY, 890, a); p2 = polar(CX, CY, 960, a + 0.18); p3 = polar(CX, CY, 920, a + 0.09)
        d.line([p1, p3, p2], fill=org, width=4)
        d.line([polar(CX, CY, 900, a + 0.05), polar(CX, CY, 950, a + 0.22)], fill=wht, width=2)
    draw_radial_ticks(d, CX, CY, 840, 870, 64, 0, red, 2)
    draw_dashed_ring(d, CX, CY, 725, 32, 0.5, org, 3)
    for i in range(16):
        a = i * (2*math.pi / 16); p = polar(CX, CY, 795, a)
        draw_arcane_rune(d, p[0], p[1], 48, i*2 + 5, a + math.pi/2, org, 3)
    draw_star_polygon(d, CX, CY, 750, 5, 2, -math.pi/2, red, 5)
    draw_star_polygon(d, CX, CY, 750, 5, 2, math.pi/2, org, 4)
    draw_star_burst(d, CX, CY, 750, 520, 10, 0, wht, None, 3)
    for i in range(10):
        a = i * (2*math.pi / 10); p = polar(CX, CY, 750, a)
        draw_circle_ring(d, p[0], p[1], 25, org, 3)
        draw_circle_ring(d, p[0], p[1], 10, wht, 3)
        d.line([p, polar(CX, CY, 520, a + math.pi/10)], fill=red, width=3)
        d.line([p, polar(CX, CY, 520, a - math.pi/10)], fill=red, width=3)
    draw_star_polygon(d, CX, CY, 480, 5, 2, -math.pi/2, org, 4)
    draw_star_polygon(d, CX, CY, 300, 5, 1, math.pi/2, red, 3)
    for i in range(12):
        a = i * (2*math.pi / 12)
        d.arc([CX-180, CY-180, CX+180, CY+180], start=math.degrees(a), end=math.degrees(a+math.pi/3), fill=org, width=4)
    d.ellipse([CX-50, CY-120, CX+50, CY+120], outline=org, width=4)
    d.polygon([polar(CX, CY, 90, -math.pi/2), polar(CX, CY, 20, 0), polar(CX, CY, 90, math.pi/2), polar(CX, CY, 20, math.pi)], fill=wht)
    return apply_vfx_bloom(img, (255, 100, 10))

def gen_glacial_frost():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    cyan, azu, wht = (0, 235, 255, 255), (30, 150, 255, 255), (240, 255, 255, 255)
    for r, w, c in [(950, 5, azu), (900, 3, cyan), (840, 4, cyan), (760, 4, azu), (700, 3, cyan), (540, 4, azu), (480, 3, cyan), (320, 4, azu), (160, 4, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    draw_regular_polygon(d, CX, CY, 950, 12, 0, azu, 3)
    draw_regular_polygon(d, CX, CY, 840, 6, 0, cyan, 4)
    draw_regular_polygon(d, CX, CY, 840, 6, math.pi/6, cyan, 4)
    draw_regular_polygon(d, CX, CY, 540, 6, 0, azu, 3)
    draw_dashed_ring(d, CX, CY, 870, 36, 0.6, cyan, 3)
    draw_radial_ticks(d, CX, CY, 900, 940, 48, 0, wht, 2)
    for i in range(24):
        a = i * (2*math.pi / 24); p = polar(CX, CY, 800, a)
        draw_arcane_rune(d, p[0], p[1], 44, i + 8, a + math.pi/2, cyan, 3)
    for i in range(12):
        a = i * (2*math.pi / 12); p_tip = polar(CX, CY, 950, a)
        d.line([polar(CX, CY, 320, a), p_tip], fill=wht, width=4)
        for dist in [420, 580, 720]:
            pb = polar(CX, CY, dist, a)
            for da in [-0.25, 0.25]:
                p_sub = (pb[0] + 55*math.cos(a + da + math.pi/2), pb[1] + 55*math.sin(a + da + math.pi/2))
                d.line([pb, p_sub], fill=cyan, width=3)
        p_dia = polar(CX, CY, 640, a)
        draw_star_burst(d, p_dia[0], p_dia[1], 25, 10, 4, a, wht, None, 2)
    draw_star_polygon(d, CX, CY, 480, 6, 2, 0, wht, 4)
    draw_star_polygon(d, CX, CY, 480, 6, 2, math.pi/6, cyan, 3)
    for i in range(6):
        a = i * (2*math.pi / 6); p = polar(CX, CY, 240, a)
        draw_circle_ring(d, p[0], p[1], 20, cyan, 2)
        draw_star_burst(d, p[0], p[1], 15, 6, 6, a, wht, None, 2)
    d.ellipse([CX-50, CY-50, CX+50, CY+50], fill=wht, outline=cyan, width=4)
    return apply_vfx_bloom(img, (0, 210, 255))

def gen_void_abyss():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    vio, mag, wht = (140, 20, 240, 255), (225, 40, 240, 255), (255, 220, 255, 255)
    for r, w, c in [(950, 5, vio), (910, 3, mag), (850, 4, vio), (760, 4, mag), (680, 3, vio), (510, 4, mag), (420, 3, vio), (280, 4, mag), (140, 5, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    draw_radial_ticks(d, CX, CY, 910, 950, 64, 0, mag, 2)
    draw_dashed_ring(d, CX, CY, 880, 32, 0.5, vio, 3)
    for arm in range(8):
        a_offset = arm * (2*math.pi / 8)
        s_pts = [polar(CX, CY, 100 + (step/50.0)*830, a_offset + (step/50.0)*2.5) for step in range(50)]
        d.line(s_pts, fill=mag, width=3)
    for i in range(16):
        a = i * (2*math.pi / 16); p = polar(CX, CY, 805, a)
        draw_arcane_rune(d, p[0], p[1], 46, i*3 + 1, a + math.pi/2, mag, 3)
    for i in range(8):
        a = i * (2*math.pi / 8); p = polar(CX, CY, 600, a)
        draw_circle_ring(d, p[0], p[1], 30, vio, 3)
        d.ellipse([p[0]-12, p[1]-12, p[0]+12, p[1]+12], fill=wht)
        d.arc([p[0]-40, p[1]-40, p[0]+40, p[1]+40], start=math.degrees(a), end=math.degrees(a+math.pi), fill=mag, width=3)
    for rot in [0, math.pi/3]:
        draw_star_polygon(d, CX, CY, 510, 3, 1, rot, mag, 4)
    for i in range(16):
        a = i * (2*math.pi / 16)
        d.arc([CX-280, CY-280, CX+280, CY+280], start=math.degrees(a), end=math.degrees(a+math.pi/2), fill=vio, width=3)
    d.ellipse([CX-70, CY-70, CX+70, CY+70], fill=wht, outline=mag, width=5)
    d.ellipse([CX-35, CY-35, CX+35, CY+35], fill=(20, 0, 35, 255))
    return apply_vfx_bloom(img, (180, 30, 250))

def gen_tempest_lightning():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    cyn, cob, wht = (0, 245, 255, 255), (60, 100, 255, 255), (255, 255, 255, 255)
    for r, w, c in [(950, 5, cob), (890, 3, cyn), (830, 4, cyn), (760, 4, cob), (670, 3, cyn), (520, 4, cob), (440, 3, cyn), (280, 4, cob), (140, 5, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    draw_radial_ticks(d, CX, CY, 890, 950, 64, 0, cyn, 2)
    draw_dashed_ring(d, CX, CY, 860, 32, 0.5, cob, 3)
    for rot in [0, math.pi/4]:
        draw_star_polygon(d, CX, CY, 760, 4, 1, rot, cyn, 4)
    draw_star_burst(d, CX, CY, 920, 670, 8, math.pi/8, wht, None, 4)
    for i in range(16):
        a = i * (2*math.pi / 16); p = polar(CX, CY, 795, a)
        draw_arcane_rune(d, p[0], p[1], 46, i*4 + 6, a + math.pi/2, cyn, 3)
    for i in range(8):
        a = i * (2*math.pi / 8)
        path = [polar(CX, CY, 440 + seg*80, a + (((-1)**seg)*0.07 if seg>0 else 0)) for seg in range(7)]
        d.line(path, fill=wht, width=3)
        p_node = polar(CX, CY, 670, a)
        draw_circle_ring(d, p_node[0], p_node[1], 18, cyn, 3)
        draw_circle_ring(d, p_node[0], p_node[1], 7, wht, 3)
    draw_star_burst(d, CX, CY, 440, 280, 8, 0, cyn, None, 3)
    for i in range(4):
        a = i * (math.pi/2)
        d.line([polar(CX, CY, 0, a), polar(CX, CY, 280, a)], fill=wht, width=6)
        d.line([polar(CX, CY, 140, a - 0.12), polar(CX, CY, 280, a), polar(CX, CY, 140, a + 0.12)], fill=cyn, width=3)
    d.ellipse([CX-55, CY-55, CX+55, CY+55], fill=wht, outline=cyn, width=4)
    return apply_vfx_bloom(img, (40, 170, 255))

def gen_spirit_nature():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    emr, jad, wht, gld = (30, 245, 110, 255), (10, 190, 80, 255), (240, 255, 240, 255), (160, 255, 70, 255)
    for r, w, c in [(950, 5, jad), (910, 3, emr), (850, 4, emr), (770, 4, jad), (690, 3, emr), (530, 4, jad), (430, 3, emr), (310, 4, jad), (150, 4, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    kp1 = [polar(CX, CY, 930 + 20*math.sin(s*16*math.pi/180), s*(2*math.pi/180)) for s in range(181)]
    kp2 = [polar(CX, CY, 930 - 20*math.sin(s*16*math.pi/180), s*(2*math.pi/180)) for s in range(181)]
    d.line(kp1, fill=emr, width=3); d.line(kp2, fill=gld, width=3)
    for i in range(16):
        a = i * (2*math.pi / 16); p = polar(CX, CY, 810, a)
        draw_arcane_rune(d, p[0], p[1], 44, i + 12, a + math.pi/2, emr, 3)
    for i in range(8):
        a = i * (2*math.pi / 8); p_tip = polar(CX, CY, 770, a)
        d.line([polar(CX, CY, 530, a - 0.25), p_tip, polar(CX, CY, 530, a + 0.25)], fill=emr, width=4)
        d.line([polar(CX, CY, 530, a), p_tip], fill=wht, width=2)
        p_leaf = polar(CX, CY, 650, a)
        draw_circle_ring(d, p_leaf[0], p_leaf[1], 22, gld, 3); draw_circle_ring(d, p_leaf[0], p_leaf[1], 8, wht, 3)
    for rot in [0, math.pi/4]:
        draw_regular_polygon(d, CX, CY, 430, 4, rot, emr, 4)
    for i in range(8):
        a = i * (2*math.pi / 8); p_c = polar(CX, CY, 220, a)
        draw_circle_ring(d, p_c[0], p_c[1], 90, emr, 3)
    d.ellipse([CX-55, CY-55, CX+55, CY+55], fill=wht, outline=emr, width=4)
    return apply_vfx_bloom(img, (20, 230, 90))

def gen_archdaeva_transcendence():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    gld, cyn, vio, wht = (255, 225, 90, 255), (90, 220, 255, 255), (210, 130, 255, 255), (255, 255, 255, 255)
    for r, w, c in [(950, 5, gld), (900, 3, cyn), (840, 4, vio), (750, 4, gld), (660, 3, cyn), (500, 4, vio), (400, 3, gld), (260, 4, cyn), (120, 5, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    draw_radial_ticks(d, CX, CY, 900, 950, 120, 0, gld, 2)
    draw_radial_ticks(d, CX, CY, 840, 900, 48, 0, cyn, 2)
    draw_dashed_ring(d, CX, CY, 870, 48, 0.5, vio, 3)
    for i in range(12):
        a = i * (2*math.pi / 12); p = polar(CX, CY, 795, a)
        draw_arcane_rune(d, p[0], p[1], 48, i + 3, a + math.pi/2, gld, 3)
    meta_pts = [polar(CX, CY, 500, i * (math.pi/3)) for i in range(6)]
    meta_inner = [polar(CX, CY, 260, i * (math.pi/3) + math.pi/6) for i in range(6)]
    all_meta = meta_pts + meta_inner + [(CX, CY)]
    for pt in all_meta:
        draw_circle_ring(d, pt[0], pt[1], 55, cyn, 2)
        draw_circle_ring(d, pt[0], pt[1], 15, wht, 2)
    for i in range(len(all_meta)):
        for j in range(i+1, len(all_meta)):
            d.line([all_meta[i], all_meta[j]], fill=(140, 200, 255, 120), width=2)
    draw_star_burst(d, CX, CY, 940, 750, 24, 0, wht, None, 3)
    draw_star_polygon(d, CX, CY, 660, 6, 2, 0, gld, 3)
    draw_star_polygon(d, CX, CY, 660, 6, 2, math.pi/6, vio, 3)
    d.ellipse([CX-45, CY-45, CX+45, CY+45], fill=wht, outline=gld, width=4)
    return apply_vfx_bloom(img, (160, 210, 255))

def gen_tiamat_balaur_curse():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0)); d = ImageDraw.Draw(img)
    crm, sca, nec, wht = (255, 20, 50, 255), (180, 0, 30, 255), (100, 0, 20, 255), (255, 210, 210, 255)
    for r, w, c in [(950, 5, nec), (900, 3, crm), (840, 4, sca), (750, 4, crm), (680, 3, sca), (500, 4, crm), (400, 3, sca), (260, 4, crm), (130, 5, wht)]:
        draw_circle_ring(d, CX, CY, r, c, w)
    for i in range(24):
        a = i * (2*math.pi / 24)
        p_tip = polar(CX, CY, 980, a + 0.08)
        d.polygon([polar(CX, CY, 890, a - 0.05), p_tip, polar(CX, CY, 910, a + 0.12)], fill=crm, outline=wht)
    draw_radial_ticks(d, CX, CY, 840, 880, 72, 0, sca, 2)
    draw_dashed_ring(d, CX, CY, 870, 28, 0.5, nec, 4)
    for i in range(14):
        a = i * (2*math.pi / 14); p = polar(CX, CY, 795, a)
        draw_arcane_rune(d, p[0], p[1], 48, i*2 + 1, a + math.pi/2, crm, 3)
    draw_star_polygon(d, CX, CY, 750, 7, 3, -math.pi/2, crm, 5)
    draw_star_polygon(d, CX, CY, 750, 7, 2, -math.pi/2, sca, 3)
    for i in range(7):
        a = -math.pi/2 + i * (2*math.pi / 7); p = polar(CX, CY, 750, a)
        draw_circle_ring(d, p[0], p[1], 28, crm, 3); draw_circle_ring(d, p[0], p[1], 10, wht, 3)
        d.line([p, polar(CX, CY, 850, a)], fill=crm, width=4)
    for rot in [-math.pi/2, math.pi/2]:
        draw_regular_polygon(d, CX, CY, 500, 7, rot, sca, 3)
    for i in range(14):
        a = i * (2*math.pi / 14)
        d.arc([CX-260, CY-260, CX+260, CY+260], start=math.degrees(a), end=math.degrees(a+math.pi/3), fill=crm, width=4)
    d.ellipse([CX-40, CY-100, CX+40, CY+100], fill=crm, outline=wht, width=3)
    d.polygon([polar(CX, CY, 80, -math.pi/2), polar(CX, CY, 15, 0), polar(CX, CY, 80, math.pi/2), polar(CX, CY, 15, math.pi)], fill=(10, 0, 10, 255))
    return apply_vfx_bloom(img, (240, 20, 40))

def main():
    out_dir = 'assets/images/vfx_sprites/magic_circles'
    os.makedirs(out_dir, exist_ok=True)
    tasks = [
        ('magic_circle_divine_light.png', gen_divine_light),
        ('magic_circle_inferno_flame.png', gen_inferno_flame),
        ('magic_circle_glacial_frost.png', gen_glacial_frost),
        ('magic_circle_void_abyss.png', gen_void_abyss),
        ('magic_circle_tempest_lightning.png', gen_tempest_lightning),
        ('magic_circle_spirit_nature.png', gen_spirit_nature),
        ('magic_circle_archdaeva_transcendence.png', gen_archdaeva_transcendence),
        ('magic_circle_tiamat_balaur_curse.png', gen_tiamat_balaur_curse),
    ]
    for filename, fn in tasks:
        path = f'{out_dir}/{filename}'
        print(f'Rendering {filename}...')
        img = fn()
        img.save(path, format='PNG', optimize=True)
        sz = os.path.getsize(path)
        w, h = img.size
        amin, amax = img.getextrema()[3]
        print(f'Done {filename}: {w}x{h}, {sz/1024:.1f} KB, Alpha: [{amin}, {amax}]')
    print('ALL 8 CIRCLES GENERATED AND VERIFIED SUCCESSFULLY')

if __name__ == '__main__':
    main()
