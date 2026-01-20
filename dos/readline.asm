            .cpu    "65c02"

readline    .namespace

OFFSET = 3
MAX = 78-OFFSET
MAX_TOKENS = 8
HISTORY_SIZE = 8        ; Number of commands to store
HISTORY_LEN = 80        ; Max length per command (including null)
KEY_UP = $b6            ; Raw key code for cursor up
KEY_DOWN = $b7          ; Raw key code for cursor down

            .section    dp
line        .word       ?
            .send

            .section    data
cursor      .byte       ?
length      .byte       ?
tokens      .fill       MAX_TOKENS
token_count .byte       ?   ; Token count
hist_count  .byte       ?   ; Number of commands in history (0-HISTORY_SIZE)
hist_pos    .byte       ?   ; Current position when browsing (0=newest)
hist_head   .byte       ?   ; Index of next slot to write (circular buffer)
hist_active .byte       ?   ; Non-zero if browsing history
saved_len   .byte       ?   ; Saved length before browsing
            .send

            .section    kupdata
buf         .fill       128 ; Only need 80, must be page aligned
argv        .fill       (readline.MAX_TOKENS+1)*2
history     .fill       HISTORY_SIZE * HISTORY_LEN  ; Circular history buffer
saved_buf   .fill       HISTORY_LEN ; Saved current line when browsing
            .send

            .section    code

; Initialize history - call once at startup
init
            stz     hist_count
            stz     hist_head
            stz     hist_pos
            stz     hist_active
            stz     saved_len
            rts

read
            stz     cursor
            stz     length
            stz     hist_active     ; Not browsing history
_loop
            jsr     refresh
_event
            jsr     kernel.NextEvent
            bcs     _event

            lda     event.type
            cmp     #kernel.event.key.PRESSED
            beq     _kbd
            bra     _event

_kbd
          ; Check for history navigation keys first (via raw key code)
            lda     event.key.raw
            cmp     #KEY_UP
            beq     _hist_prev
            cmp     #KEY_DOWN
            beq     _hist_next

            lda     event.key.ascii
            cmp     #13
            beq     _done
            cmp     #32
            bcc     _ctrl
            jsr     insert
            bra     _loop
_ctrl
            jsr     ctrl
            bra     _loop
_hist_prev
            jsr     history_prev
            bra     _loop
_hist_next
            jsr     history_next
            bra     _loop
_done
            jsr     history_save    ; Save command to history
            jmp     put_cr          ; Output newline (A was clobbered by history_save)

ctrl
            cmp     #'B'-64
            beq     left
            cmp     #'F'-64
            beq     right
            cmp     #'A'-64
            beq     home
            cmp     #'E'-64
            beq     end
            cmp     #'H'-64
            beq     back
            cmp     #'D'-64
            beq     del
            cmp     #'K'-64
            beq     kill
            rts

kill
            lda     cursor
            cmp     length
            beq     _done
            jsr     del
            jsr     refresh
            bra     kill
_done       rts

left
            lda     cursor
            beq     _done
            dec     cursor
_done
            rts
right
            lda     cursor
            cmp     length
            bcs     _done
            inc     cursor
_done
            rts
home
            stz     cursor
            rts
end
            lda     length
            sta     cursor
            rts
del
            ldy     cursor
            cpy     length
            bcs     _done
_loop
            lda     buf+1,y
            sta     buf,y
            iny
            cpy     length
            bne     _loop
            dec     length
_done
            rts

back
            ldy     cursor
            beq     _done
            cpy     length
            beq     _simple
_loop
            lda     buf,y
            sta     buf-1,y
            iny
            cpy     length
            bne     _loop
_simple
            dec     cursor
            dec     length
            rts
_done
            rts

insert
            ldy     length
            cpy     #MAX
            beq     _done

            ldy     cursor
            cpy     length
            beq     _insert

            pha
            ldy     length
_loop
            lda     buf-1,y
            sta     buf,y
            dey
            cpy     cursor
            bne     _loop
            pla

_insert
            sta     buf,y
            inc     cursor
            inc     length
_done
            jmp     refresh

refresh
            phy

            jsr     display.cursor_off

            lda     display.screen+0
            sta     line+0
            lda     display.screen+1
            sta     line+1

            ldy     #line
            lda     #OFFSET
            jsr     display.add

            ldy     #0
_loop
            cpy     length
            beq     _done
            lda     buf,y
            sta     (line),y
            iny
            bra     _loop
_done
          ; Clear from length to MAX to erase leftover characters
            lda     #$20
_clear
            cpy     #MAX
            bcs     _cleared
            sta     (line),y
            iny
            bra     _clear
_cleared
            clc
            lda     cursor
            adc     #OFFSET
            sta     display.cursor
            jsr     display.cursor_on

            ply
            rts

populate_arguments
          ; Populate argv array
            ldx     #0
            ldy     #0
_copy_token
            lda     readline.tokens,y
            sta     argv,x
            inx
            lda     #>readline.buf
            sta     argv,x
            inx
            iny
            cpy     readline.token_count
            bne     _copy_token

          ; null terminate argv array
            stz     argv,x
            stz     argv+1,x

          ; Set ext and extlen to argv and argc
            lda     #<argv
            sta     kernel.args.ext
            lda     #>argv
            sta     kernel.args.ext+1
            lda     readline.token_count
            asl     a
            sta     kernel.args.extlen

            rts

tokenize
            ldx     #0      ; Token count
            ldy     #0      ; Start of line
_loop
            jsr     skip_white
            cpy     length
            bcs     _done

            lda     buf,y
            cmp     #'"'
            bne     _not_quoted

            iny
            tya
            sta     tokens,x
            jsr     skip_to_quote
            bra     _continue_next_token

_not_quoted
            tya
            sta     tokens,x
            jsr     skip_to_white

_continue_next_token
            inx
            cpy     length
            bcs     _done

            lda     #0
            sta     buf,y
            iny

            cpx     #MAX_TOKENS
            bne     _loop
_done
            lda     #0
            sta     buf,y
            stx     token_count
            rts

skip_white
            cpy     length
            bcs     _done
            lda     buf,y
            cmp     #' '
            bne     _done
            iny
            bra     skip_white
_done
            rts

skip_to_white
            cpy     length
            bcs     _done
            lda     buf,y
            cmp     #' '
            beq     _done
            iny
            bra     skip_to_white
_done
            rts

skip_to_quote
            cpy     length
            bcs     _done
            lda     buf,y
            cmp     #'"'
            beq     _done
            iny
            bra     skip_to_quote
_done
            rts

token_length
    ; IN: A = token#
    ; OUT: A=token length

            phx
            phy

            cmp     token_count
            bcs     _out

            tax
            ldy     tokens,x

            ldx     #0
_loop       lda     buf,y
            beq     _done
            inx
            iny
            bra     _loop
_done
            txa
_out
            ply
            plx
            cmp     #0
            rts


parse_drive
	; IN: A = token#
            tax

          ; Make sure we have an argument
            cmp     token_count
            bge     _default

          ; Make sure it's at least 2 characters
            jsr     token_length
            cmp     #2
            bcc     _default

          ; Consider only <drive><colon> prefixen
            ldy     tokens,x
            lda     buf+1,y
            cmp     #':'
            bne     _default

          ; Remove the drive spec from the token
            inc     tokens,x
            inc     tokens,x

          ; Consider the first character a drive;
          ; other layers can check if it's valid
            lda     buf,y
            and     #7

            rts

_default
            lda     drive   ; Return the default
            rts

; ============================================================
; History functions
; ============================================================

; Lookup table for history slot offsets (slot * 80)
hist_offset_lo  .byte   $00, $50, $A0, $F0, $40, $90, $E0, $30
hist_offset_hi  .byte   $00, $00, $00, $00, $01, $01, $01, $02

; history_save - Save current command to history buffer
; Called when Enter is pressed
history_save
            lda     length
            beq     _done           ; Don't save empty commands

          ; Calculate slot index: hist_head is next write position
            ldx     hist_head

          ; Copy buf to history[slot]
            lda     hist_offset_lo,x
            clc
            adc     #<history
            sta     line+0
            lda     hist_offset_hi,x
            adc     #>history
            sta     line+1

            ldy     #0
_copy       lda     buf,y
            sta     (line),y
            iny
            cpy     length
            bne     _copy
            lda     #0              ; Null terminate
            sta     (line),y

          ; Advance head: hist_head = (hist_head + 1) & 7
            lda     hist_head
            inc     a
            and     #HISTORY_SIZE-1
            sta     hist_head

          ; Increment count if not at max
            lda     hist_count
            cmp     #HISTORY_SIZE
            bcs     _done
            inc     hist_count
_done
            stz     hist_active     ; Reset browsing state
            rts

; history_prev - Navigate to older command (UP key)
history_prev
            lda     hist_count
            beq     _done           ; No history, nothing to do

          ; If not currently browsing, save current line first
            lda     hist_active
            bne     _already_browsing

          ; Save current line to saved_buf
            ldy     #0
_save       cpy     length
            beq     _save_done
            lda     buf,y
            sta     saved_buf,y
            iny
            bra     _save
_save_done  lda     #0
            sta     saved_buf,y
            lda     length
            sta     saved_len

          ; Start browsing at position 0 (most recent)
            stz     hist_pos
            lda     #1
            sta     hist_active
            bra     _load

_already_browsing
          ; Check if we can go further back
            lda     hist_pos
            inc     a
            cmp     hist_count
            bcs     _done           ; Already at oldest
            sta     hist_pos

_load       jsr     history_load
_done       rts

; history_next - Navigate to newer command (DOWN key)
history_next
            lda     hist_active
            beq     _done           ; Not browsing, nothing to do

            lda     hist_pos
            beq     _restore        ; At newest, restore original line

          ; Go to newer entry
            dec     hist_pos
            jsr     history_load
            rts

_restore  ; Restore saved line
            ldy     #0
_copy       cpy     saved_len
            beq     _copy_done
            lda     saved_buf,y
            sta     buf,y
            iny
            bra     _copy
_copy_done
            lda     saved_len
            sta     length
            sta     cursor          ; Position cursor at end
            stz     hist_active
_done       rts

; history_load - Load history entry at hist_pos into buf
; Internal helper
history_load
          ; Calculate actual slot: (hist_head - 1 - hist_pos + 8) & 7
            lda     hist_head
            sec
            sbc     #1
            sec
            sbc     hist_pos
            and     #HISTORY_SIZE-1
            tax

          ; Get history buffer address
            lda     hist_offset_lo,x
            clc
            adc     #<history
            sta     line+0
            lda     hist_offset_hi,x
            adc     #>history
            sta     line+1

          ; Copy to buf and calculate length
            ldy     #0
_copy       lda     (line),y
            beq     _done
            sta     buf,y
            iny
            cpy     #HISTORY_LEN-1
            bne     _copy
_done
            sty     length
            sty     cursor          ; Position cursor at end
            rts

            .send
            .endn

