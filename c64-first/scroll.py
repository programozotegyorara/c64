#!/usr/bin/env python3
"""
Python port of the C64 scroll.s demo.

Renders a horizontal text scroller on row 12 of the terminal, with a
ping-pong grayscale color pulse, mimicking the original 6502 version.

Run:  python3 scroll.py     (Ctrl-C to quit)
"""

import sys
import time

# --- Tunables (mirror scroll.s) --------------------------------------------
SCROLL_ROW   = 12              # which terminal row the scroller lives on
VISIBLE_COLS = 38              # 38-column mode like $D016 CSEL=0
FRAME_HZ     = 50              # C64 PAL frame rate
FRAME_SKIP   = 1               # pixels per shift (lower = faster)
COLOR_DELAY  = 6               # frames per color step

MESSAGE = (
    " " * 40 +
    "Hello           "
)

# Ping-pong fade: black -> dark grey -> mid grey -> light grey -> white -> ...
# Mapped to the nearest xterm-256 grayscale values.
COLOR_TABLE = [232, 236, 240, 250, 231, 250, 240, 236]


def fg(code: int) -> str:
    return f"\x1b[38;5;{code}m"


RESET = "\x1b[0m"
CLEAR = "\x1b[2J"
HIDE  = "\x1b[?25l"
SHOW  = "\x1b[?25h"


def move(row: int, col: int) -> str:
    return f"\x1b[{row};{col}H"


def main() -> None:
    buf = [" "] * VISIBLE_COLS
    scroll_pos = 0
    frame_ctr  = 0
    color_ctr  = 0
    color_idx  = 0
    color      = COLOR_TABLE[0]

    sys.stdout.write(CLEAR + HIDE)
    sys.stdout.flush()

    frame_dt = 1.0 / FRAME_HZ
    next_tick = time.monotonic()

    try:
        while True:
            # --- update_color: step every COLOR_DELAY frames ---------------
            color_ctr += 1
            if color_ctr >= COLOR_DELAY:
                color_ctr = 0
                color = COLOR_TABLE[color_idx]
                color_idx = (color_idx + 1) % len(COLOR_TABLE)

            # --- frame divider --------------------------------------------
            frame_ctr += 1
            if frame_ctr >= FRAME_SKIP:
                frame_ctr = 0
                # do_scroll: shift left and append next message char
                buf.pop(0)
                ch = MESSAGE[scroll_pos]
                buf.append(ch)
                scroll_pos = (scroll_pos + 1) % len(MESSAGE)

            # --- paint the row --------------------------------------------
            line = "".join(buf)
            sys.stdout.write(move(SCROLL_ROW, 1) + fg(color) + line + RESET)
            sys.stdout.flush()

            # --- raster-style frame sync (sleep to next tick) -------------
            next_tick += frame_dt
            delay = next_tick - time.monotonic()
            if delay > 0:
                time.sleep(delay)
            else:
                next_tick = time.monotonic()
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write(RESET + SHOW + move(SCROLL_ROW + 2, 1))
        sys.stdout.flush()


if __name__ == "__main__":
    main()
