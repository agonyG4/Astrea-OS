#!/usr/bin/env python3

import sys
from pathlib import Path
from PIL import Image, ImageFilter

def blur_wallpaper(input_path: str, output_path: str, radius: int = 20):
    input_file = Path(input_path)

    if not input_file.exists():
        print(f"Erro: arquivo '{input_path}' não encontrado")
        sys.exit(1)

    print(f"Carregando {input_file.name}...")
    img = Image.open(input_file)

    print(f"Aplicando blur (radius={radius})...")
    blurred = img.filter(ImageFilter.GaussianBlur(radius=radius))

    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)
    blurred.save(output_file, quality=95)

    print(f"Salvo em {output_file}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python blur.py <input> <output> [radius]")
        print("Exemplo: python blur.py wallpaper.png blurred.png 20")
        sys.exit(1)

    input_path  = sys.argv[1]
    output_path = sys.argv[2]
    radius      = int(sys.argv[3]) if len(sys.argv) > 3 else 20

    blur_wallpaper(input_path, output_path, radius)