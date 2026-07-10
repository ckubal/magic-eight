# Magic Eight — Theme Background Regeneration Kit

The old backgrounds failed because they were **square collages centered in a tall canvas with baked-in
letterbox padding**. The app crops to fill the screen, so the padding showed as bars. These prompts
produce **true full-bleed portrait wallpapers** that fill the whole phone screen with no bars.

---

## Non-negotiable design rules (why the old ones broke)

Every prompt below already bakes these in, but if you write your own, keep them:

1. **Full-bleed, edge-to-edge.** Art must reach all four edges. Explicitly forbid: *borders, frames,
   letterbox bars, padding, margins, drop-shadow around the art, rounded corners.*
2. **Portrait, tall.** Target the phone: **9:19.5** (~1290×2796). If a tool can't do arbitrary ratios,
   use the tallest it offers (2:3 / 1024×1536) — the app crops the sides, not the top/bottom.
3. **Calm center — but DON'T draw a ball.** The app overlays its own 3D black 8-ball dead-center. Ask
   for a *softly darkened, less-busy vertical center* (textured, not a solid black hole) — and
   **explicitly forbid drawing any magic 8-ball / pool ball / sphere / circle**, or you get two
   overlapping balls. This is the single most important line to include.
4. **Keep key detail in the central ~80% width.** On narrow phones the far left/right get cropped, so
   don't put anything essential at the extreme edges.
5. High detail, crisp, no watermark / signature / caption text unless the theme is literally a UI.

---

## Aspect ratio & tool cheat-sheet

| Tool | Best for | Portrait control | Notes |
|------|----------|------------------|-------|
| **Midjourney v6/v7** | Highest aesthetic, exact fit | `--ar 9:19.5` (or `--ar 1290:2796`) | Best choice for pixel-perfect no-crop. Batch by pasting many `/imagine` lines. |
| **Ideogram / Leonardo / Freepik** | Themes with real text (MySpace, Facebook, AIM) | custom ratios incl. ~9:19.5 | Better text rendering than most. |
| **ChatGPT (gpt-image-1)** | Easy, one at a time | max portrait 1024×1536 (2:3) | Sides get cropped ~30% by the app — fine given the center-safe design. |
| **OpenAI Images API** | True batch (see `generate_backgrounds.py`) | 1024×1536 | Run all 20 in one script. |

**Recommendation:** Midjourney `--ar 9:19.5` for the best-looking, zero-crop result; or the batch API
script if you want all 20 generated hands-off.

---

## Reusable master template

> Full-bleed vertical phone wallpaper, **9:19.5 portrait**, of **{THEME}**. The artwork fills the entire
> frame edge to edge — top, bottom, and both sides — with **no borders, no frame, no letterbox bars, no
> padding, no margins**. Rich detail is concentrated around the edges, top, and bottom, framing a
> **calmer, softly shadowed open area down the vertical center**. **IMPORTANT: do NOT draw any magic
> 8-ball, pool ball, sphere, circle, orb, or ball anywhere** — the center must stay as simple, softly
> shadowed background texture (a separate app overlays a 3D 8-ball there, so leave that space open).
> Keep the most important elements within the central 80% of the width. **{COLOR / MOOD}.**
> Ultra-detailed, crisp, high resolution, cohesive composition, no watermark, no signature, no captions.

---

## The 20 prompts (copy-paste ready)

Each is standalone. File it into `Assets.xcassets/theme-bg-<id>.imageset/background.png`.

### classic  🎱 — *Classic*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **vintage 1950s Mattel Magic 8-Ball toy world** — glossy black fortune-telling spheres, aged cream-and-cherry-red retro toy packaging, mid-century atomic starbursts, worn cardboard and print-halftone texture, old fortune-teller graphics. Fills the frame edge to edge, no borders/frame/letterbox/padding. Detail around the edges and top/bottom, with a softly shadowed, less-busy textured center column left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Keep key detail within the central 80% width. Nostalgic, warm, slightly faded vintage palette. Ultra-detailed, crisp, no watermark.

### shakespearean  🪶 — *Shakespearean*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of an **Elizabethan manuscript** — aged parchment, handwritten iron-gall ink script and calligraphic flourishes, quill pens, dripping wax seals, First-Folio typography, ink blots and smudges. Fills the frame edge to edge, no borders/frame/letterbox/padding. Detail concentrated at edges and top/bottom, framing a softly shadowed, less-busy textured parchment center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Candle-lit sepia and bone-white palette, moody. Ultra-detailed, crisp, no watermark.

### huntersthompson  🦂 — *Hunter S. Thompson*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, in **Ralph Steadman gonzo style** — frantic splattered black ink, bleeding acid-red and toxic-green watercolor, Fear-and-Loathing Las Vegas desert chaos, wild scrawled linework, bats, cacti and neon casino signs. Fills the frame edge to edge, no borders/frame/letterbox/padding. Chaos pushed to the edges and top/bottom, with a calmer, softly darkened but still ink-textured center column left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Deranged, high-contrast, psychedelic desert palette. Ultra-detailed, crisp, no watermark.

### genalpha  🍼 — *Gen Alpha*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **kidcore pastel sticker-bomb collage** — cute rainbow stickers, glittery hearts, stars, clouds, smiley faces, candy, plushies, holographic sparkles, densely packed. Fills the frame edge to edge, no borders/frame/letterbox/padding. Stickers packed around the edges and top/bottom, framing a softly shadowed, calmer sparkly center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Bright, saturated, playful rainbow palette. Ultra-detailed, crisp, no watermark.

### genz  ⚡ — *Gen Z*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **Gen-Z neon sticker collage on near-black** — glowing neon-outline doodles, holographic gradient blobs, sparkles, y2k emoji icons, drippy graffiti, chrome hearts. Fills the frame edge to edge, no borders/frame/letterbox/padding. Neon elements crowd the edges and top/bottom, framing a darker, calmer center column (still faintly glowing) left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Cyan-and-magenta neon glow on black. Ultra-detailed, crisp, no watermark.

### millennial  📼 — *Millennials*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of an **early-2000s Y2K / Frutiger Aero aesthetic** — glossy bubble icons, aqua gradients, lens flares, chrome type, translucent gel buttons, soft clouds and dewy grass, optimistic iPod-era tech-utopia. Fills the frame edge to edge, no borders/frame/letterbox/padding. Glossy elements around the edges and top/bottom, framing a calmer, softly shadowed glassy center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Aqua-blue, silver, and lime, bright and glossy. Ultra-detailed, crisp, no watermark.

### genx  🎧 — *Gen X*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **90s grunge rave-flyer aesthetic** — bold Memphis geometric shapes, paint splatter, halftone dots, distorted xerox/photocopy texture, jagged neon-on-black MTV-era graphic chaos, cassette and boombox motifs. Fills the frame edge to edge, no borders/frame/letterbox/padding. Graphics pushed to the edges and top/bottom, framing a calmer, gritty-textured darker center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Neon magenta, electric teal, and black, high-contrast. Ultra-detailed, crisp, no watermark.

### boomers1958  📻 — *Boomers*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **1950s retro diner** — chrome trim and red vinyl booths, black-and-white checkerboard floor, glowing neon 'OPEN' and 'EAT' signs, jukebox, milkshakes, atomic starbursts. Fills the frame edge to edge, no borders/frame/letterbox/padding. Diner detail around the edges and top/bottom, framing a calmer, softly shadowed center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Mint green, cherry red, cream and chrome, cheerful retro. Ultra-detailed, crisp, no watermark.

### twitterx2024  🐦 — *Twitter 2025*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **modern X / Twitter dark-mode UI aesthetic** — near-black background, subtle dark-grey UI cards and dividers, minimalist white and electric-blue accents, sparse floating like / repost / reply glyphs, glassy panels. Fills the frame edge to edge, no borders/frame/letterbox/padding. UI elements drift toward the edges and top/bottom, leaving a clean, slightly darker calm center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Monochrome black-grey with blue accents, sleek and minimal. Ultra-detailed, crisp, no watermark.

### tiktok2020  🎵 — *TikTok 2020*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **TikTok 2020 UI aesthetic** — dark background with vibrant neon cyan and magenta glow, floating music notes, heart / comment / share icons, glitchy chromatic-aberration edges, 'For You' energy. Fills the frame edge to edge, no borders/frame/letterbox/padding. Neon UI around the edges and top/bottom, framing a darker calm center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Black with cyan + magenta neon, punchy. Ultra-detailed, crisp, no watermark.

### tumblr2012  🌙 — *Tumblr 2012*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **2012 Tumblr soft-grunge aesthetic** — moody desaturated pastels, faded 35mm film grain, indie photo collage of roses, galaxy prints, cross and triangle motifs, dreamy hipster-grunge overlays. Fills the frame edge to edge, no borders/frame/letterbox/padding. Collage crowds the edges and top/bottom, framing a hazy, softly darkened calm center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Washed lavender, dusty rose, and charcoal, dreamy and faded. Ultra-detailed, crisp, no watermark.

### facebook2008  📘 — *Facebook 2008*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **2008 Facebook UI nostalgia scene** — classic Facebook-blue header bars, white profile panels, wall posts, poke / friend-request / notification icons, Tahoma-style type, clean early-web boxes tiled densely. Fills the frame edge to edge, no borders/frame/letterbox/padding. UI panels tiled to the edges and top/bottom, framing a softly shadowed calmer center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Facebook blue, white, and grey, clean web-2.0. Ultra-detailed, crisp, no watermark.

### deviantart2006  🎨 — *DeviantArt 2006*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **mid-2000s DeviantArt community aesthetic** — dark charcoal-green layout, tiled digital-art thumbnails, journal panels, pixel icons and stamps, early digital-painting grunge brushes and splatters. Fills the frame edge to edge, no borders/frame/letterbox/padding. Panels and thumbnails around the edges and top/bottom, framing a softly darkened calm center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Charcoal, olive-green, and muted teal, early-web arty. Ultra-detailed, crisp, no watermark.

### myspace2005  🖤 — *MySpace 2005*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of **2005 MySpace profile chaos** — glitter GIF sparkles, a 'Top 8' friends grid, comment boxes, sparkly cursors, clashing custom-HTML layout blocks, autoplay-music vibe, on a black background. Fills the frame edge to edge, no borders/frame/letterbox/padding. Layout blocks and glitter around the edges and top/bottom, framing a darker calm center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Black with hot-pink and lime glitter, chaotic emo-scene energy. Ultra-detailed, crisp, no watermark.

### xanga2002  📓 — *Xanga Girl 2002*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of an **early-2000s Xanga blog aesthetic** — girly glitter layouts, tiled pixel-heart and star backgrounds, sparkle dividers, cursive script, pastel web-1.0 doodads and blinkies. Fills the frame edge to edge, no borders/frame/letterbox/padding. Girly detail around the edges and top/bottom, framing a soft, calmer center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Baby pink, powder blue, and glitter, sweet and nostalgic. Ultra-detailed, crisp, no watermark.

### aimy2k  💬 — *AIM 2001*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **year-2000 AOL Instant Messenger aesthetic** — overlapping Windows-2000 chat windows, buddy lists, the yellow running-man icon, away-message boxes, beige title bars and blocky pixel UI, tiled densely. Fills the frame edge to edge, no borders/frame/letterbox/padding. Windows tiled to the edges and top/bottom, framing a softly darkened calm center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Windows teal, beige, and AIM yellow, retro-desktop. Ultra-detailed, crisp, no watermark.

### harrypotter  🪄 — *Harry Potter*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **Marauder's-Map parchment aesthetic** — aged tan parchment, hand-inked magical map lines and footprints, wands, stars, moons, compass roses, spell script and flourishes. Fills the frame edge to edge, no borders/frame/letterbox/padding. Map detail around the edges and top/bottom, framing a softly shadowed calmer parchment center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Aged tan, sepia-brown ink, warm and magical. Ultra-detailed, crisp, no watermark.

### matrix  🟩 — *The Matrix*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of **The Matrix digital rain** — cascading green katakana and monospaced code glyphs on black, glowing trails, CRT scanlines, deep emerald glow, dense at the edges. Fills the frame edge to edge, no borders/frame/letterbox/padding. Brightest code crowds the edges and top/bottom, fading to a darker, calmer center column left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Emerald green on black, glowing and digital. Ultra-detailed, crisp, no watermark.

### nbajam  🔥 — *Arcade Sports*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of a **90s NBA Jam arcade aesthetic** — flaming basketballs, bold pixel-art explosions, 'ON FIRE' energy, arcade-cabinet neon, halftone crowd, lightning bolts and stars. Fills the frame edge to edge, no borders/frame/letterbox/padding. Explosive detail around the edges and top/bottom, framing a calmer, smoky-textured darker center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Electric blue, flame orange, and black, high-energy arcade. Ultra-detailed, crisp, no watermark.

### sportscenter  📺 — *SportsCenter Catchphrases*
Full-bleed vertical phone wallpaper, 9:19.5 portrait, of an **ESPN SportsCenter broadcast aesthetic** — glossy red-and-black sports-graphics panels, lower-third bars, motion swooshes, stadium floodlights, bold sporty chevrons and highlight-reel energy. Fills the frame edge to edge, no borders/frame/letterbox/padding. Broadcast graphics around the edges and top/bottom, framing a calmer, softly darkened center left open for the app's 3D 8-ball overlay — do NOT draw any ball, sphere, or circle. Key detail within central 80% width. Red, black, and steel-grey, glossy and broadcast-slick. Ultra-detailed, crisp, no watermark.

---

## Placing the finished art

Each theme id maps to `Assets.xcassets/theme-bg-<id>.imageset/background.png`. Replace the file, keep the
name `background.png`. No code changes needed — the app already renders any full-bleed image correctly.

Quick sanity check after dropping new art in (run from `Assets.xcassets`):

```bash
python3 -c "from PIL import Image; im=Image.open('theme-bg-genalpha.imageset/background.png'); print(im.size, im.width/im.height)"
```

Aim for a tall portrait ratio (≤ 0.55). Anything close to square will get cropped hard on the sides.
