import os
from PIL import Image, ImageDraw, ImageOps

# Source paths
brain_dir = os.path.expanduser(r"~\.gemini\antigravity-ide\brain\ce198549-9c1c-4eeb-b3b9-9f78331ebc9b")
icon_src = os.path.join(brain_dir, "trimly_app_icon_1789744235053.jpg")
logo_src = os.path.join(brain_dir, "trimly_logo_master_1789744218385.jpg")

mobile_dir = r"d:\Cuts-Salon\mobile"
web_icons_dir = os.path.join(mobile_dir, "web", "icons")
web_favicon = os.path.join(mobile_dir, "web", "favicon.png")
assets_img_dir = os.path.join(mobile_dir, "assets", "images")
os.makedirs(web_icons_dir, exist_ok=True)
os.makedirs(assets_img_dir, exist_ok=True)

# Load base image
if os.path.exists(icon_src):
    base_img = Image.open(icon_src).convert("RGBA")
else:
    print(f"File not found: {icon_src}")
    # Fallback to creating a vector-like gradient square if needed
    base_img = Image.new("RGBA", (1024, 1024), (15, 23, 42, 255))

# Generate assets
# 1. Favicon (64x64)
fav = base_img.resize((64, 64), Image.Resampling.LANCZOS)
fav.save(web_favicon, "PNG")
print("Saved favicon:", web_favicon)

# 2. Web icons
icon_192 = base_img.resize((192, 192), Image.Resampling.LANCZOS)
icon_192.save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
icon_192.save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")

icon_512 = base_img.resize((512, 512), Image.Resampling.LANCZOS)
icon_512.save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
icon_512.save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")
print("Saved web icons in:", web_icons_dir)

# 3. Flutter assets
base_img.save(os.path.join(assets_img_dir, "trimly_icon.png"), "PNG")
if os.path.exists(logo_src):
    logo_img = Image.open(logo_src).convert("RGBA")
    logo_img.save(os.path.join(assets_img_dir, "trimly_logo.png"), "PNG")
print("Saved Flutter assets in:", assets_img_dir)

# 4. Android Mipmaps
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
    os.makedirs(target_folder, exist_ok=True)
    resized = base_img.resize(size, Image.Resampling.LANCZOS)
    resized.save(os.path.join(target_folder, "ic_launcher.png"), "PNG")
    print(f"Saved Android launcher {size} to {folder}")

print("All icon & logo assets created successfully!")
