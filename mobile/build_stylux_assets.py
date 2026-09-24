import os
from PIL import Image

brain_dir = r"C:\Users\Amit's Laptop\.gemini\antigravity-ide\brain\ff8984ee-c7a4-41f7-9aca-0d6a0091558f"
mobile_dir = r"d:\Cuts-Salon\mobile"
assets_img_dir = os.path.join(mobile_dir, "assets", "images")
web_icons_dir = os.path.join(mobile_dir, "web", "icons")
web_favicon = os.path.join(mobile_dir, "web", "favicon.png")
android_res = os.path.join(mobile_dir, "android", "app", "src", "main", "res")

os.makedirs(assets_img_dir, exist_ok=True)
os.makedirs(web_icons_dir, exist_ok=True)

logo_dark_src = os.path.join(brain_dir, "stylux_clean_dark_logo_1790235682157.jpg")
logo_light_src = os.path.join(brain_dir, "stylux_clean_logo_white_1790235633143.jpg")
icon_src = os.path.join(brain_dir, "stylux_clean_squircle_icon_1790235701230.jpg")

print(f"Loading clean minimalist assets:")
print(f" - Dark Logo: {logo_dark_src}")
print(f" - Light Logo: {logo_light_src}")
print(f" - Clean App Icon: {icon_src}")

logo_dark_img = Image.open(logo_dark_src).convert("RGBA")
logo_light_img = Image.open(logo_light_src).convert("RGBA")
icon_img = Image.open(icon_src).convert("RGBA")

# Save primary Flutter image assets
logo_dark_img.save(os.path.join(assets_img_dir, "stylux_logo.png"), "PNG")
logo_dark_img.save(os.path.join(assets_img_dir, "stylux_logo_dark.png"), "PNG")
logo_light_img.save(os.path.join(assets_img_dir, "stylux_logo_light.png"), "PNG")
icon_img.save(os.path.join(assets_img_dir, "stylux_icon.png"), "PNG")
icon_img.save(os.path.join(assets_img_dir, "stylux_mark.png"), "PNG")

# Backwards compatibility aliases
logo_dark_img.save(os.path.join(assets_img_dir, "trimly_logo.png"), "PNG")
icon_img.save(os.path.join(assets_img_dir, "trimly_icon.png"), "PNG")

# Web favicon (64x64)
fav = icon_img.resize((64, 64), Image.Resampling.LANCZOS)
fav.save(web_favicon, "PNG")

# Web PWA icons
icon_192 = icon_img.resize((192, 192), Image.Resampling.LANCZOS)
icon_192.save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
icon_192.save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")

icon_512 = icon_img.resize((512, 512), Image.Resampling.LANCZOS)
icon_512.save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
icon_512.save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")

# Android mipmaps
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
        resized = icon_img.resize(size, Image.Resampling.LANCZOS)
        resized.save(os.path.join(target_folder, "ic_launcher.png"), "PNG")

print("Stylux clean minimal assets built successfully!")
