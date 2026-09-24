import os
from PIL import Image

brain_dir = os.path.expanduser(r"~\.gemini\antigravity-ide\brain\ff8984ee-c7a4-41f7-9aca-0d6a0091558f")

concepts = [
    "stylux_clean_logo_white_1790235633143.jpg",
    "stylux_clean_dark_logo_1790235682157.jpg",
    "stylux_logo_concept_1_1790235789301.jpg",
    "stylux_logo_concept_2_1790235812824.jpg",
    "stylux_logo_concept_3_1790235837427.jpg",
    "stylux_logo_concept_4_1790235857058.jpg",
    "stylux_logo_concept_5_1790235881134.jpg",
]

for c in concepts:
    p = os.path.join(brain_dir, c)
    if os.path.exists(p):
        im = Image.open(p)
        print(f"{c}: size={im.size}, mode={im.mode}")
    else:
        print(f"{c}: NOT FOUND")
