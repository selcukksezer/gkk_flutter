import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

INPUT_IMAGES = {
    'asmodian_gladiator.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_gladiator_1793223393917.jpg',
    'asmodian_templar.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_templar_1793223455988.jpg',
    'asmodian_sorcerer.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_sorcerer_1793224013398.jpg',
    'asmodian_spiritmaster.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_spiritmaster_1793224688665.jpg',
    'asmodian_cleric.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_cleric_1793224803956.jpg',
    'asmodian_chanter.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_chanter_1793224943685.jpg',
    'asmodian_ranger.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_ranger_1793224998369.jpg',
    'asmodian_assassin.png': r'C:\Users\selçuk\.gemini\antigravity-cli\brain\8be8ee91-bb72-4fc3-ba04-663d44a09e4a\asmodian_assassin_1793225059559.jpg',
}

OUTPUT_DIR = r'C:\Users\selçuk\orca\workspaces\gkk_flutter\prawn\assets\images\portraits\asmodian'

def create_gothic_spiked_frame(size=(1024, 1024)):
    w, h = size
    frame = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)

    border_thickness = 28
    inner_inset = 34

    draw.rectangle([0, 0, w, border_thickness], fill=(12, 10, 14, 255))
    draw.rectangle([0, h - border_thickness, w, h], fill=(12, 10, 14, 255))
    draw.rectangle([0, 0, border_thickness, h], fill=(12, 10, 14, 255))
    draw.rectangle([w - border_thickness, 0, w, h], fill=(12, 10, 14, 255))

    draw.rectangle([border_thickness - 4, border_thickness - 4, w - border_thickness + 4, border_thickness], fill=(45, 38, 48, 240))
    draw.rectangle([border_thickness - 4, h - border_thickness, w - border_thickness + 4, h - border_thickness + 4], fill=(25, 20, 28, 240))
    draw.rectangle([border_thickness - 4, border_thickness - 4, border_thickness, h - border_thickness + 4], fill=(45, 38, 48, 240))
    draw.rectangle([w - border_thickness, border_thickness - 4, w - border_thickness + 4, h - border_thickness + 4], fill=(25, 20, 28, 240))

    crimson_line_color = (220, 30, 45, 200)
    draw.rectangle([inner_inset, inner_inset, w - inner_inset, h - inner_inset], outline=crimson_line_color, width=3)

    corner_size = 70
    spike_color = (18, 14, 22, 255)
    spike_edge = (160, 25, 35, 220)

    # Top-Left
    draw.polygon([(0, 0), (corner_size, 0), (inner_inset, inner_inset), (0, corner_size)], fill=spike_color, outline=spike_edge)
    draw.line([(0, 0), (corner_size + 15, 0), (0, corner_size + 15)], fill=(200, 40, 50, 180), width=2)
    draw.polygon([(0, 0), (corner_size + 25, 8), (inner_inset + 10, inner_inset + 10), (8, corner_size + 25)], fill=(25, 20, 30, 255), outline=spike_edge)

    # Top-Right
    draw.polygon([(w, 0), (w - corner_size, 0), (w - inner_inset, inner_inset), (w, corner_size)], fill=spike_color, outline=spike_edge)
    draw.line([(w, 0), (w - corner_size - 15, 0), (w, corner_size + 15)], fill=(200, 40, 50, 180), width=2)
    draw.polygon([(w, 0), (w - corner_size - 25, 8), (w - inner_inset - 10, inner_inset + 10), (w - 8, corner_size + 25)], fill=(25, 20, 30, 255), outline=spike_edge)

    # Bottom-Left
    draw.polygon([(0, h), (corner_size, h), (inner_inset, h - inner_inset), (0, h - corner_size)], fill=spike_color, outline=spike_edge)
    draw.line([(0, h), (corner_size + 15, h), (0, h - corner_size - 15)], fill=(200, 40, 50, 180), width=2)
    draw.polygon([(0, h), (corner_size + 25, h - 8), (inner_inset + 10, h - inner_inset - 10), (8, h - corner_size - 25)], fill=(25, 20, 30, 255), outline=spike_edge)

    # Bottom-Right
    draw.polygon([(w, h), (w - corner_size, h), (w - inner_inset, h - inner_inset), (w, h - corner_size)], fill=spike_color, outline=spike_edge)
    draw.line([(w, h), (w - corner_size - 15, h), (w, h - corner_size - 15)], fill=(200, 40, 50, 180), width=2)
    draw.polygon([(w, h), (w - corner_size - 25, h - 8), (w - inner_inset - 10, h - inner_inset - 10), (w - 8, h - corner_size - 25)], fill=(25, 20, 30, 255), outline=spike_edge)

    # Thorns
    draw.polygon([(w//2 - 20, 0), (w//2, 38), (w//2 + 20, 0)], fill=spike_color, outline=spike_edge)
    draw.polygon([(w//2 - 20, h), (w//2, h - 38), (w//2 + 20, h)], fill=spike_color, outline=spike_edge)
    draw.polygon([(0, h//2 - 20), (38, h//2), (0, h//2 + 20)], fill=spike_color, outline=spike_edge)
    draw.polygon([(w, h//2 - 20), (w - 38, h//2), (w, h//2 + 20)], fill=spike_color, outline=spike_edge)

    def draw_rune_gem(cx, cy):
        pts = [(cx, cy - 8), (cx + 8, cy), (cx, cy + 8), (cx - 8, cy)]
        draw.polygon(pts, fill=(240, 45, 60, 240), outline=(255, 180, 190, 255))
        draw.point((cx, cy), fill=(255, 255, 255, 255))

    draw_rune_gem(w//2, 16)
    draw_rune_gem(w//2, h - 16)
    draw_rune_gem(16, h//2)
    draw_rune_gem(w - 16, h//2)

    return frame

def create_abyss_vignette(size=(1024, 1024)):
    w, h = size
    x = np.linspace(-1, 1, w)
    y = np.linspace(-1, 1, h)
    xx, yy = np.meshgrid(x, y)
    radius = np.sqrt(xx**2 + yy**2)
    
    mask = np.clip((radius - 0.45) / 0.65, 0.0, 1.0)
    mask = mask * mask * (3 - 2 * mask)
    alpha = (mask * 140).astype(np.uint8)

    vignette = Image.new('RGBA', size, (5, 3, 8, 0))
    vignette.putalpha(Image.fromarray(alpha))
    return vignette

def process_portrait(src_path, dst_path, frame, vignette):
    img = Image.open(src_path).convert('RGBA')
    img = img.resize((1024, 1024), Image.Resampling.LANCZOS)

    enhancer_con = ImageEnhance.Contrast(img)
    img = enhancer_con.enhance(1.08)
    enhancer_sat = ImageEnhance.Color(img)
    img = enhancer_sat.enhance(1.05)
    enhancer_sharp = ImageEnhance.Sharpness(img)
    img = enhancer_sharp.enhance(1.15)

    img.alpha_composite(vignette)
    img.alpha_composite(frame)

    img.save(dst_path, format='PNG', optimize=True)
    size_bytes = os.path.getsize(dst_path)
    print(f'Processed: {os.path.basename(dst_path)} -> {img.size[0]}x{img.size[1]} ({size_bytes/1024:.1f} KB)')
    return dst_path

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    frame = create_gothic_spiked_frame((1024, 1024))
    vignette = create_abyss_vignette((1024, 1024))

    for filename, src in INPUT_IMAGES.items():
        dst = os.path.join(OUTPUT_DIR, filename)
        if not os.path.exists(src):
            raise FileNotFoundError(f'Source file not found: {src}')
        process_portrait(src, dst, frame, vignette)

    print('All 8 Asmodian portraits processed successfully!')

if __name__ == '__main__':
    main()
