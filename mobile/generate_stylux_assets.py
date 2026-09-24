import os
import math
from PIL import Image, ImageDraw, ImageFont

# Set up paths
mobile_dir = r"d:\Cuts-Salon\mobile"
assets_img_dir = os.path.join(mobile_dir, "assets", "images")
web_icons_dir = os.path.join(mobile_dir, "web", "icons")
web_favicon = os.path.join(mobile_dir, "web", "favicon.png")
os.makedirs(assets_img_dir, exist_ok=True)
os.makedirs(web_icons_dir, exist_ok=True)

def create_stylux_icon(size=1024):
    """
    Creates a master premium high-res Stylux icon:
    Modern rounded squircle with dark luxury slate gradient background,
    featuring an elegant, flowing geometric 'S' monogram with precision shear & styling curves.
    """
    # Supersampling factor for ultra-crisp edges
    scale = 2
    w = size * scale
    h = size * scale
    
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 1. Background Rounded Squircle with subtle gradient
    # Gradient from #0F172A (slateDark) to #1E1B4B (deep indigo night)
    r = int(w * 0.22)
    # Draw dark base
    draw.rounded_rectangle([int(w*0.04), int(h*0.04), int(w*0.96), int(h*0.96)], radius=r, fill=(15, 23, 42, 255))
    
    # Inner subtle radial/linear glow
    glow_overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_overlay)
    
    # Soft indigo ambient glow at center-top
    cx, cy = int(w * 0.5), int(h * 0.45)
    for radius in range(int(w * 0.45), 0, -6):
        alpha = int((1.0 - (radius / (w * 0.45))) ** 2 * 45)
        glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(79, 70, 229, alpha))
        
    img = Image.alpha_composite(img, glow_overlay)
    draw = ImageDraw.Draw(img)
    
    # Subtle border rim
    draw.rounded_rectangle([int(w*0.04), int(h*0.04), int(w*0.96), int(h*0.96)], radius=r, outline=(255, 255, 255, 30), width=int(3*scale))

    # 2. Draw Stylux "S" Emblem (Geometric Flowing Curves with Precision Shears Aesthetics)
    # The emblem consists of two fluid sweeping ribbon arcs meeting with a precision diagonal taper
    # Upper Arc (Indigo -> Violet Gradient)
    # Lower Arc (Violet -> Electric Indigo)
    # Sparkle / Diamond Apex (Pure White / Cyan-Gold)
    
    emblem_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    edraw = ImageDraw.Draw(emblem_layer)
    
    # Draw geometric precision curves for Stylux 'S'
    # Upper loop of 'S'
    upper_points = []
    num_pts = 60
    # Center reference
    ox, oy = w * 0.5, h * 0.5
    
    # Draw upper sweeping blade ribbon
    upper_blade = [
        (ox + w*0.18, oy - h*0.24), # top right apex
        (ox + w*0.02, oy - h*0.28),
        (ox - w*0.18, oy - h*0.22),
        (ox - w*0.24, oy - h*0.08),
        (ox - w*0.14, oy + h*0.04),
        (ox + w*0.14, oy + h*0.02),
        (ox + w*0.20, oy - h*0.06),
        (ox + w*0.08, oy - h*0.18),
    ]
    
    # Lower sweeping blade ribbon
    lower_blade = [
        (ox - w*0.18, oy + h*0.24), # bottom left apex
        (ox - w*0.02, oy + h*0.28),
        (ox + w*0.18, oy + h*0.22),
        (ox + w*0.24, oy + h*0.08),
        (ox + w*0.14, oy - h*0.04),
        (ox - w*0.14, oy - h*0.02),
        (ox - w*0.20, oy + h*0.06),
        (ox - w*0.08, oy + h*0.18),
    ]
    
    # Generate smooth ribbon strokes with gradient interpolation
    # Blade 1: Upper Stylux Ribbon
    for i in range(120):
        t = i / 120.0
        # Parametric curve for upper S loop
        angle = -math.pi * 0.2 + t * math.pi * 1.25
        rad_x = w * 0.20 * (1.0 - t * 0.25)
        rad_y = h * 0.16 * (1.0 - t * 0.2)
        px = ox + math.cos(angle) * rad_x - (w * 0.04 * t)
        py = oy - h * 0.12 + math.sin(angle) * rad_y
        
        # Color transition from Electric Indigo (99, 102, 241) to Vivid Violet (168, 85, 247)
        cr = int(99 + (168 - 99) * t)
        cg = int(102 + (85 - 102) * t)
        cb = int(241 + (247 - 241) * t)
        
        thickness = int((w * 0.062) * (1.0 - 0.45 * (t - 0.5)**2))
        edraw.ellipse([px - thickness, py - thickness, px + thickness, py + thickness], fill=(cr, cg, cb, 255))

    # Blade 2: Lower Stylux Ribbon
    for i in range(120):
        t = i / 120.0
        # Parametric curve for lower S loop
        angle = math.pi * 0.8 + t * math.pi * 1.25
        rad_x = w * 0.20 * (1.0 - t * 0.25)
        rad_y = h * 0.16 * (1.0 - t * 0.2)
        px = ox + math.cos(angle) * rad_x + (w * 0.04 * t)
        py = oy + h * 0.12 + math.sin(angle) * rad_y
        
        # Color transition from Vivid Violet (168, 85, 247) to Refined Indigo (79, 70, 229)
        cr = int(168 + (79 - 168) * t)
        cg = int(85 + (70 - 85) * t)
        cb = int(247 + (229 - 247) * t)
        
        thickness = int((w * 0.062) * (1.0 - 0.45 * (t - 0.5)**2))
        edraw.ellipse([px - thickness, py - thickness, px + thickness, py + thickness], fill=(cr, cg, cb, 255))
        
    # Central Precision Interlock (Styling Shear Pivot Accent)
    # Draw central sleek diagonal connector
    for i in range(80):
        t = i / 80.0
        px = (ox - w * 0.10) + t * (w * 0.20)
        py = (oy + h * 0.06) - t * (h * 0.12)
        cr = int(147 + (192 - 147) * t)
        cg = int(112 + (132 - 112) * t)
        cb = int(250 + (252 - 250) * t)
        th = int(w * 0.048 * (1.0 - 0.3 * (t - 0.5)**2))
        edraw.ellipse([px - th, py - th, px + th, py + th], fill=(cr, cg, cb, 255))

    # Luxury Diamond Star Gleam (Top Right of Logo)
    gx, gy = ox + w * 0.22, oy - h * 0.22
    star_size = int(w * 0.05)
    for st in range(star_size, 0, -2):
        s_alpha = int(255 * (1.0 - (st / star_size) ** 1.5))
        edraw.ellipse([gx - st, gy - st*0.3, gx + st, gy + st*0.3], fill=(255, 255, 255, s_alpha))
        edraw.ellipse([gx - st*0.3, gy - st, gx + st*0.3, gy + st], fill=(255, 255, 255, s_alpha))
    edraw.ellipse([gx - 4*scale, gy - 4*scale, gx + 4*scale, gy + 4*scale], fill=(255, 255, 255, 255))

    img = Image.alpha_composite(img, emblem_layer)
    
    # Downsample with high quality Lanczos
    final_icon = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_icon

def create_stylux_transparent_mark(size=512):
    """Creates transparent background Stylux vector mark for widgets and splash screens."""
    scale = 2
    w, h = size * scale, size * scale
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    edraw = ImageDraw.Draw(img)
    ox, oy = w * 0.5, h * 0.5
    
    # Upper S Loop
    for i in range(120):
        t = i / 120.0
        angle = -math.pi * 0.2 + t * math.pi * 1.25
        rad_x = w * 0.26 * (1.0 - t * 0.25)
        rad_y = h * 0.21 * (1.0 - t * 0.2)
        px = ox + math.cos(angle) * rad_x - (w * 0.05 * t)
        py = oy - h * 0.15 + math.sin(angle) * rad_y
        cr = int(99 + (168 - 99) * t)
        cg = int(102 + (85 - 102) * t)
        cb = int(241 + (247 - 241) * t)
        thickness = int((w * 0.075) * (1.0 - 0.45 * (t - 0.5)**2))
        edraw.ellipse([px - thickness, py - thickness, px + thickness, py + thickness], fill=(cr, cg, cb, 255))

    # Lower S Loop
    for i in range(120):
        t = i / 120.0
        angle = math.pi * 0.8 + t * math.pi * 1.25
        rad_x = w * 0.26 * (1.0 - t * 0.25)
        rad_y = h * 0.21 * (1.0 - t * 0.2)
        px = ox + math.cos(angle) * rad_x + (w * 0.05 * t)
        py = oy + h * 0.15 + math.sin(angle) * rad_y
        cr = int(168 + (79 - 168) * t)
        cg = int(85 + (70 - 85) * t)
        cb = int(247 + (229 - 247) * t)
        thickness = int((w * 0.075) * (1.0 - 0.45 * (t - 0.5)**2))
        edraw.ellipse([px - thickness, py - thickness, px + thickness, py + thickness], fill=(cr, cg, cb, 255))
        
    # Center Connector
    for i in range(80):
        t = i / 80.0
        px = (ox - w * 0.13) + t * (w * 0.26)
        py = (oy + h * 0.08) - t * (h * 0.16)
        cr = int(147 + (192 - 147) * t)
        cg = int(112 + (132 - 112) * t)
        cb = int(250 + (252 - 250) * t)
        th = int(w * 0.06 * (1.0 - 0.3 * (t - 0.5)**2))
        edraw.ellipse([px - th, py - th, px + th, py + th], fill=(cr, cg, cb, 255))

    # Sparkle
    gx, gy = ox + w * 0.28, oy - h * 0.28
    star_size = int(w * 0.06)
    for st in range(star_size, 0, -2):
        s_alpha = int(255 * (1.0 - (st / star_size) ** 1.5))
        edraw.ellipse([gx - st, gy - st*0.3, gx + st, gy + st*0.3], fill=(255, 255, 255, s_alpha))
        edraw.ellipse([gx - st*0.3, gy - st, gx + st*0.3, gy + st], fill=(255, 255, 255, s_alpha))
    edraw.ellipse([gx - 4*scale, gy - 4*scale, gx + 4*scale, gy + 4*scale], fill=(255, 255, 255, 255))

    return img.resize((size, size), Image.Resampling.LANCZOS)

# Generate and save all assets
print("Generating Stylux master assets...")
icon_1024 = create_stylux_icon(1024)
mark_512 = create_stylux_transparent_mark(512)

# Save to mobile assets
icon_1024.save(os.path.join(assets_img_dir, "stylux_icon.png"), "PNG")
mark_512.save(os.path.join(assets_img_dir, "stylux_mark.png"), "PNG")

# Also save trimly_icon.png / trimly_logo.png as backup aliases so existing references don't break
icon_1024.save(os.path.join(assets_img_dir, "trimly_icon.png"), "PNG")
mark_512.save(os.path.join(assets_img_dir, "trimly_logo.png"), "PNG")

# Web icons and favicon
fav = icon_1024.resize((64, 64), Image.Resampling.LANCZOS)
fav.save(web_favicon, "PNG")

icon_192 = icon_1024.resize((192, 192), Image.Resampling.LANCZOS)
icon_192.save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
icon_192.save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")

icon_512 = icon_1024.resize((512, 512), Image.Resampling.LANCZOS)
icon_512.save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
icon_512.save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")

# Android mipmaps
android_res = os.path.join(mobile_dir, "android", "app", "src", "main", "res")
mipmaps = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}
for folder, size in mipmaps.items():
    target_folder = os.path.join(android_res, folder)
    if os.path.exists(target_folder):
        resized = icon_1024.resize(size, Image.Resampling.LANCZOS)
        resized.save(os.path.join(target_folder, "ic_launcher.png"), "PNG")

print("Stylux brand assets created successfully!")
