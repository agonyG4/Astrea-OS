#!/usr/bin/env python3
"""
blur_lockscreen.py — Astrea lockscreen blur generator
Gera o blur no mesmo diretório do arquivo original e cria um symlink (aponta para ele)
"""
import argparse
import os
import sys
import tempfile
from pathlib import Path
from PIL import Image, ImageFilter

RADIUS = 20


def generate_blur(input_path: Path, output_path: Path | None = None) -> Path:
    if not input_path.exists():
        raise FileNotFoundError(f"'{input_path}' não encontrado")

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)

    real_input = input_path.resolve()
    real_output_dir = real_input.parent
    blurred_file = real_output_dir / "blurred.jpg"

    if not blurred_file.exists() or real_input.stat().st_mtime > blurred_file.stat().st_mtime:
        fd, tmp_name = tempfile.mkstemp(prefix=f".{blurred_file.name}.", suffix=".tmp", dir=str(real_output_dir))
        os.close(fd)
        tmp = Path(tmp_name)
        try:
            with Image.open(real_input) as img:
                blurred = img.convert("RGB").filter(ImageFilter.GaussianBlur(radius=RADIUS))
                blurred.save(tmp, "JPEG", quality=92, optimize=True)
            os.replace(tmp, blurred_file)
        finally:
            try:
                tmp.unlink()
            except FileNotFoundError:
                pass

    if output_path:
        if output_path.exists() or output_path.is_symlink():
            output_path.unlink()
        output_path.symlink_to(blurred_file)

    return blurred_file

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Input wallpaper path (could be a symlink)")
    parser.add_argument("--output", required=False, help="Output blurred wallpaper symlink path")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output) if args.output else None

    try:
        blurred_file = generate_blur(input_path, output_path)
    except Exception as e:
        print(f"Erro ao gerar blur: {e}")
        sys.exit(1)

    print(f"blurred.jpg gerado -> {blurred_file}")
    if output_path:
        print(f"Apontando {output_path} -> {blurred_file}")

if __name__ == "__main__":
    main()
