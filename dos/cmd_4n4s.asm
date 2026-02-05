            .cpu    "65c02"

; NES/SNES controller test (4 NES + 4 SNES = 4n4s)
; Usage: 4n4s - displays controller state, press any key to exit

fnx4n4s     .namespace

; Controller registers
NES_CTRL    = $D880         ; Write: control register
NES_STAT    = $D880         ; Read: status register
PAD0        = $D884         ; Controller 0 (NES: all, SNES: B,Y,Sel,Start,U,D,L,R)
PAD0_S      = $D885         ; Controller 0 SNES extended (A,X,L,R)
PAD1        = $D886         ; Controller 1
PAD1_S      = $D887         ; Controller 1 SNES extended
PAD2        = $D888         ; Controller 2
PAD2_S      = $D889         ; Controller 2 SNES extended
PAD3        = $D88A         ; Controller 3
PAD3_S      = $D88B         ; Controller 3 SNES extended

; Control register bits (NES_CTRL write)
NES_EN     = $01           ; Bit 0: Enable
SNES_MODE  = $04           ; Bit 2: 1=SNES, 0=NES
NES_TRIG   = $80           ; Bit 7: Trigger polling

; Status register bits (NES_STAT read)
NES_DONE   = $40           ; Bit 6: Polling complete

; NES button bits (active low: 0 = pressed)
; Order: A, B, Select, Start, Up, Down, Left, Right
NES_A       = $80
NES_B       = $40
NES_SELECT  = $20
NES_START   = $10
NES_UP      = $08
NES_DOWN    = $04
NES_LEFT    = $02
NES_RIGHT   = $01

; SNES primary byte (PAD0-3): B, Y, Select, Start, Up, Down, Left, Right
SNES_B      = $80
SNES_Y      = $40
SNES_SELECT = $20
SNES_START  = $10
SNES_UP     = $08
SNES_DOWN   = $04
SNES_LEFT   = $02
SNES_RIGHT  = $01

; SNES secondary byte (PAD0_S-PAD3_S): A, X, L, R (active low, bits 3-0)
SNES_A      = $08
SNES_X      = $04
SNES_L      = $02
SNES_R      = $01

            .section    dp
; NES controller state (primary byte only, no extended)
nes_last0   .byte   ?       ; NES controller 0 state
nes_last1   .byte   ?       ; NES controller 1 state
nes_last2   .byte   ?       ; NES controller 2 state
nes_last3   .byte   ?       ; NES controller 3 state
; SNES controller state (primary + extended bytes)
snes_last0  .byte   ?       ; SNES controller 0 primary
snes_last0_s .byte  ?       ; SNES controller 0 extended
snes_last1  .byte   ?       ; SNES controller 1 primary
snes_last1_s .byte  ?       ; SNES controller 1 extended
snes_last2  .byte   ?       ; SNES controller 2 primary
snes_last2_s .byte  ?       ; SNES controller 2 extended
snes_last3  .byte   ?       ; SNES controller 3 primary
snes_last3_s .byte  ?       ; SNES controller 3 extended
buttons     .byte   ?       ; Current button state for display (primary)
buttons_s   .byte   ?       ; Current button state (secondary/SNES extended)
            .send

            .section    code

cmd
            lda     #>_header
            ldx     #<_header
            jsr     strings.puts_zero

          ; Initialize NES last state (all buttons released = $FF)
            lda     #$FF
            sta     nes_last0
            sta     nes_last1
            sta     nes_last2
            sta     nes_last3

          ; Initialize SNES last state
          ; Primary bytes: $FF (all 8 buttons released)
          ; Secondary bytes: $0F (only bits 3-0 used, upper bits read as 0)
            sta     snes_last0
            sta     snes_last1
            sta     snes_last2
            sta     snes_last3
            lda     #$0F
            sta     snes_last0_s
            sta     snes_last1_s
            sta     snes_last2_s
            sta     snes_last3_s

          ; Save I/O control and enable I/O page 0
            lda     io_ctrl
            pha
            stz     io_ctrl

            ;jsr     display.cursor_off

_loop
          ; Check for keypress to exit
            jsr     kernel.NextEvent
            bcs     _poll_nes

            lda     event.type
            cmp     #kernel.event.key.PRESSED
            bne     _poll_nes
            jmp     _done

; ============== Poll NES mode ==============
_poll_nes
          ; Trigger NES controller polling (mode = 0)
            lda     #NES_EN             ; NES mode (bit 2 = 0)
            stz     io_ctrl
            sta     NES_CTRL


            ora     #NES_TRIG
            sta     NES_CTRL

          ; Small delay (NOPs for timing)
            nop
            nop

_wait_nes
            lda     NES_STAT
            and     #NES_DONE
            cmp     #NES_DONE
            bne     _wait_nes

          ; Check NES controller 0 for changes
            stz     io_ctrl
            lda     PAD0
            cmp     nes_last0
            beq     _nes_check1

          ; Update last state and show
            sta     nes_last0
            jsr     _show_nes_controller0
            stz     io_ctrl

_nes_check1
          ; Check NES controller 1 for changes
            stz     io_ctrl
            lda     PAD1
            cmp     nes_last1
            beq     _nes_check2

          ; Update last state and show
            sta     nes_last1
            jsr     _show_nes_controller1
            stz     io_ctrl

_nes_check2
          ; Check NES controller 2 for changes
            stz     io_ctrl
            lda     PAD2
            cmp     nes_last2
            beq     _nes_check3

          ; Update last state and show
            sta     nes_last2
            jsr     _show_nes_controller2
            stz     io_ctrl

_nes_check3
          ; Check NES controller 3 for changes
            stz     io_ctrl
            lda     PAD3
            cmp     nes_last3
            beq     _poll_snes

          ; Update last state and show
            sta     nes_last3
            jsr     _show_nes_controller3
            stz     io_ctrl

; ============== Poll SNES mode ==============
_poll_snes
          ; Trigger SNES controller polling (mode = SNES_MODE)
            lda     #NES_EN | SNES_MODE
            stz     io_ctrl
            sta     NES_CTRL

            ora     #NES_TRIG
            sta     NES_CTRL

          ; Small delay (NOPs for timing)
            nop
            nop

_wait_snes
            lda     NES_STAT
            and     #NES_DONE
            cmp     #NES_DONE
            bne     _wait_snes

          ; Check SNES controller 0 for changes
            stz     io_ctrl
            lda     PAD0
            cmp     snes_last0
            bne     _snes_changed0
            lda     PAD0_S
            cmp     snes_last0_s
            beq     _snes_check1

_snes_changed0
          ; Update last state and show
            lda     PAD0
            sta     snes_last0
            lda     PAD0_S
            sta     snes_last0_s
            jsr     _show_snes_controller0
            stz     io_ctrl

_snes_check1
          ; Check SNES controller 1 for changes
            stz     io_ctrl
            lda     PAD1
            cmp     snes_last1
            bne     _snes_changed1
            lda     PAD1_S
            cmp     snes_last1_s
            beq     _snes_check2

_snes_changed1
          ; Update last state and show
            lda     PAD1
            sta     snes_last1
            lda     PAD1_S
            sta     snes_last1_s
            jsr     _show_snes_controller1
            stz     io_ctrl

_snes_check2
          ; Check SNES controller 2 for changes
            stz     io_ctrl
            lda     PAD2
            cmp     snes_last2
            bne     _snes_changed2
            lda     PAD2_S
            cmp     snes_last2_s
            beq     _snes_check3

_snes_changed2
          ; Update last state and show
            lda     PAD2
            sta     snes_last2
            lda     PAD2_S
            sta     snes_last2_s
            jsr     _show_snes_controller2
            stz     io_ctrl

_snes_check3
          ; Check SNES controller 3 for changes
            stz     io_ctrl
            lda     PAD3
            cmp     snes_last3
            bne     _snes_changed3
            lda     PAD3_S
            cmp     snes_last3_s
            beq     _next

_snes_changed3
          ; Update last state and show
            lda     PAD3
            sta     snes_last3
            lda     PAD3_S
            sta     snes_last3_s
            jsr     _show_snes_controller3
            stz     io_ctrl

_next
            jmp     _loop

_done
          ; Disable controllers
            ;stz     NES_CTRL

          ; Restore I/O control
            pla
            sta     io_ctrl
            jsr     put_cr
            clc
            ;jsr     display.cursor_on
            rts

; ============== NES Display Functions ==============

_show_nes_controller0
            lda     #>_nes_ctrl0
            ldx     #<_nes_ctrl0
            jsr     strings.puts_zero
            lda     nes_last0
            jsr     _show_nes_buttons
            rts

_show_nes_controller1
            lda     #>_nes_ctrl1
            ldx     #<_nes_ctrl1
            jsr     strings.puts_zero
            lda     nes_last1
            jsr     _show_nes_buttons
            rts

_show_nes_controller2
            lda     #>_nes_ctrl2
            ldx     #<_nes_ctrl2
            jsr     strings.puts_zero
            lda     nes_last2
            jsr     _show_nes_buttons
            rts

_show_nes_controller3
            lda     #>_nes_ctrl3
            ldx     #<_nes_ctrl3
            jsr     strings.puts_zero
            lda     nes_last3
            jsr     _show_nes_buttons
            rts

; Show NES button states (8 buttons: A, B, Select, Start, U, D, L, R)
; A = button byte (active low: 0 = pressed)
_show_nes_buttons
            sta     buttons     ; Save for bit testing

          ; D-pad: Up, Down, Left, Right (bits 3,2,1,0)
            lda     #'U'
            ldx     #$08
            jsr     _show_bit

            lda     #'D'
            ldx     #$04
            jsr     _show_bit

            lda     #'L'
            ldx     #$02
            jsr     _show_bit

            lda     #'R'
            ldx     #$01
            jsr     _show_bit

            lda     #' '
            jsr     putc

          ; NES: A is bit 7 of primary
            lda     #'A'
            ldx     #$80
            jsr     _show_bit

          ; NES: B is bit 6
            lda     #'B'
            ldx     #$40
            jsr     _show_bit

          ; Select (bit 5 = $20)
            lda     #'e'
            ldx     #$20
            jsr     _show_bit

          ; Start (bit 4 = $10)
            lda     #'S'
            ldx     #$10
            jsr     _show_bit

            jmp     put_cr

; ============== SNES Display Functions ==============

_show_snes_controller0
            lda     #>_snes_ctrl0
            ldx     #<_snes_ctrl0
            jsr     strings.puts_zero
            lda     snes_last0
            ldx     snes_last0_s
            jsr     _show_snes_buttons
            rts

_show_snes_controller1
            lda     #>_snes_ctrl1
            ldx     #<_snes_ctrl1
            jsr     strings.puts_zero
            lda     snes_last1
            ldx     snes_last1_s
            jsr     _show_snes_buttons
            rts

_show_snes_controller2
            lda     #>_snes_ctrl2
            ldx     #<_snes_ctrl2
            jsr     strings.puts_zero
            lda     snes_last2
            ldx     snes_last2_s
            jsr     _show_snes_buttons
            rts

_show_snes_controller3
            lda     #>_snes_ctrl3
            ldx     #<_snes_ctrl3
            jsr     strings.puts_zero
            lda     snes_last3
            ldx     snes_last3_s
            jsr     _show_snes_buttons
            rts

; Show SNES button states (12 buttons: A, B, X, Y, L, R, Select, Start, U, D, L, R)
; A = primary button byte, X = secondary (extended)
; Buttons are active low (0 = pressed)
_show_snes_buttons
            sta     buttons     ; Save primary for bit testing
            stx     buttons_s   ; Save secondary

          ; D-pad: Up, Down, Left, Right (bits 3,2,1,0)
            lda     #'U'
            ldx     #$08
            jsr     _show_bit

            lda     #'D'
            ldx     #$04
            jsr     _show_bit

            lda     #'L'
            ldx     #$02
            jsr     _show_bit

            lda     #'R'
            ldx     #$01
            jsr     _show_bit

            lda     #' '
            jsr     putc

          ; SNES: A is bit 3 of secondary
            lda     #'A'
            ldx     #$08
            jsr     _show_bit_s

          ; SNES: B is bit 7 of primary
            lda     #'B'
            ldx     #$80
            jsr     _show_bit

          ; Select (bit 5 = $20)
            lda     #'e'
            ldx     #$20
            jsr     _show_bit

          ; Start (bit 4 = $10)
            lda     #'S'
            ldx     #$10
            jsr     _show_bit

            lda     #' '
            jsr     putc

          ; Y (bit 6 of primary)
            lda     #'Y'
            ldx     #$40
            jsr     _show_bit

          ; X (bit 2 of secondary)
            lda     #'X'
            ldx     #$04
            jsr     _show_bit_s

          ; L (bit 1 of secondary)
            lda     #'L'
            ldx     #$02
            jsr     _show_bit_s

          ; R (bit 0 of secondary)
            lda     #'R'
            ldx     #$01
            jsr     _show_bit_s

            jmp     put_cr

; Show a button state from primary byte
; A = char to show when pressed
; X = bit mask to test
; Buttons are active low (0 = pressed)
_show_bit
            pha
            txa
            and     buttons
            beq     _pressed        ; Bit clear = pressed
            pla
            lda     #'-'
            jmp     putc
_pressed
            pla
            jmp     putc

; Show a button state from secondary byte (SNES extended)
_show_bit_s
            pha
            txa
            and     buttons_s
            beq     _pressed_s      ; Bit clear = pressed
            pla
            lda     #'-'
            jmp     putc
_pressed_s
            pla
            jmp     putc

_header     .text   "4N4S Controller Test (press any key to exit)", $0a
            .text   "NES (N1-N4): UDLR ABeS   SNES (S1-S4): UDLR ABeS YXLR", $0a, 0
_nes_ctrl0  .text   "N1: ", 0
_nes_ctrl1  .text   "N2: ", 0
_nes_ctrl2  .text   "N3: ", 0
_nes_ctrl3  .text   "N4: ", 0
_snes_ctrl0 .text   "S1: ", 0
_snes_ctrl1 .text   "S2: ", 0
_snes_ctrl2 .text   "S3: ", 0
_snes_ctrl3 .text   "S4: ", 0

            .send
            .endn
