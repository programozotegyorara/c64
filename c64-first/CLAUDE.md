# C64 Scroller Demo

A minimal Commodore 64 demo that shows a smooth horizontal text scroller on row 12, written in 6502 assembly with the cc65 toolchain.

## Files

- `scroll.s` — 6502 source (ca65 syntax)
- `c64-asm.cfg` — custom ld65 linker config (pure-asm, no cc65 runtime)
- `Makefile` — build / run / clean targets
- `scroll.prg` — built artifact (load address `$0801`)

## Build & run

```sh
make          # ca65 + ld65 → scroll.prg
make run      # launches VICE x64sc with the prg
make clean
```

Requires `cc65` and `vice` from Homebrew (`brew install cc65 vice`). Note: VICE on macOS is the **formula** `vice`, not a cask — `brew install --cask vice` does not exist.

## Memory layout

The custom `c64-asm.cfg` keeps things explicit and avoids pulling in the cc65 C runtime:

| Segment    | Load addr | Purpose                                  |
|------------|-----------|------------------------------------------|
| `LOADADDR` | `$07FF`   | 2-byte PRG load-address word (`$0801`)   |
| `EXEHDR`   | `$0801`   | BASIC stub: `10 SYS 2061`                |
| `CODE`     | `$080D`   | Entry point (`start:`) — matches SYS 2061 |
| `DATA`     | after CODE| `scroll_pos`, `frame_ctr`, `xscroll`, `message` |

The SYS target (`2061` = `$080D`) **must** match where CODE actually begins after the BASIC stub (12 bytes from `$0801`). If you change the stub, recompute it.

## Scrolling technique

Classic C64 hardware scroll, not character-by-character:

1. **`$D016` X-scroll register** (lower 3 bits) shifts the visible row 0–7 pixels.
2. Each frame tick decrements `xscroll`. When it wraps from 0 → 7, the row is shifted one character left in screen RAM and the next message byte is appended at column 39. This gives smooth pixel-level motion.
3. **38-column mode** (`$D016` bit 3 = 0, CSEL) hides the row's edges behind the side border so you don't see characters popping in/out.
4. Frame sync is a busy-wait on raster line `$F8` (below visible area) — `FRAME_SKIP` controls speed (frames per pixel step).

Tunables in `scroll.s`:
- `FRAME_SKIP` — pixels-per-frame divisor (lower = faster). Currently `1` (~50 px/sec). Integer-only; for finer steps add a fractional accumulator.
- `SCROLL_ROW` — which text row scrolls (currently row 12)
- `COLOR_DELAY` — frames per color step in the pulse (see below)

## Color pulse

`update_color` runs every frame and ping-pongs the scroll row through the C64 grayscale ramp on a separate clock from the scroll:

`$00` black → `$0B` dark grey → `$0C` mid grey → `$0F` light grey → `$01` white → `$0F` → `$0C` → `$0B` → loop

The table is `color_table` (8 entries). Each step holds for `COLOR_DELAY = 6` frames; on a step the routine rewrites all 40 entries of `COLOR_ROW`. The black step is intentionally invisible against the black background — that's the fade beat. The colors are independent of the scroll speed.

## Character encoding gotcha (important)

**Do not pass `-t c64` to ca65.** That target installs an ASCII→PETSCII charmap, which translates `"A"` (ASCII `$41`) to PETSCII `$C1`. The `petscii_to_screen` routine expects raw ASCII in the `$40-$5F` range and would otherwise emit graphics symbols instead of letters.

The Makefile invokes ca65 with no `-t` flag so strings stay as raw ASCII bytes. `petscii_to_screen` then maps:

- `$20-$3F` → unchanged (space, punctuation, digits)
- `$40-$5F` → `-$40` (uppercase A–Z + symbols → screen codes `$00-$1F`)
- `$60-$7F` → `-$60` (lowercase a–z folded onto the same A–Z screen-code slots)

This means message strings can be written in natural mixed case in the source, but the **default uppercase/graphics charset has no real lowercase glyphs** — both cases render with the uppercase shapes. To get true mixed-case output, switch to the lowercase/uppercase charset by writing `$17` to `$D018` and adjust the converter to keep cases distinct.

ld65 still gets `-C c64-asm.cfg` and does not need `-t` either — passing both `-t` and `-C` to ld65 errors out with "Cannot use -C/-t twice".

## Conventions

- Pure asm; no cc65 C runtime, no startup library, no zeropage allocator.
- All hardware register addresses are named constants at the top of `scroll.s`.
- Frame timing is raster-polled, not IRQ-driven — simple and good enough for a single-row scroller. Switch to a raster IRQ if you add multi-region effects.
