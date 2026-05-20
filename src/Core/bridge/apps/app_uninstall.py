from __future__ import annotations

from pathlib import Path


def is_protected_app(app: dict) -> bool:
    app_id = (app.get("id") or "").casefold()
    desktop_file = (app.get("desktop_file") or "").casefold()
    name = (app.get("name") or "").casefold()
    return (
        app_id == "astrea-settings.desktop"
        or desktop_file.endswith("/astrea-settings.desktop")
        or name in {"astrea settings", "settings"} and app_id.startswith("astrea-settings")
    )


def is_steam_game_app(app: dict) -> bool:
    app_id = (app.get("id") or "").casefold()
    exec_line = (app.get("exec") or "").casefold()
    icon = (app.get("icon") or "").casefold()
    comment = (app.get("comment") or "").casefold()
    if app_id in {"steam.desktop", "steam-console.desktop", "steam_http_loader.desktop"}:
        return False
    return (
        "steam://rungameid/" in exec_line
        or icon.startswith("steam_icon_")
        or "steam_app_" in (app.get("startup_wm_class") or "").casefold()
        or "play this game on steam" in comment
    )


def uninstall_info(app: dict, *, flatpak_id: str, flatpak_installation: str, package_owner: str) -> dict:
    if is_protected_app(app):
        return {
            "can": False,
            "method": "protected",
            "label": "Settings protegido",
            "reason": "Settings é protegido e não pode ser desinstalado.",
        }

    if flatpak_id:
        return {
            "can": True,
            "method": "flatpak",
            "label": "Desinstalar",
            "reason": "Remove o app Flatpak. Dados do app são preservados.",
            "flatpak_id": flatpak_id,
            "installation": flatpak_installation,
        }

    if is_steam_game_app(app):
        return {
            "can": False,
            "method": "steam",
            "label": "Desinstalar pela Steam",
            "reason": "Este jogo deve ser desinstalado na Steam.",
        }

    desktop_file = Path(app.get("desktop_file", "")).expanduser()
    if app.get("source") == "user" and desktop_file.is_file():
        return {
            "can": True,
            "method": "desktop-file",
            "label": "Remover da lista",
            "reason": "Remove apenas este launcher de aplicativos.",
        }

    if package_owner:
        return {
            "can": True,
            "method": "system-package",
            "label": "Desinstalar",
            "reason": f"Remove o pacote Pacman {package_owner}.",
            "package": package_owner,
        }

    return {
        "can": False,
        "method": "system-package",
        "label": "Desinstalar",
        "reason": "Este app é do sistema, mas não foi possível identificar o pacote dono.",
        "package": "",
    }
