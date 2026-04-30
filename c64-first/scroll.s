; ----------------------------------------------------------------------------
; scroll.s - C64 horizontal text scroller demo
; Build:  ca65 -t c64 scroll.s -o scroll.o
;         ld65 -t c64 scroll.o -o scroll.prg -C c64-asm.cfg
; Run:    x64sc scroll.prg
; ----------------------------------------------------------------------------

.setcpu "6502"

; --- Hardware addresses ----------------------------------------------------
VIC_BORDER  = $d020
VIC_BG      = $d021
VIC_RASTER  = $d012
VIC_CTRL1   = $d011         ; bit 7 = raster bit 8
VIC_CTRL2   = $d016         ; bits 0-2 = X scroll, bit 3 = 40-col select
SCREEN_RAM  = $0400
SCROLL_ROW  = SCREEN_RAM + 40*12   ; row 12
COLOR_RAM   = $d800
COLOR_ROW   = COLOR_RAM  + 40*12

; --- PRG load address ------------------------------------------------------
.segment "LOADADDR"
        .word $0801

; --- BASIC stub: 10 SYS 2061 -----------------------------------------------
.segment "EXEHDR"
        .word basic_end          ; $0801: ptr to next BASIC line
        .word 10                 ; $0803: line number 10
        .byte $9e                ; $0805: SYS token
        .byte "2061", 0          ; $0806-$080a: "2061" + end-of-line
basic_end:
        .word 0                  ; $080b-$080c: end of BASIC program
                                 ; $080d: start of CODE  ($080d = 2061)

.segment "CODE"

start:
        sei
        lda #$00
        sta VIC_BORDER
        sta VIC_BG

        ; Clear screen with spaces and set color
        ldx #$00
clr:
        lda #$20                 ; space (screen code)
        sta SCREEN_RAM + $000,x
        sta SCREEN_RAM + $100,x
        sta SCREEN_RAM + $200,x
        sta SCREEN_RAM + $300,x
        lda #$0e                 ; light blue
        sta COLOR_RAM  + $000,x
        sta COLOR_RAM  + $100,x
        sta COLOR_RAM  + $200,x
        sta COLOR_RAM  + $300,x
        inx
        bne clr

        lda #0
        sta scroll_pos
        sta frame_ctr
        sta color_idx
        sta color_ctr

        ; Switch to 38-column mode so the scroll edges are hidden by border
        lda VIC_CTRL2
        and #$f7                 ; clear bit 3 (CSEL) -> 38 columns
        ora #$07                 ; start xscroll at 7
        sta VIC_CTRL2
        lda #7
        sta xscroll

mainloop:
        ; Wait for raster line $f8 (below visible area) - one frame tick
wait1:
        lda VIC_RASTER
        cmp #$f8
        bne wait1
wait2:
        lda VIC_RASTER
        cmp #$f8
        beq wait2

        jsr update_color

        ; Frame divider so the smooth scroll is calm and readable.
        ; FRAME_SKIP=2 -> update every other frame (~25 px/sec)
        inc frame_ctr
        lda frame_ctr
        cmp #FRAME_SKIP
        bcc mainloop
        lda #0
        sta frame_ctr

        ; Smooth scroll: decrement xscroll (0-7). When it wraps, shift chars.
        dec xscroll
        lda xscroll
        bpl no_wrap
        lda #7
        sta xscroll
        jsr do_scroll
no_wrap:
        ; Write xscroll into $d016 lower 3 bits, keep CSEL=0 (38 col)
        lda VIC_CTRL2
        and #$f8
        ora xscroll
        sta VIC_CTRL2
        jmp mainloop

FRAME_SKIP = 1                   ; pixel step every N frames (1 = 50 px/sec)

; ---------------------------------------------------------------------------
; do_scroll: shift the scroll row one char to the left and append next char
; ---------------------------------------------------------------------------
do_scroll:
        ldx #0
shift:
        lda SCROLL_ROW+1,x
        sta SCROLL_ROW,x
        inx
        cpx #39
        bne shift

        ; Fetch next character from message
        ldx scroll_pos
        lda message,x
        bne not_end
        ; hit terminator -> wrap
        ldx #0
        stx scroll_pos
        lda message
not_end:
        jsr petscii_to_screen
        sta SCROLL_ROW+39
        inc scroll_pos
        rts

; ---------------------------------------------------------------------------
; update_color: cycle the scroll row color through a black->white->black
; ping-pong every COLOR_DELAY frames, painting all 40 chars of COLOR_ROW.
; ---------------------------------------------------------------------------
COLOR_DELAY = 6                  ; frames per color step

update_color:
        inc color_ctr
        lda color_ctr
        cmp #COLOR_DELAY
        bcc uc_done
        lda #0
        sta color_ctr

        ldx color_idx
        lda color_table,x
        ldy #39
uc_paint:
        sta COLOR_ROW,y
        dey
        bpl uc_paint

        inx
        cpx #COLOR_TABLE_LEN
        bne uc_save
        ldx #0
uc_save:
        stx color_idx
uc_done:
        rts

; Ping-pong fade: black -> dark grey -> mid grey -> light grey -> white
; -> light grey -> mid grey -> dark grey -> (loop)
color_table:
        .byte $00, $0b, $0c, $0f, $01, $0f, $0c, $0b
COLOR_TABLE_LEN = * - color_table

; ---------------------------------------------------------------------------
; petscii_to_screen: convert ASCII byte in A to a C64 screen code
;   $20-$3F  ->  unchanged (space, punctuation, digits)
;   $40-$5F  ->  -$40   (uppercase A-Z + symbols -> $00-$1F)
;   $60-$7F  ->  -$60   (lowercase a-z folded onto A-Z slots)
;   anything else -> unchanged
; ---------------------------------------------------------------------------
petscii_to_screen:
        cmp #$20
        bcc psc_done
        cmp #$40
        bcc psc_done             ; $20-$3F map 1:1
        cmp #$60
        bcc psc_upper
        cmp #$80
        bcs psc_done
        sec
        sbc #$60                 ; $60-$7F -> $00-$1F
        rts
psc_upper:
        sec
        sbc #$40                 ; $40-$5F -> $00-$1F
psc_done:
        rts

; ---------------------------------------------------------------------------
.segment "DATA"
scroll_pos:  .byte 0
frame_ctr:   .byte 0
xscroll:     .byte 0
color_idx:   .byte 0
color_ctr:   .byte 0

message:
        .byte "                                        "
        .byte "Hello           "
        .byte 0
