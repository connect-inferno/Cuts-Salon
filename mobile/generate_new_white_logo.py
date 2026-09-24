import os
import math
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

def generate_luxury_white_logo():
    mobile_dir = r"d:\Cuts-Salon\mobile"
    assets_img_dir = os.path.join(mobile_dir, "assets", "images")
    web_dir = os.path.join(mobile_dir, "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    build_web_dir = os.path.join(mobile_dir, "build", "web")
    
    os.makedirs(assets_img_dir, exist_ok=True)
    os.makedirs(web_icons_dir, exist_ok=True)
    
    # 2048x2048 super-sampled canvas for ultra-crisp antialiased edges
    size = 2048
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    
    # Drawing on a grayscale mask for precise sub-pixel antialiasing
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    
    cx, cy = size / 2.0, size / 2.0
    scale = size / 1000.0  # Normalized coordinate multiplier
    
    # Modern Luxury Salon Styling Shears & Monogram:
    # An iconic, minimalist pair of precision shears rotated elegantly at -35 degrees
    # Featuring:
    # 1. Two razor-sharp tapered styling blades extending upward & right
    # 2. Precision circular pivot ring & diamond jewel at the center
    # 3. Two ergonomic luxury finger loops / rings extending downward & left,
    #    with an integrated finger rest / tang hook.
    # 4. Clean architectural line weights in pure platinum white.

    angle = -math.radians(35)
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    
    def transform(x, y):
        # Rotate around (cx, cy) and apply scale
        rx = x * scale
        ry = y * scale
        tx = cx + (rx * cos_a - ry * sin_a)
        ty = cy + (rx * sin_a + ry * cos_a)
        return tx, ty

    # A. Draw Upper Blade (Right Blade):
    # Originates from pivot (0,0), extends to (0, -420), width tapers from 38 to 3
    blade_pts_right = []
    num_pts = 100
    for i in range(num_pts + 1):
        t = i / float(num_pts)
        y = -t * 420
        # Blade curve: subtle convex spine
        x_spine = math.sin(t * math.pi) * 12
        w_blade = (1.0 - t * 0.94) * 38
        
        # Right blade edge
        p_spine = transform(x_spine + w_blade, y)
        p_edge = transform(x_spine - 4, y)
        # We can draw circles along the blade path for perfect smoothness
        p_center = transform(x_spine + w_blade * 0.45, y)
        r = w_blade * 0.5 * scale
        draw.ellipse([p_center[0] - r, p_center[1] - r, p_center[0] + r, p_center[1] + r], fill=255)

    # B. Draw Lower Blade (Left Blade):
    for i in range(num_pts + 1):
        t = i / float(num_pts)
        y = -t * 420
        x_spine = -math.sin(t * math.pi) * 12
        w_blade = (1.0 - t * 0.94) * 38
        
        p_center = transform(x_spine - w_blade * 0.45, y)
        r = w_blade * 0.5 * scale
        draw.ellipse([p_center[0] - r, p_center[1] - r, p_center[0] + r, p_center[1] + r], fill=255)

    # C. Draw Center Pivot Boss & Dial:
    # Outer ring
    p_pivot = transform(0, 0)
    r_outer = 48 * scale
    draw.ellipse([p_pivot[0] - r_outer, p_pivot[1] - r_outer, p_pivot[0] + r_outer, p_pivot[1] + r_outer], fill=255)
    # Inner cutout for hollow pivot ring
    r_inner = 24 * scale
    draw.ellipse([p_pivot[0] - r_inner, p_pivot[1] - r_inner, p_pivot[0] + r_inner, p_pivot[1] + r_inner], fill=0)
    # Center diamond jewel
    jewel_r = 14 * scale
    diamond = [
        (p_pivot[0], p_pivot[1] - jewel_r * 1.5),
        (p_pivot[0] + jewel_r, p_pivot[1]),
        (p_pivot[0], p_pivot[1] + jewel_r * 1.5),
        (p_pivot[0] - jewel_r, p_pivot[1]),
    ]
    draw.polygon(diamond, fill=255)

    # D. Draw Left Handle & Finger Loop (Thumb ring):
    # Sweeps from pivot (0,0) down to (-95, 260) with an open ring (radius 105)
    thumb_center = (-105, 275)
    ring_radius = 100
    ring_thickness = 26
    
    # Handle shank connecting pivot to ring
    for i in range(60):
        t = i / 60.0
        x = -t * 90
        y = t * 185
        r = (28 - t * 6) * scale
        pt = transform(x, y)
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=255)

    # Draw Thumb Ring (Full 360 circle with thick wall)
    for i in range(360):
        t = i / 360.0 * 2 * math.pi
        rx = thumb_center[0] + math.cos(t) * ring_radius
        ry = thumb_center[1] + math.sin(t) * ring_radius
        pt = transform(rx, ry)
        r = ring_thickness * scale * 0.5
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=255)

    # E. Draw Right Handle & Finger Loop (Finger ring) + Tang rest:
    finger_center = (95, 305)
    # Handle shank
    for i in range(60):
        t = i / 60.0
        x = t * 80
        y = t * 215
        r = (28 - t * 6) * scale
        pt = transform(x, y)
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=255)

    # Draw Finger Ring
    for i in range(360):
        t = i / 360.0 * 2 * math.pi
        rx = finger_center[0] + math.cos(t) * ring_radius
        ry = finger_center[1] + math.sin(t) * ring_radius
        pt = transform(rx, ry)
        r = ring_thickness * scale * 0.5
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=255)

    # Elegant Tang / Finger Rest:
    # A graceful upward curl from (175, 370) to (235, 415)
    for i in range(40):
        t = i / 40.0
        x = 175 + t * 60 + math.sin(t * math.pi) * 10
        y = 370 + t * 45
        r = (18 * (1.0 - t * 0.7)) * scale
        pt = transform(x, y)
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=255)

    # Apply subtle antialiasing filter
    mask = mask.filter(ImageFilter.SMOOTH)

    # Assemble Pure White RGBA Logo
    alpha_arr = np.array(mask)
    white_arr = np.zeros((size, size, 4), dtype=np.uint8)
    white_arr[:, :, 0] = 255  # Pure White R
    white_arr[:, :, 1] = 255  # Pure White G
    white_arr[:, :, 2] = 255  # Pure White B
    white_arr[:, :, 3] = alpha_arr

    white_logo_1024 = Image.fromarray(white_arr).resize((1024, 1024), Image.Resampling.LANCZOS)
    
    # Save standalone white logo (transparent background)
    white_logo_path = os.path.join(assets_img_dir, "stylux_white_logo.png")
    white_logo_1024.save(white_logo_path, "PNG")
    print(f"1. Saved pure white logo: {white_logo_path}")
    
    # Also save as stylux_mark.png (transparent background)
    mark_path = os.path.join(assets_img_dir, "stylux_mark.png")
    white_logo_1024.save(mark_path, "PNG")
    print(f"2. Saved stylux_mark.png (pure white on transparent)")

    # Dark Slate Version for light-background headers
    dark_arr = np.zeros((size, size, 4), dtype=np.uint8)
    dark_arr[:, :, 0] = 15   # #0F172A
    dark_arr[:, :, 1] = 23
    dark_arr[:, :, 2] = 42
    dark_arr[:, :, 3] = alpha_arr
    dark_logo_1024 = Image.fromarray(dark_arr).resize((1024, 1024), Image.Resampling.LANCZOS)
    dark_logo_path = os.path.join(assets_img_dir, "stylux_dark_logo.png")
    dark_logo_1024.save(dark_logo_path, "PNG")

    # 3. Create Master App Icon & Favicon:
    # A sleek Obsidian luxury badge (#090D16 -> #0F172A) with subtle platinum border
    # AND 100% TRANSPARENT EXTERIOR (No white corners anywhere!)
    icon_canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    idraw = ImageDraw.Draw(icon_canvas)
    
    # Squircle with transparent corners
    r = int(1024 * 0.22)
    margin = int(1024 * 0.04)
    
    # Base obsidian rectangle
    idraw.rounded_rectangle(
        [margin, margin, 1024 - margin, 1024 - margin],
        radius=r,
        fill=(9, 13, 22, 255) # Deep Obsidian #090D16
    )
    # Subtle platinum rim
    idraw.rounded_rectangle(
        [margin, margin, 1024 - margin, 1024 - margin],
        radius=r,
        outline=(255, 255, 255, 35),
        width=3
    )
    
    # Place white logo in center of squircle
    emblem_scaled = white_logo_1024.resize((660, 660), Image.Resampling.LANCZOS)
    icon_canvas.paste(emblem_scaled, ((1024 - 660) // 2, (1024 - 660) // 2), emblem_scaled)
    
    icon_path = os.path.join(assets_img_dir, "stylux_icon.png")
    icon_canvas.save(icon_path, "PNG")
    icon_canvas.save(os.path.join(assets_img_dir, "trimly_icon.png"), "PNG")
    print(f"3. Saved master app icon: {icon_path}")

    # 4. Save Favicon (64x64) with 100% transparent corners
    fav_64 = icon_canvas.resize((64, 64), Image.Resampling.LANCZOS)
    fav_path = os.path.join(web_dir, "favicon.png")
    fav_64.save(fav_path, "PNG")
    if os.path.exists(build_web_dir):
        fav_64.save(os.path.join(build_web_dir, "favicon.png"), "PNG")
    print(f"4. Saved web/favicon.png: {fav_path}")

    # PWA icons
    for sz in [192, 512]:
        pwa_icon = icon_canvas.resize((sz, sz), Image.Resampling.LANCZOS)
        pwa_icon.save(os.path.join(web_icons_dir, f"Icon-{sz}.png"), "PNG")
        pwa_icon.save(os.path.join(web_icons_dir, f"Icon-maskable-{sz}.png"), "PNG")
    print("5. Saved PWA web icons")

if __name__ == "__main__":
    generate_luxury_white_logo()
