            .cpu    "65c02"

; DOS Wedge - @ command for IEC device access
; Usage:
;   @           - Read and display IEC error channel (like iecstat)
;   @<cmd>      - Send command to IEC device (e.g., @I, @V, @N:DISK)
;   @ <cmd>     - Send command to IEC device (with space)

wedge       .namespace

            .section    code

cmd
          ; Check if we're on an IEC drive first
            jsr     iec.check_iec
            bcs     _done

          ; Get length of first token (the @ or @CMD part)
            lda     #0
            jsr     readline.token_length
            cmp     #2
            bcs     _inline_cmd         ; @CMD style (no space)

          ; Token is just "@" - check for second token
            lda     readline.token_count
            cmp     #2
            bcs     _space_cmd          ; @ CMD style (with space)

          ; Just "@" alone - read status
            jmp     iec.stat_cmd

_space_cmd
          ; "@ CMD" style - use existing send_cmd
            jmp     iec.send_cmd

_inline_cmd
          ; "@CMD" style - command follows @ directly
          ; Need to send the part after @ to IEC

          ; Set the drive
            lda     drive
            sta     kernel.args.fs.write_block.drive

          ; Set a cookie
            lda     #0
            sta     kernel.args.fs.write_block.cookie

          ; Set the command buffer (token 0, skip the @)
            lda     readline.tokens+0
            inc     a                   ; Skip the '@'
            sta     kernel.args.fs.write_block.buf+0
            lda     #>readline.buf
            sta     kernel.args.fs.write_block.buf+1

          ; Get command length (token length - 1 for the @)
            lda     #0
            jsr     readline.token_length
            dec     a                   ; Subtract 1 for the @
            sta     kernel.args.fs.write_block.buflen

          ; Call the kernel
            jsr     kernel.FileSystem.WriteBlock
            bcs     _err

          ; Wait for the response event
_loop
            jsr     kernel.NextEvent
            bcs     _loop

            lda     event.type

            cmp     #kernel.event.fs.WROTE
            beq     _ok

            cmp     #kernel.event.fs.ERROR
            beq     _err

          ; Unknown event, keep waiting
            bra     _loop

_ok
            ldx     #<_ok_msg
            lda     #>_ok_msg
            jsr     strings.puts_zero

          ; Read and show the resulting status
            jsr     iec.stat_cmd
_done
            rts

_err
            ldx     #<_err_msg
            lda     #>_err_msg
            jsr     strings.puts_zero
            sec
            rts

_ok_msg     .text   "OK - ", 0
_err_msg    .text   "IEC error", $0a, 0

            .send
            .endn
