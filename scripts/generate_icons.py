"""Generate platform app icons from the root icon.png.

Usage: python scripts/generate_icons.py

Outputs:
  - android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
  - windows/runner/resources/app_icon.ico (multi-size, also used by the Inno Setup installer)
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "icon.png"

ANDROID_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def main() -> None:
    img = Image.open(SRC).convert("RGBA")

    for dpi, size in ANDROID_SIZES.items():
        out = (
            ROOT / "android" / "app" / "src" / "main" / "res"
            / f"mipmap-{dpi}" / "ic_launcher.png"
        )
        out.parent.mkdir(parents=True, exist_ok=True)
        img.resize((size, size), Image.LANCZOS).save(out, "PNG")
        print(f"android {dpi}: {size}x{size} -> {out.relative_to(ROOT)}")

    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(ico_path, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
    print(f"windows ico: sizes={ICO_SIZES} -> {ico_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

