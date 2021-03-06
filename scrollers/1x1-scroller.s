;
; scrolling 1x1 test
; Compile it using cc65: http://cc65.github.io/cc65/
;
; Command line:
;    cl65 -o file.prg -u __EXEHDR__ -t c64 -C c64-asm.cfg 1x1-scroller.s
;

.macpack cbm

; exported by the linker
.import __SIDMUSIC_LOAD__

; Use 1 to enable raster-debugging in music
DEBUG = 1

SCROLL_AT_LINE = 12
RASTER_START = 50

SCREEN = $0400 + SCROLL_AT_LINE * 40
SPEED = 1

MUSIC_INIT = __SIDMUSIC_LOAD__
MUSIC_PLAY = __SIDMUSIC_LOAD__ + 3

.code

        jsr $ff81           ; Init screen

        ; default is #$15  #00010101
        lda #%00011110
        sta $d018           ; Logo font at $3800

        sei

        ; turn off cia interrups
        lda #$7f
        sta $dc0d
        sta $dd0d

        lda $d01a       ; enable raster irq
        ora #$01
        sta $d01a

        lda $d011       ; clear high bit of raster line
        and #$7f
        sta $d011

        ; irq handler
        lda #<irq1
        sta $0314
        lda #>irq1
        sta $0315

        ; raster interrupt
        lda #RASTER_START+SCROLL_AT_LINE*8
        sta $d012

        ; clear interrupts and ACK irq
        lda $dc0d
        lda $dd0d
        asl $d019

        lda #$00
        tax
        tay

        ; init music
        lda #0
        jsr MUSIC_INIT

        cli


mainloop:
        lda sync   ; init sync
        and #$00
        sta sync
@loop:	cmp sync
        beq @loop

        jsr scroll
        jmp mainloop

irq1:
        asl $d019

        lda #<irq2
        sta $0314
        lda #>irq2
        sta $0315

        ; FIXME Raster is not stable.
        lda #RASTER_START+(SCROLL_AT_LINE+1)*8
        sta $d012

        lda #0
        sta $d020

        lda scroll_x
        sta $d016

        jmp $ea81


irq2:
        asl $d019

        lda #<irq1
        sta $0314
        lda #>irq1
        sta $0315

        ; FIXME If I don't add the -1 it won't scroll correctly.
        ; FIXME Raster is not stable.
        lda #RASTER_START+SCROLL_AT_LINE*8-1
        sta $d012

        lda #1
        sta $d020

        ; no scrolling, 40 cols
        lda #%00001000
        sta $d016

        inc sync

.if DEBUG = 1
        inc $d020
.endif

        jsr MUSIC_PLAY

.if DEBUG = 1
        dec $d020
.endif

        jmp $ea31


scroll:
        ; speed control
        ldx scroll_x

.repeat SPEED
        dec scroll_x
.endrepeat

        lda scroll_x
        and #07
        sta scroll_x

        cpx scroll_x
        bcc @dothescroll
        rts

@dothescroll:

        ; move the chars to the left
        ldx #0
@loop:	lda SCREEN+1,x
        sta SCREEN,x
        inx
        cpx #39
        bne @loop

        ; put next char in column 40
        ldx lines_scrolled
        lda label,x
        cmp #$ff
        bne @printchar

        ; reached $ff ? Then start from the beginning
        ldx #0
        stx lines_scrolled
        lda label

@printchar:
        sta SCREEN+39
        inx
        stx lines_scrolled

endscroll:
        rts


;
; Data
;
.data
sync:           .byte 1
scroll_x:       .byte 7
speed:          .byte SPEED
lines_scrolled: .byte 0

label:
            scrcode "Hello World! abc DEF ghi JKL mno PQR stu VWX yz 01234567890 ()."
            .byte $ff


.segment "CHARSET"
        ; .import binary "fonts/rambo_font.ctm",24    // skip first 24 bytes which is CharPad format information
        ; .import c64 "fonts/yie_are_kung_fu.64c"
        ; .import c64 "fonts/devils_collection_01.64c"
        .incbin "fonts/1x1-inverted-chars.raw"

.segment "SIDMUSIC"
         .incbin "music.sid",$7e
