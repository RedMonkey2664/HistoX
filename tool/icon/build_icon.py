"""Write every app icon size from the brand mark.

    python tool/icon/build_icon.py

Source is `assets/brand/icon_master.png`, a 1024x1024 render of the HistoX
mark: the green arrow on the navy ground. It is the supplied artwork,
`assets/brand/logo_source.png` (547x525), centre-cropped square and scaled
up. Nothing is recoloured, recentred or composited: the artwork already
carries its own ground and needs no help. The original is kept beside the
master so both can be rebuilt if the mark is ever redrawn.

The icon used to be Flutter's own logo, which is third-party branding and
grounds for rejection at App Store review besides.

Outputs carry no alpha channel, which App Store Connect requires of the 1024
and which costs nothing on the rest. Rerunning overwrites every icon in the
repository, so this is a deliberate command, not part of the build.

Needs Pillow.
"""

import os

from PIL import Image

MASTER = "assets/brand/icon_master.png"
GROUND = (0x0D, 0x14, 0x22)  # The master's darkest navy, for maskable bleed.

IOS_DIR = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_SIZES = {
    "Icon-App-20x20@1x": 20, "Icon-App-20x20@2x": 40, "Icon-App-20x20@3x": 60,
    "Icon-App-29x29@1x": 29, "Icon-App-29x29@2x": 58, "Icon-App-29x29@3x": 87,
    "Icon-App-40x40@1x": 40, "Icon-App-40x40@2x": 80, "Icon-App-40x40@3x": 120,
    "Icon-App-60x60@2x": 120, "Icon-App-60x60@3x": 180,
    "Icon-App-76x76@1x": 76, "Icon-App-76x76@2x": 152,
    "Icon-App-83.5x83.5@2x": 167,
    "Icon-App-1024x1024@1x": 1024,
}
ANDROID_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144,
                 "xxxhdpi": 192}


def emit(master: Image.Image, path: str, size: int,
         maskable: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if maskable:
        # A maskable icon may be cropped to a circle of 80% of its width, so
        # the mark sits inside that and the ground colour fills the bleed.
        img = Image.new("RGB", (size, size), GROUND)
        inner = int(size * 0.78)
        off = (size - inner) // 2
        img.paste(master.resize((inner, inner), Image.LANCZOS), (off, off))
    else:
        img = master.resize((size, size), Image.LANCZOS)
    img.save(path, "PNG", optimize=True)


def main() -> None:
    master = Image.open(MASTER).convert("RGB")
    if master.size != (1024, 1024):
        raise SystemExit(f"{MASTER} must be 1024x1024, got {master.size}")

    for name, size in IOS_SIZES.items():
        emit(master, f"{IOS_DIR}/{name}.png", size)
    for density, size in ANDROID_SIZES.items():
        emit(master,
             f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
             size)

    emit(master, "web/icons/Icon-192.png", 192)
    emit(master, "web/icons/Icon-512.png", 512)
    emit(master, "web/icons/Icon-maskable-192.png", 192, maskable=True)
    emit(master, "web/icons/Icon-maskable-512.png", 512, maskable=True)
    emit(master, "web/favicon.png", 32)
    emit(master, "docs/submission/app_icon_1024.png", 1024)

    # web_dist/ is a committed build artefact (see tool/publish_web.sh), so
    # the deployed preview would otherwise keep the old favicon until the
    # next full rebuild.
    for src, dst in [
        ("web/icons/Icon-192.png", "web_dist/icons/Icon-192.png"),
        ("web/icons/Icon-512.png", "web_dist/icons/Icon-512.png"),
        ("web/icons/Icon-maskable-192.png",
         "web_dist/icons/Icon-maskable-192.png"),
        ("web/icons/Icon-maskable-512.png",
         "web_dist/icons/Icon-maskable-512.png"),
        ("web/favicon.png", "web_dist/favicon.png"),
    ]:
        if os.path.isdir(os.path.dirname(dst)):
            Image.open(src).save(dst, "PNG", optimize=True)

    print(f"wrote {len(IOS_SIZES) + len(ANDROID_SIZES) + 6} icons from {MASTER}")


if __name__ == "__main__":
    main()
