#!/usr/bin/env python3
"""
blur_lockscreen.py — Astrea lockscreen blur generator
Lê:   ~/.local/share/Astrea/System/Lockscreen/Wallpaper/wallpaper.jpg
Gera: ~/.local/share/Astrea/System/Lockscreen/Wallpaper/blurred.jpg
"""
from pathlib import Path
from PIL import Image, ImageFilter

LOCKSCREEN_DIR = Path.home() / ".local/share/Astrea/System/Paper/LockscreenWallpaper"
INPUT          = LOCKSCREEN_DIR / "wallpaper.jpg"
OUTPUT         = LOCKSCREEN_DIR / "blurred.jpg"
RADIUS         = 20

def main():
    if not INPUT.exists():
        print(f"Erro: '{INPUT}' não encontrado")
        raise SystemExit(1)

    LOCKSCREEN_DIR.mkdir(parents=True, exist_ok=True)

    with Image.open(INPUT) as img:
        blurred = img.convert("RGB").filter(ImageFilter.GaussianBlur(radius=RADIUS))
        blurred.save(OUTPUT, "JPEG", quality=92, optimize=True)

    print(f"blurred.jpg gerado → {OUTPUT}")

if __name__ == "__main__":
    main()