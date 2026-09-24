#!/usr/bin/env python3
"""Generate every app icon from one glyph (conventions/icons.md).

    python3 tool/icon/generate_icons.py            # from assets/icon/source_glyph.png
    python3 tool/icon/generate_icons.py path/to/glyph.png

From jejezz/application-release-templates common/ @ conventions-v1 — merges
allwinner-phoenix's macOS/Windows/Linux scripts with saturn-mobile's
iOS/Android one. Needs Pillow (`pip3 install pillow`).

The glyph is transparent artwork (e.g. an Icons8 download, 512px or larger).
Every icon puts it on the same plate — a vertical gradient #1F2A38 → #0A0E14 —
so all apps read as one family in the Dock, taskbar and home screen. The
glyph's colour tells apps apart; the plate never changes.

Writes, for each platform folder that exists:

  assets/icon/app_icon_1024.png   master (macOS-shaped), for docs and stores
  assets/icon/app_icon.png        256px copy used inside the app (About dialog)
  macOS    AppIcon.appiconset     Apple icon grid: 824px rounded plate
                                  (radius 185) in a 1024 canvas, glyph 600px
  Windows  app_icon.ico           full-bleed plate (12% radius), glyph 92% —
                                  a macOS-sized glyph reads as too small in
                                  the taskbar, and the dark plate all but
                                  disappears against a dark taskbar
  Linux    app_icon.png 512px     same as Windows
  iOS      AppIcon.appiconset     square plate, glyph 76%, NO alpha channel
                                  (App Store Connect rejects one)
  Android  legacy mipmaps + adaptive icon (gradient background layer, glyph
           foreground inside the 66/108 safe zone)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ICON_DIR = ROOT / 'assets/icon'

PLATE_TOP = (0x1F, 0x2A, 0x38)
PLATE_BOTTOM = (0x0A, 0x0E, 0x14)

MASTER = 1024

# macOS: Apple's icon grid.
MAC_PLATE = 824
MAC_RADIUS = 185
MAC_GLYPH = 600

# Windows / Linux: nearly edge to edge.
DESKTOP_RADIUS_FRACTION = 0.12
DESKTOP_GLYPH_FRACTION = 0.92

# iOS / Android legacy: the OS applies its own mask to a square plate.
MOBILE_GLYPH_FRACTION = 0.76
# Android adaptive: only the inner 66dp of 108dp is guaranteed visible.
# 0.54 keeps a round-ish glyph whole inside that circle; lower it for
# artwork whose corners stick out further.
ADAPTIVE_GLYPH_FRACTION = 0.54

ANDROID_LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ANDROID_ADAPTIVE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}


def gradient(size: int) -> Image.Image:
    column = Image.new('RGB', (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        column.putpixel((0, y), tuple(
            round(PLATE_TOP[c] + (PLATE_BOTTOM[c] - PLATE_TOP[c]) * t) for c in range(3)))
    return column.resize((size, size))


def rounded_plate(size: int, radius: int) -> Image.Image:
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    plate = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    plate.paste(gradient(size), (0, 0), mask)
    return plate


def fit(glyph: Image.Image, box: int) -> Image.Image:
    """Crop the glyph to its opaque pixels and scale its longest side to `box`."""
    art = glyph.crop(glyph.getbbox())
    scale = box / max(art.size)
    return art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))),
                      Image.LANCZOS)


def centre(canvas: Image.Image, art: Image.Image) -> Image.Image:
    canvas.alpha_composite(art, ((canvas.width - art.width) // 2,
                                 (canvas.height - art.height) // 2))
    return canvas


def macos_icon(glyph: Image.Image) -> Image.Image:
    plate = centre(rounded_plate(MAC_PLATE, MAC_RADIUS), fit(glyph, MAC_GLYPH))
    return centre(Image.new('RGBA', (MASTER, MASTER), (0, 0, 0, 0)), plate)


def desktop_icon(glyph: Image.Image) -> Image.Image:
    plate = rounded_plate(MASTER, round(MASTER * DESKTOP_RADIUS_FRACTION))
    return centre(plate, fit(glyph, round(MASTER * DESKTOP_GLYPH_FRACTION)))


def mobile_icon(glyph: Image.Image) -> Image.Image:
    plate = gradient(MASTER).convert('RGBA')
    return centre(plate, fit(glyph, round(MASTER * MOBILE_GLYPH_FRACTION)))


def write_macos(icon: Image.Image) -> None:
    out = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    if not out.parent.parent.exists():
        return
    out.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        icon.resize((size, size), Image.LANCZOS).save(out / f'app_icon_{size}.png')
    print(f'macOS    {out.relative_to(ROOT)}/app_icon_{{16..1024}}.png')


def write_windows(icon: Image.Image) -> None:
    out = ROOT / 'windows/runner/resources/app_icon.ico'
    if not out.parent.exists():
        return
    sizes = [256, 128, 64, 48, 32, 16]
    icon.save(out, format='ICO', sizes=[(s, s) for s in sizes])
    print(f'Windows  {out.relative_to(ROOT)} ({"/".join(map(str, sizes))})')


def write_linux(icon: Image.Image) -> None:
    runner = ROOT / 'linux/runner'
    if not runner.exists():
        return
    out = runner / 'resources/app_icon.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(out)
    print(f'Linux    {out.relative_to(ROOT)} (512)')


def write_ios(icon: Image.Image) -> None:
    out = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    contents = out / 'Contents.json'
    if not contents.exists():
        return
    flat = icon.convert('RGB')  # no alpha channel
    written = 0
    for image in json.loads(contents.read_text())['images']:
        name = image.get('filename')
        if not name:
            continue
        points = float(image['size'].split('x')[0])
        pixels = round(points * int(image['scale'].rstrip('x')))
        flat.resize((pixels, pixels), Image.LANCZOS).save(out / name)
        written += 1
    print(f'iOS      {out.relative_to(ROOT)} ({written} files, no alpha)')


def write_android(icon: Image.Image, glyph: Image.Image) -> None:
    res = ROOT / 'android/app/src/main/res'
    if not res.exists():
        return
    for density, size in ANDROID_LEGACY.items():
        (res / f'mipmap-{density}').mkdir(exist_ok=True)
        icon.resize((size, size), Image.LANCZOS).save(res / f'mipmap-{density}/ic_launcher.png')

    for density, size in ANDROID_ADAPTIVE.items():
        foreground = centre(Image.new('RGBA', (size, size), (0, 0, 0, 0)),
                            fit(glyph, round(size * ADAPTIVE_GLYPH_FRACTION)))
        foreground.save(res / f'mipmap-{density}/ic_launcher_foreground.png')
        gradient(size).save(res / f'mipmap-{density}/ic_launcher_background.png')

    anydpi = res / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Generated by tool/icon/generate_icons.py. -->\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding='utf-8')
    print(f'Android  {res.relative_to(ROOT)}/mipmap-* (legacy + adaptive)')


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else ICON_DIR / 'source_glyph.png'
    if not source.exists():
        raise SystemExit(f'source glyph not found: {source}')
    glyph = Image.open(source).convert('RGBA')
    if glyph.getbbox() is None:
        raise SystemExit(f'source glyph is fully transparent: {source}')

    mac = macos_icon(glyph)
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    mac.save(ICON_DIR / 'app_icon_1024.png')
    mac.resize((256, 256), Image.LANCZOS).save(ICON_DIR / 'app_icon.png')
    print(f'master   {(ICON_DIR / "app_icon_1024.png").relative_to(ROOT)}, app_icon.png (256)')

    write_macos(mac)
    desktop = desktop_icon(glyph)
    write_windows(desktop)
    write_linux(desktop)
    mobile = mobile_icon(glyph)
    write_ios(mobile)
    write_android(mobile, glyph)


if __name__ == '__main__':
    main()
