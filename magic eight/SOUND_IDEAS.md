# Magic Eight — Sound Sourcing Kit

A shopping list for the reveal cues (and future sounds). Everything below is a *suggestion* —
grab whatever fits the vibe.

---

## How the sound system works today

- On each fortune reveal the app plays **one short cue** for the current theme, in sync with a haptic.
- The engine ([SoundManager.swift](SoundManager.swift)) plays `.wav` files bundled in `/Sounds`.
- **To swap any sound: keep the filename, replace the file.** No code change needed.
- Right now there are **9 shared cues** and the 20 themes map onto them (grouped by vibe).

### Current setup: PER-THEME (active)
Each theme now plays its own file **`cue-<themeid>.wav`** in `/Sounds` (e.g. `cue-aimy2k.wav`).
There are 20 original synthesized placeholders in place today — **replace any one to give that theme
its real sound.** If a `cue-<id>.wav` is ever missing, the app falls back to the shared vibe cue
(the 9 files below), then to `knock.wav`. Use the per-theme "ideal sound" table for what to source.

### File spec (for anything you make/export)
- Format **WAV** (or m4a/mp3), **44.1 kHz**, mono is fine.
- Keep cues **short: 0.2–1.5 s**. Special/anticipation can be up to ~2 s.
- Normalize so it's audible but not clipping. Trim leading silence.

---

## The 9 shared cues (current files)

| File | Used by themes | What it should be | Search keywords |
|------|----------------|-------------------|-----------------|
| `knock.wav` | classic (+default) | hollow plastic/wood knock, or a real 8-ball shake-and-settle liquid *glug* | `pool ball click`, `wood knock`, `toy shake`, `liquid glug bloop` |
| `bell.wav` | boomers1958 | diner counter bell *ding*, or cash-register *cha-ching* | `diner bell ding`, `service bell`, `cash register`, `jukebox click` |
| `blip.wav` | matrix, deviantart2006, twitterx2024, tiktok2020, sportscenter | crisp digital notification blip | `digital blip`, `soft notification`, `UI ding`, `computer beep` |
| `modem.wav` | facebook2008, myspace2005, aimy2k | dial-up handshake screech (short) | `dial up modem`, `56k handshake`, `modem connect` |
| `ringtone.wav` | genx | retro monophonic cellphone melody (original, **not** Nokia) | `retro phone ring`, `polyphonic ringtone`, `90s cellphone` |
| `arcade.wav` | nbajam, huntersthompson | arcade power-up / explosion hit | `arcade power up`, `8-bit explosion`, `coin insert`, `he's on fire` |
| `twinkle.wav` | genalpha, genz, millennial, tumblr2012, xanga2002 | sparkly ascending chime / glitter shimmer | `sparkle chime`, `glitter twinkle`, `magic sparkle`, `cute ding` |
| `mystic.wav` | shakespearean, harrypotter | magical harp shimmer / spell cast | `magic shimmer`, `harp glissando`, `wand cast`, `mystical chime` |
| `shiny.wav` | ✨ rare fortunes (all themes) | triumphant fanfare / gacha "legendary" | `level up`, `power up fanfare`, `achievement`, `legendary reward` |

---

## Ideal per-theme sounds (if you go for 20 unique)

| Theme | Ideal sound | Search keywords | ⚠️ don't ship the real one |
|-------|-------------|-----------------|-----------------------------|
| **classic** | 8-ball shake + liquid settle, or pool-ball clack | `magic 8 ball shake`, `pool ball click`, `liquid bloop` | — |
| **shakespearean** | quill scratch + lute/harpsichord flourish, page turn | `quill writing`, `harpsichord chord`, `lute`, `parchment page` | — |
| **huntersthompson** | typewriter ding+slam, bat screech, psychedelic wobble | `typewriter ding`, `psychedelic whoosh`, `bat screech`, `ether wobble` | — |
| **genalpha** | kawaii pop-it fidget, cute boing + sparkle | `cute pop`, `pop it fidget`, `cartoon boing`, `kawaii chime` | — |
| **genz** | slick UI pop + "vine boom" style bass hit | `vine boom`, `notification pop`, `bass drop hit` | meme audio — check reuse |
| **millennial** | glassy MSN-style nudge / aqua bubble blip | `MSN nudge` (→ use a sound-alike), `glass UI blip`, `aqua bubble` | real MSN nudge |
| **genx** | cassette clunk + tape whir, or TV channel static | `cassette clunk`, `tape rewind`, `TV static zap`, `boombox click` | — |
| **boomers1958** | jukebox needle drop, soda-fountain fizz, cash register | `jukebox needle drop`, `vinyl start`, `soda fizz`, `cash register` | — |
| **twitterx2024** | post-sent *swoosh* + soft chirp | `sent swoosh`, `tweet whoosh`, `soft chirp` | real Twitter/X sound |
| **tiktok2020** | bright ding/ta-da + snappy transition whoosh | `pop transition`, `snap swoosh`, `bright ding` | real TikTok ding |
| **tumblr2012** | lo-fi vinyl crackle + mellow chime, camera shutter | `vinyl crackle`, `lofi swell`, `camera shutter`, `soft chime` | — |
| **facebook2008** | the "poke" *boop* / old chat pop | `poke boop`, `chat pop`, `soft notification` | real FB chat pop |
| **deviantart2006** | mouse click + submit chime, brush stroke | `mouse click`, `UI submit`, `brush stroke`, `camera shutter` | — |
| **myspace2005** | emo power-chord stab / profile-song start + glitter | `power chord stab`, `emo guitar`, `glitter sparkle`, `web ding` | recognizable song clips |
| **xanga2002** | MIDI glitter twinkle / "new post" chime | `MIDI chime`, `glitter twinkle`, `sparkle`, `cute ding` | — |
| **aimy2k** | **door creak = buddy on**, door slam = buddy off, IM knock+beep | `door creak open`, `door slam`, `knock knock`, `IM beep` | real AOL door / "You've Got Mail" |
| **harrypotter** | wand sparkle whoosh, spellbook page, distant owl hoot | `magic sparkle`, `wand whoosh`, `spellbook page`, `owl hoot` | film score / real FX |
| **matrix** | digital glitch/data beep, cyber whoosh, ringing phone | `digital glitch`, `data beep`, `cyber whoosh`, `computer blip` | film's exact phone ring |
| **nbajam** | swish + buzzer + explosion; announcer "boomshakalaka" | `basketball swish`, `buzzer`, `arcade explosion`, `coin insert` | real NBA Jam voice — **record your own** |
| **sportscenter** | broadcast sting/whoosh + crowd cheer + highlight ding | `sports broadcast sting`, `news swoosh`, `crowd cheer`, `highlight ding` | real ESPN "da-na-na" theme |

---

## Special / system sounds (nice-to-haves)

| Slot | Sound | Search keywords | Status |
|------|-------|-----------------|--------|
| **Shiny fortune** ✨ | triumphant fanfare / legendary reward | `level up`, `fanfare`, `achievement`, `sparkle win` | `shiny.wav` exists |
| **Flip-down anticipation** (Phase 3) | low rumble/riser, shake-liquid glug, suspense build | `suspense riser`, `whoosh charge`, `rumble build`, `liquid shake` | planned |
| **Theme switch** | soft swipe/whoosh | `swipe whoosh`, `transition whoosh`, `page turn` | optional |
| **Button tap / UI** | subtle click | `UI tap`, `soft click`, `bubble tap` | optional |

## Optional per-era ambient loops (very low, toggleable — later phase)
Chiptune/MIDI for 90s · 50s diner jukebox / doo-wop for boomers · lo-fi for tumblr · dark synth drone
for matrix · vaporwave for millennial. Search `royalty free [era] loop` / `[era] background music no copyright`.

---

## Where to get them (royalty-free)

- **Pixabay Audio** — royalty-free, no attribution, commercial OK. *Best default.*
- **Freesound.org** — huge; filter license to **CC0** to avoid attribution requirements.
- **Mixkit**, **Uppbeat**, **YouTube Audio Library**, **Zapsplat** (free w/ account).
- **AI sound effects** — ElevenLabs "Sound Effects" (type a description like "retro dial-up modem
  connecting, short"), or similar generators. Great for exact one-offs.
- **DIY** — GarageBand (built-in FX + synths), or just record real objects: shake an actual 8-ball,
  tap wood, quill on paper, a real diner bell. Phone voice-memo → trim → export.

### ⚠️ Licensing — important for the App Store
Do **not** ship the *actual* trademarked/copyrighted sounds. Use sound-alikes or originals for:
Nokia "Gran Vals", Windows startup chime, AOL "You've Got Mail" / door, ICQ "uh-oh", the real
MSN nudge, the real TikTok ding, actual NBA Jam announcer samples, the ESPN SportsCenter theme,
recognizable song clips. Personal/side-loaded use is lower-risk, but for distribution stay clean.

When you've gathered files, drop them in `/Sounds` (same names to swap the 9 cues, or `cue-<themeid>.wav`
for per-theme) and I'll wire up whichever route you chose.
