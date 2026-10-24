"""Renders every sound effect and music track into assets/audio/.

Usage:  python3 tools/audio/generate.py [--sfx-only | --music-only] [name ...]
Requires numpy and ffmpeg (with libvorbis) on PATH.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import music  # noqa: E402
import sfx  # noqa: E402
from synth import write_ogg  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"


def main(argv: list[str]) -> None:
    only = [a for a in argv if not a.startswith("--")]
    if "--music-only" not in argv:
        for name, fn in sfx.ALL.items():
            if only and name not in only:
                continue
            t = time.time()
            write_ogg(SFX_DIR / f"{name}.ogg", fn(), quality=4)
            print(f"sfx   {name:18s} {time.time() - t:5.2f}s")
    if "--sfx-only" not in argv:
        for name, fn in music.TRACKS.items():
            if only and name not in only:
                continue
            t = time.time()
            write_ogg(MUSIC_DIR / f"{name}.ogg", fn(), quality=4)
            print(f"music {name:18s} {time.time() - t:5.2f}s")


if __name__ == "__main__":
    main(sys.argv[1:])
