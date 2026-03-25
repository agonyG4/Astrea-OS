#!/usr/bin/env python3
"""
Astrea Orchestrator — O motor de miniaturas do Vitor.
"""
import argparse
from pathlib import Path
from PIL import Image

# ── Configurações de Qualidade Estilo Apple ───────────────────────────────────
THUMB_SIZE    = (900, 500)
THUMB_QUALITY = 85
USER_WP_DIR   = Path.home() / ".local/share/Astrea/System/Paper/UserWallpapers"
WP_THUMB_SRC  = Path.home() / ".local/share/Astrea/System/Paper/Wallpaper/wallpaper.jpg"
WP_THUMB_DEST = Path.home() / ".local/share/Astrea/System/Paper/Wallpaper/wallpaper_thumb.jpg"


def _crop_center(img: Image.Image, target: tuple) -> Image.Image:
    tw, th = target
    iw, ih = img.size
    scale   = max(tw / iw, th / ih)
    new_w, new_h = round(iw * scale), round(ih * scale)
    resized = img.resize((new_w, new_h), Image.LANCZOS)
    left, top = (new_w - tw) // 2, (new_h - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def process_image(src: Path, dest: Path) -> bool:
    try:
        if not src.exists():
            print(f"  [ERR] não encontrado: {src}")
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(src) as img:
            thumb = _crop_center(img.convert("RGB"), THUMB_SIZE)
            thumb.save(dest, "JPEG", quality=THUMB_QUALITY, optimize=True)
        print(f"  [OK] {dest}")
        return True
    except Exception as e:
        print(f"  [ERR] {src.name}: {e}")
        return False


def scan_and_cache():
    """Gera/atualiza o thumb.jpg dentro de cada pasta de slug."""
    print("Astrea — Sincronizando cache da biblioteca...")
    if not USER_WP_DIR.exists():
        print("  Biblioteca vazia.")
        return
    for wp_folder in USER_WP_DIR.iterdir():
        if wp_folder.is_dir():
            src  = wp_folder / "wallpaper.jpg"
            dest = wp_folder / "thumb.jpg"
            if src.exists() and (not dest.exists() or src.stat().st_mtime > dest.stat().st_mtime):
                process_image(src, dest)


def only_wallpaper():
    """Regenera apenas o thumb do wallpaper atual (chamado pelo QML após troca)."""
    print("Astrea — Atualizando thumb do wallpaper atual...")
    process_image(WP_THUMB_SRC, WP_THUMB_DEST)


def main():
    parser = argparse.ArgumentParser(description="Astrea Image Orchestrator")
    parser.add_argument("--src",            help="Caminho da imagem original")
    parser.add_argument("--dest",           help="Caminho do thumbnail de saída")
    parser.add_argument("--scan",           action="store_true", help="Sincroniza toda a biblioteca de usuário")
    parser.add_argument("--only-wallpaper", action="store_true", help="Regenera apenas o thumb do wallpaper atual")
    parser.add_argument("--slug",           help="Gera o thumb para um slug específico em UserWallpapers")
    args = parser.parse_args()

    if args.only_wallpaper:
        only_wallpaper()
    elif args.scan:
        scan_and_cache()
    elif args.slug:
        folder = USER_WP_DIR / args.slug
        process_image(folder / "wallpaper.jpg", folder / "thumb.jpg")
    elif args.src and args.dest:
        process_image(Path(args.src).expanduser(), Path(args.dest).expanduser())
    else:
        parser.print_help()


if __name__ == "__main__":
    main()