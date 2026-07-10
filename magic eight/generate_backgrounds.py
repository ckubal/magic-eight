#!/usr/bin/env python3
"""
Batch-generate all 20 Magic Eight theme backgrounds via the OpenAI Images API
(gpt-image-1) and drop them straight into the asset catalog.

Setup:
    pip install openai
    export OPENAI_API_KEY=sk-...

Run:
    python3 generate_backgrounds.py               # generate every theme
    python3 generate_backgrounds.py genz matrix   # only these themes
    OUT_DIR=./preview python3 generate_backgrounds.py   # write to ./preview instead of the asset catalog

Notes:
  * gpt-image-1's tallest portrait is 1024x1536 (2:3). The app uses aspect-fill and
    crops the SIDES, so 2:3 is fine — the prompts keep key detail center-safe.
  * For a pixel-perfect 9:19.5 with zero side-crop, generate in Midjourney with
    `--ar 9:19.5` using the same prompt text and skip this script.
  * Cost is roughly $0.02-0.19 per image depending on `quality` (~20 images total).
"""
import base64
import os
import sys

from openai import OpenAI

# theme id -> the {THEME} + {COLOR/MOOD} core; wrapped in the shared full-bleed template below.
THEMES = {
    "classic": "a vintage 1950s Mattel Magic 8-Ball toy world (glossy black fortune spheres, cream-and-cherry-red retro packaging, atomic starbursts, aged cardboard halftone). Warm, faded vintage palette",
    "shakespearean": "an Elizabethan manuscript (aged parchment, iron-gall ink script and flourishes, quills, wax seals, First-Folio type, ink blots). Candle-lit sepia and bone-white",
    "huntersthompson": "Ralph Steadman gonzo style (splattered black ink, bleeding acid-red and toxic-green watercolor, Fear-and-Loathing Vegas chaos, bats, neon casino signs). Deranged high-contrast psychedelic desert",
    "genalpha": "a kidcore pastel sticker-bomb collage (rainbow stickers, glittery hearts, stars, clouds, smileys, candy, plushies, holographic sparkles). Bright saturated playful rainbow",
    "genz": "a Gen-Z neon sticker collage on near-black (glowing neon-outline doodles, holographic blobs, sparkles, y2k emoji, drippy graffiti, chrome hearts). Cyan-and-magenta neon glow on black",
    "millennial": "an early-2000s Y2K / Frutiger Aero aesthetic (glossy bubble icons, aqua gradients, lens flares, chrome, gel buttons, clouds and dewy grass). Aqua-blue, silver, lime, glossy",
    "genx": "a 90s grunge rave-flyer aesthetic (Memphis geometric shapes, paint splatter, halftone, xerox texture, neon-on-black MTV chaos, cassette motifs). Neon magenta, electric teal, black",
    "boomers1958": "a 1950s retro diner (chrome and red vinyl, checkerboard floor, neon OPEN/EAT signs, jukebox, milkshakes, atomic starbursts). Mint green, cherry red, cream, chrome",
    "twitterx2024": "a busy modern X (Twitter) dark-mode timeline — many stacked tweet cards with round avatars, blue verified checks, short text and glowing blue reply/retweet/like/view counts, a trending sidebar with hashtags, compose box and notification badges; densely packed feed, no large black voids. Near-black with white text and electric-blue accents",
    "tiktok2020": "a busy TikTok 2020 'For You' feed — floating video thumbnails with faces, a spinning music disc, hearts/comment/share icons with view counts, #fyp hashtags, avatars, sound-wave bars and music notes, glitchy neon glow; lots of floating UI, densely packed. Black with vibrant cyan and magenta neon",
    "tumblr2012": "a busy 2012 Tumblr dashboard collage — overlapping reblogged posts: soft-grunge photos of roses, galaxies and film-grain portraits, black-and-white text posts, note/heart/reblog icons, indie stickers, crosses and triangles; densely layered, minimal empty haze. Washed lavender, dusty rose and charcoal, dreamy",
    "facebook2008": "a busy, content-rich 2008-era Facebook profile — blue top bar with logo and search, profile photo, a dense Wall of status updates and posts each with a friend avatar, a Top-Friends grid of small photos, poke and notification badges, mini-feed, group/app icons, blue chat bar, sidebar ad; packed with UI, photos and text, almost no empty space. Facebook blue, white and grey, clean web-2.0",
    "deviantart2006": "a vibrant mid-2000s DeviantArt gallery — a dense grid of colorful art thumbnails (fantasy landscapes, anime, 3D renders, photography), green DA header, journal panels, pixel stamps and llama badges, +fav/watch/comment buttons; packed with bright colorful artwork, vivid not murky. Charcoal and DA-green with bright thumbnails",
    "myspace2005": "2005 MySpace profile chaos (glitter GIFs, a Top-8 friends grid, comment boxes, sparkly cursors, clashing HTML blocks, on black). Black with hot-pink and lime glitter, chaotic emo-scene",
    "xanga2002": "an early-2000s Xanga blog aesthetic (girly glitter layouts, tiled pixel-heart/star backgrounds, sparkle dividers, cursive script, blinkies). Baby pink, powder blue, glitter, sweet",
    "aimy2k": "a desktop crowded with overlapping year-2000 AOL Instant Messenger windows — buddy lists and IM chat windows with beige title bars and blue chrome, the yellow AIM running-man repeated, smileys, send buttons and scrollbars over a Windows-2000 teal desktop; many overlapping windows, lots going on, lettering minimal and correctly spelled. Windows teal, beige and AIM yellow",
    "harrypotter": "a Marauder's-Map parchment aesthetic (aged tan parchment, inked map lines and footprints, wands, stars, moons, compass roses, spell script). Aged tan, sepia-brown ink, warm magical",
    "matrix": "The Matrix digital rain (cascading green katakana and monospaced code on black, glowing trails, CRT scanlines, emerald glow). Emerald green on black, glowing digital",
    "nbajam": "a 90s NBA Jam arcade aesthetic (flaming basketballs, pixel-art explosions, ON FIRE energy, arcade neon, halftone crowd, lightning). Electric blue, flame orange, black, high-energy",
    "sportscenter": "an ESPN SportsCenter broadcast aesthetic (red-and-black graphics panels, lower-third bars, motion swooshes, stadium floodlights, bold chevrons). Red, black, steel-grey, glossy broadcast",
}

TEMPLATE = (
    "Full-bleed vertical phone wallpaper, 9:19.5 portrait, of {core}. The artwork fills the "
    "entire frame edge to edge — top, bottom, and both sides — with no borders, no frame, no "
    "letterbox bars, no padding, no margins. Rich detail is concentrated around the edges, top, "
    "and bottom, framing a calmer, softly shadowed open area down the vertical center. "
    "IMPORTANT: do NOT draw any magic 8-ball, pool ball, sphere, circle, orb, or ball anywhere — "
    "the center must stay as simple, softly shadowed background texture (a separate app overlays a "
    "3D 8-ball there, so leave that space open). Keep the most important elements within the "
    "central 80% of the width. Ultra-detailed, crisp, high resolution, cohesive composition, "
    "no watermark, no signature, no text captions."
)

# Where finished art lands. Defaults to the asset catalog next to this script.
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Assets.xcassets")
OUT_DIR = os.environ.get("OUT_DIR")  # if set, write flat PNGs here instead


def dest_path(theme: str) -> str:
    if OUT_DIR:
        os.makedirs(OUT_DIR, exist_ok=True)
        return os.path.join(OUT_DIR, f"theme-bg-{theme}.png")
    return os.path.join(ASSETS, f"theme-bg-{theme}.imageset", "background.png")


def main():
    wanted = [a for a in sys.argv[1:] if not a.startswith("-")] or list(THEMES)
    unknown = [t for t in wanted if t not in THEMES]
    if unknown:
        sys.exit(f"Unknown theme(s): {', '.join(unknown)}\nValid: {', '.join(THEMES)}")

    client = OpenAI()  # reads OPENAI_API_KEY
    for i, theme in enumerate(wanted, 1):
        prompt = TEMPLATE.format(core=THEMES[theme])
        print(f"[{i}/{len(wanted)}] generating {theme} ...")
        resp = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size="1024x1536",
            quality="high",
            n=1,
        )
        png = base64.b64decode(resp.data[0].b64_json)
        out = dest_path(theme)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "wb") as f:
            f.write(png)
        print(f"    -> {out}")
    print("done")


if __name__ == "__main__":
    main()
