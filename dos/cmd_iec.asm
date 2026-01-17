            .cpu    "65c02"

; IEC device status and command channel access
; Usage:
;   iecstat         - Read and display IEC error channel
;   ieccmd <cmd>    - Send command to IEC command channel

iec         .namespace

            .section    code

; Check if current drive is IEC (drive 1 or 2)
; Returns: carry set if not IEC
check_iec
            lda     drive
            beq     _not_iec        ; Drive 0 is SD card
            cmp     #3
            bcs     _not_iec        ; Drive 3+ not supported
            clc
            rts
_not_iec
            ldx     #<_not_iec_msg
            lda     #>_not_iec_msg
            jsr     strings.puts_zero
            sec
            rts

_not_iec_msg .text  "Not an IEC drive (use 1: or 2:)", $0a, 0


; Read and display the IEC status/error channel
stat_cmd
          ; Check we're on an IEC drive
            jsr     check_iec
            bcs     _done

          ; Set the drive (use current drive)
            lda     drive
            sta     kernel.args.fs.read_block.drive

          ; Set a cookie
            lda     #0
            sta     kernel.args.fs.read_block.cookie

          ; Set buffer for response
            lda     #<buf
            sta     kernel.args.fs.read_block.buf+0
            lda     #>buf
            sta     kernel.args.fs.read_block.buf+1

          ; Set buffer length (max response size)
            lda     #64
            sta     kernel.args.fs.read_block.buflen

          ; Call the kernel
            jsr     kernel.FileSystem.ReadBlock
            bcs     _err

          ; Wait for the response event
_loop
            jsr     kernel.NextEvent
            bcs     _loop

            lda     event.type

            cmp     #kernel.event.fs.DATA
            beq     _data

            cmp     #kernel.event.fs.ERROR
            beq     _err

          ; Unknown event, keep waiting
            bra     _loop

_data
          ; Read the data into our buffer
            lda     event.file.data.read
            beq     _empty
            sta     kernel.args.recv.buflen

            lda     #<buf
            sta     kernel.args.recv.buf+0
            lda     #>buf
            sta     kernel.args.recv.buf+1

            jsr     kernel.ReadData

          ; Null-terminate
            ldy     kernel.args.recv.buflen
            lda     #0
            sta     buf,y

          ; Print the status
            jsr     _print_buf
            jsr     put_cr
            clc
            rts

_empty
            ldx     #<_empty_msg
            lda     #>_empty_msg
            jsr     strings.puts_zero
            clc
            rts

_err
            ldx     #<_err_msg
            lda     #>_err_msg
            jsr     strings.puts_zero
            sec
_done
            rts

_print_buf
            ldy     #0
_ploop
            lda     buf,y
            beq     _pdone
            jsr     putc
            iny
            bra     _ploop
_pdone
            rts

_empty_msg  .text   "(empty response)", $0a, 0
_err_msg    .text   "IEC error", $0a, 0


; Send a command to the IEC command channel
send_cmd
          ; Check we're on an IEC drive
            jsr     check_iec
            bcs     _s_done

          ; Check we have a command argument
            lda     readline.token_count
            cmp     #2
            bcc     _s_usage

          ; Set the drive (use current drive)
            lda     drive
            sta     kernel.args.fs.write_block.drive

          ; Set a cookie
            lda     #0
            sta     kernel.args.fs.write_block.cookie

          ; Set the command buffer (point to token 1)
            lda     readline.tokens+1
            sta     kernel.args.fs.write_block.buf+0
            lda     #>readline.buf
            sta     kernel.args.fs.write_block.buf+1

          ; Get command length
            lda     #1
            jsr     readline.token_length
            sta     kernel.args.fs.write_block.buflen

          ; Call the kernel
            jsr     kernel.FileSystem.WriteBlock
            bcs     _s_err

          ; Wait for the response event
_s_loop
            jsr     kernel.NextEvent
            bcs     _s_loop

            lda     event.type

            cmp     #kernel.event.fs.WROTE
            beq     _s_ok

            cmp     #kernel.event.fs.ERROR
            beq     _s_err

          ; Unknown event, keep waiting
            bra     _s_loop

_s_ok
            ldx     #<_s_ok_msg
            lda     #>_s_ok_msg
            jsr     strings.puts_zero

          ; Now read and show the resulting status
            jsr     stat_cmd
            rts

_s_usage
            ldx     #<_s_usage_msg
            lda     #>_s_usage_msg
            jsr     strings.puts_zero
            clc
            rts

_s_err
            ldx     #<_s_err_msg
            lda     #>_s_err_msg
            jsr     strings.puts_zero
            sec
_s_done
            rts

_s_usage_msg .text  "Usage: ieccmd <command>", $0a
            .text   "Examples:", $0a
            .text   "  ieccmd I       - Initialize drive", $0a
            .text   "  ieccmd V       - Validate disk", $0a
            .text   "  ieccmd N:NAME  - Format disk", $0a
            .byte   0
_s_ok_msg   .text   "OK - ", 0
_s_err_msg  .text   "IEC error", $0a, 0

            .send
            .endn
