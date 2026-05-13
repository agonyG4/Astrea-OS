#!/usr/bin/env python3
"""
Soivern — Linux Music Identifier
Captures system audio via PipeWire and identifies it using Shazam.
Opens the result directly in Spotify.

Requirements:
    pip install shazamio
    pacman -S pipewire libnotify
"""

import asyncio
import logging
import os
import subprocess
import tempfile
from typing import Dict, Optional
from urllib.parse import quote_plus

from shazamio import Shazam

# ── Configuration ──────────────────────────────────────────────────────────────
RECORD_DURATION_SECS = 5
APP_NAME              = "Soivern"
LOG_FORMAT            = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT       = "%H:%M:%S"

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT, datefmt=LOG_DATE_FORMAT)
logger = logging.getLogger(__name__)


# ── Audio ──────────────────────────────────────────────────────────────────────

def find_audio_monitor() -> str:
    """
    Detects the active PipeWire monitor source via pactl.
    Returns the source name, or 'auto' as fallback.
    """
    try:
        result = subprocess.run(
            ["pactl", "list", "sources", "short"],
            capture_output=True, text=True, check=True
        )
        for line in result.stdout.splitlines():
            if "monitor" in line and "RUNNING" in line:
                source = line.split()[1]
                logger.info(f"Monitor source detected: {source}")
                return source
    except Exception as e:
        logger.warning(f"Could not query pactl sources: {e}")

    logger.warning("No active monitor found, falling back to 'auto'")
    return "auto"


def record_audio() -> str:
    """
    Captures system audio via pw-record for RECORD_DURATION_SECS seconds.
    Returns the path to a temporary WAV file.
    """
    target = find_audio_monitor()

    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)

    logger.info(f"Recording {RECORD_DURATION_SECS}s of audio...")
    notify("Identifying...", f"Capturing {RECORD_DURATION_SECS}s of audio...")

    proc = subprocess.Popen([
        "pw-record",
        "--target", target,
        "--channels", "2",
        "--format", "s16",
        path
    ])

    try:
        proc.wait(timeout=RECORD_DURATION_SECS)
    except subprocess.TimeoutExpired:
        proc.terminate()
        proc.wait()

    return path


# ── Shazam ─────────────────────────────────────────────────────────────────────

async def _recognize(audio_path: str) -> Optional[Dict]:
    try:
        return await Shazam().recognize(audio_path)
    except Exception as e:
        logger.error(f"Shazam request failed: {e}")
        return None


def identify_song(audio_path: str) -> Optional[Dict]:
    """Sends the audio file to Shazam and returns the raw result."""
    return asyncio.run(_recognize(audio_path))


def parse_result(data: Optional[Dict]) -> Optional[Dict]:
    """
    Extracts title, artist, and Spotify search URL from a Shazam result.
    Returns None if no track was found.
    """
    if not data or "track" not in data:
        return None

    track  = data["track"]
    title  = track.get("title",    "Unknown Title")
    artist = track.get("subtitle", "Unknown Artist")
    query  = quote_plus(f"{title} {artist}")

    return {
        "title":       title,
        "artist":      artist,
        "spotify_url": f"spotify:search:{query}",
    }


# ── Spotify ────────────────────────────────────────────────────────────────────

def open_spotify(url: str) -> None:
    """Opens Spotify at the given URI through Astrea's launch wrapper."""
    logger.info(f"Opening Spotify: {url}")
    astrea_root = os.environ.get("ASTREA_ROOT") or os.path.expanduser("~/.local/share/Astrea")
    launcher = os.path.join(astrea_root, "bin", "astrea-launch")
    command = [launcher, "--url", url] if os.path.isfile(launcher) else ["xdg-open", url]
    subprocess.run(command, check=False)


# ── Notifications ──────────────────────────────────────────────────────────────

def notify(title: str, message: str, urgency: str = "normal") -> None:
    """Sends a desktop notification via notify-send."""
    try:
        subprocess.run(
            ["notify-send", "-a", APP_NAME, "-u", urgency, title, message],
            check=False
        )
    except Exception as e:
        logger.warning(f"notify-send failed: {e}")


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    audio_path: Optional[str] = None
    try:
        audio_path = record_audio()
        result     = identify_song(audio_path)

        if result is None:
            notify("Error", "Could not reach Shazam.", urgency="critical")
            return

        info = parse_result(result)
        if info:
            label = f"{info['title']} — {info['artist']}"
            logger.info(f"Match found: {label}")
            open_spotify(info["spotify_url"])
            notify("Match found!", label)
        else:
            notify("No match", "No song detected. Is audio playing?")
            logger.info("Shazam returned no match.")

    except Exception as e:
        notify("Fatal error", str(e)[:120], urgency="critical")
        logger.exception("Unhandled exception during identification")
    finally:
        if audio_path and os.path.exists(audio_path):
            try:
                os.unlink(audio_path)
            except OSError as e:
                logger.warning(f"Failed to remove temp file: {e}")


if __name__ == "__main__":
    main()
