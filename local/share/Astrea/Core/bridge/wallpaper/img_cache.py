#!/usr/bin/env python3
"""
Astrea Orchestrator — O motor de miniaturas do Vitor.
"""
import argparse
import sys
from pathlib import Path
from PIL import Image

# ── Configurações de Qualidade Estilo Apple ───────────────────────────────────
THUMB_SIZE = (900, 500)
THUMB_QUALITY = 85
PROJECT_DIR = Path.home() / ".local/share/Astrea"
USER_DATA_DIR = PROJECT_DIR / "Data/user"
USER_CONFIG_DIR = Path.home() / ".config/AstreaOS/user"
USER_WP_DIR = USER_DATA_DIR / "wallpapers"
LOCKSCREEN_WP_DIR = USER_CONFIG_DIR / "paper/lockscreen"
WP_THUMB_SRC = USER_CONFIG_DIR / "paper/wallpaper/wallpaper.jpg"
WP_THUMB_DEST = USER_CONFIG_DIR / "paper/wallpaper/wallpaper_thumb.jpg"
LOCKSCREEN_THUMB_SRC = LOCKSCREEN_WP_DIR / "wallpaper.jpg"
LOCKSCREEN_THUMB_DEST = LOCKSCREEN_WP_DIR / "wallpaper_thumb.jpg"


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
            print(f"  [ERR] não encontrado: {src}", file=sys.stderr)
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(src) as img:
            thumb = _crop_center(img.convert("RGB"), THUMB_SIZE)
            thumb.save(dest, "JPEG", quality=THUMB_QUALITY, optimize=True)
        return True
    except Exception as e:
        print(f"  [ERR] {src.name}: {e}", file=sys.stderr)
        return False


def scan_and_cache():
    """Gera/atualiza o thumb.jpg dentro de cada pasta de slug."""
    if not USER_WP_DIR.exists():
        return
    for wp_folder in USER_WP_DIR.iterdir():
        if wp_folder.is_dir():
            src  = wp_folder / "wallpaper.jpg"
            dest = wp_folder / "thumb.jpg"
            if src.exists() and (not dest.exists() or src.stat().st_mtime > dest.stat().st_mtime):
                process_image(src, dest)


def only_wallpaper():
    """Regenera apenas o thumb do wallpaper atual (chamado pelo QML após troca)."""
    process_image(WP_THUMB_SRC, WP_THUMB_DEST)


def only_lockscreen():
    """Regenera apenas o thumb do wallpaper atual da lockscreen."""
    process_image(LOCKSCREEN_THUMB_SRC, LOCKSCREEN_THUMB_DEST)


def main():
    parser = argparse.ArgumentParser(description="Astrea Image Orchestrator")
    parser.add_argument("--src",            help="Caminho da imagem original")
    parser.add_argument("--dest",           help="Caminho do thumbnail de saída")
    parser.add_argument("--scan",           action="store_true", help="Sincroniza toda a biblioteca de usuário")
    parser.add_argument("--only-wallpaper", action="store_true", help="Regenera apenas o thumb do wallpaper atual")
    parser.add_argument("--only-lockscreen", action="store_true", help="Regenera apenas o thumb atual da lockscreen")
    parser.add_argument("--slug",           help="Gera o thumb para um slug específico em UserWallpapers")
    parser.add_argument("--lockscreen-slug", help="Gera o thumb atual da lockscreen a partir de um slug da biblioteca")
    args = parser.parse_args()

    if args.only_wallpaper:
        only_wallpaper()
    elif args.only_lockscreen:
        only_lockscreen()
    elif args.scan:
        scan_and_cache()
    elif args.slug:
        folder = USER_WP_DIR / args.slug
        process_image(folder / "wallpaper.jpg", folder / "thumb.jpg")
    elif args.lockscreen_slug:
        folder = USER_WP_DIR / args.lockscreen_slug
        process_image(folder / "wallpaper.jpg", folder / "thumb.jpg")
    elif args.src and args.dest:
        process_image(Path(args.src).expanduser(), Path(args.dest).expanduser())
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
