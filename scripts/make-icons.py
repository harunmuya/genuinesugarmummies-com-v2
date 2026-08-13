"""
Generate the GS Global app icon.

Reproducible on purpose: the icon is a build artefact, not a binary somebody has
to keep safe, so it can be regenerated after a palette change.

Why it was redrawn. V1 (genuinesugarmummies.co.ke) and this app both shipped an
orange and blue "GS" letterform on a white or transparent field. Side by side on
a home screen they were not distinguishable, which is most of what people meant
by the two apps looking the same.

So this shares nothing with V1's icon: dark field instead of white, teal to
indigo instead of orange, and a geometric mark instead of letterforms.

It is also actually maskable, which the old one claimed to be and was not. The
manifest declared purpose "any maskable" on an icon with transparent edges, so
Android composited a rounded mask over empty corners and the logo floated. A
maskable icon needs a full-bleed background and its content inside the middle
80%, which is what the SAFE fraction below enforces.

Drawn at 4x and downsampled, because PIL has no anti-aliased shape drawing.
"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from pathlib import Path

SS = 4                      # supersample factor
SIZE = 512
S = SIZE * SS

BG = (10, 14, 18)           # --color-bg-dark
TEAL = (20, 224, 200)       # --color-primary
INDIGO = (108, 123, 255)    # the far stop of --gradient-primary
SAFE = 0.80                 # maskable safe zone: content stays inside this


def gradient(size, start, end):
    """Diagonal two-stop gradient, top-left to bottom-right."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(start[i] + (end[i] - start[i]) * t) for i in range(3))
    return img


def build():
    # Full-bleed background, so the launcher mask never cuts into nothing.
    base = Image.new("RGB", (S, S), BG)

    # A soft teal light source at the top left, matching --app-bg. Drawn as a
    # blurred disc rather than a real radial gradient, which PIL lacks.
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse(
        [-S * 0.30, -S * 0.34, S * 0.62, S * 0.58], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.13))
    base = Image.composite(Image.new("RGB", (S, S), (16, 52, 58)), base, glow)

    # The mark: two interlocking rings, a connection between two people. Reads
    # at 48px, and shares no shape language with a "GS" letterform.
    #
    # Built from three masks rather than by drawing one over the other. The
    # first attempt cut a notch through both rings at once and produced two
    # facing crescents that read as the letters "CO" — worse than either the
    # intended mark or the icon it replaced.
    #
    #   left   the full left ring
    #   right  the full right ring
    #   halo   a fatter right ring, used only to cut the gap
    #
    # left minus halo, with right laid back on top, so the left ring passes
    # behind the right one and the two genuinely link.
    span = S * SAFE
    r = span * 0.30                 # ring radius
    w = span * 0.115                # stroke weight
    cy = S / 2
    dx = r * 0.62                   # overlap: close enough to interlock
    cx_l, cx_r = S / 2 - dx, S / 2 + dx

    def ring(cx, radius, width):
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            outline=255, width=round(width))
        return m

    left = ring(cx_l, r, w)
    right = ring(cx_r, r, w)
    halo = ring(cx_r, r, w * 2.6)   # the visual gap around the right ring

    mask = ImageChops.lighter(ImageChops.subtract(left, halo), right)

    grad = gradient(S, TEAL, INDIGO)
    icon = Image.composite(grad, base, mask)

    return icon.resize((SIZE, SIZE), Image.LANCZOS)


def mark_only(size, fraction=0.55):
    """
    The rings on transparency, for the Android adaptive foreground.

    An adaptive icon draws the foreground into a 108dp canvas and lets the
    launcher crop it to whatever shape the device uses, so only the middle 66%
    is guaranteed to survive. `fraction` keeps the mark well inside that: the
    old foreground filled its canvas edge to edge and lost the outer ring to
    the crop on any device using a circular mask.
    """
    icon = build()
    inner = round(size * fraction)
    mark = icon.resize((inner, inner), Image.LANCZOS).convert("RGBA")

    # Drop the background, keeping only the coloured mark. The rings are far
    # brighter than the near-black field, so luminance separates them cleanly.
    px = mark.load()
    for y in range(inner):
        for x in range(inner):
            r, g, b, _ = px[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            px[x, y] = (r, g, b, 0 if lum < 40 else min(255, (lum - 40) * 6))

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(mark, ((size - inner) // 2, (size - inner) // 2), mark)
    return canvas


if __name__ == "__main__":
    icon = build()

    out = Path("public/icons")
    out.mkdir(parents=True, exist_ok=True)
    for size in (512, 192):
        icon.resize((size, size), Image.LANCZOS).save(out / f"icon-{size}.png")
        print(f"  wrote {out / f'icon-{size}.png'}")
    icon.resize((180, 180), Image.LANCZOS).save("public/gs-logo.png")
    print("  wrote public/gs-logo.png")

    # Android launcher icons, at the densities Capacitor generated.
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    res = Path("android/app/src/main/res")
    for name, size in densities.items():
        d = res / f"mipmap-{name}"
        if not d.is_dir():
            continue
        square = icon.resize((size, size), Image.LANCZOS)
        square.save(d / "ic_launcher.png")

        # The round variant is masked to a circle by older launchers that do
        # not support adaptive icons, so it is drawn as a circle here.
        circle = Image.new("L", (size * 4, size * 4), 0)
        ImageDraw.Draw(circle).ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
        round_icon = icon.resize((size * 4, size * 4), Image.LANCZOS).convert("RGBA")
        round_icon.putalpha(circle)
        round_icon.resize((size, size), Image.LANCZOS).save(d / "ic_launcher_round.png")

        mark_only(size).save(d / "ic_launcher_foreground.png")
        print(f"  wrote {d}/ic_launcher*.png  ({size}px)")

    # The adaptive background is a flat colour behind the foreground, and it was
    # white, which framed the new dark mark in a white ring on most launchers.
    bg = res / "values" / "ic_launcher_background.xml"
    if bg.is_file():
        bg.write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#0A0E12</color>\n'
            "</resources>\n",
            encoding="utf-8")
        print(f"  wrote {bg}  (#0A0E12)")

    # Splash screens.
    #
    # Every one of these was solid white, so launching a dark app flashed white
    # first. On a phone at night that is the most noticeable thing about the
    # whole redesign, and it is the one screen the user cannot skip.
    #
    # Each existing file is rewritten at its own size, so the density and
    # orientation variants Capacitor generated stay correct.
    splashes = sorted(res.glob("drawable*/splash.png"))
    for path in splashes:
        with Image.open(path) as existing:
            w, h = existing.size
        canvas = Image.new("RGB", (w, h), BG)

        # A glow behind the mark, sized to the shorter edge so portrait and
        # landscape both look deliberate rather than stretched.
        short = min(w, h)
        glow = Image.new("L", (w, h), 0)
        gr = short * 0.42
        ImageDraw.Draw(glow).ellipse(
            [w / 2 - gr, h / 2 - gr, w / 2 + gr, h / 2 + gr], fill=70)
        glow = glow.filter(ImageFilter.GaussianBlur(short * 0.10))
        canvas = Image.composite(Image.new("RGB", (w, h), (16, 52, 58)), canvas, glow)

        mark = mark_only(round(short * 0.34), fraction=1.0)
        canvas.paste(mark, ((w - mark.width) // 2, (h - mark.height) // 2), mark)
        canvas.save(path)
    print(f"  wrote {len(splashes)} splash screens  (#0A0E12)")
