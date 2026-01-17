            .cpu    "65c02"

crc32       .namespace

            .section    dp
count       .byte       ?
print_fn    .word       ?
total       .byte       ?
crc         .dword      ?
            .send

crct0 = $8000       ; Four 256-byte tables
crct1 = $8100       ; (should be page-aligned for speed)
crct2 = $8200
crct3 = $8300

WIDTH = 16  ; hex dump width / requested read size.

            .section    code

cmd
            jsr     makecrctable

          ; Initialize CRC to $FFFFFFFF (must be after makecrctable
          ; since it uses crc as workspace)
            ldy     #$ff
            sty     crc
            sty     crc+1
            sty     crc+2
            sty     crc+3

            lda     #WIDTH
            sta     count

            lda     #<print
            sta     print_fn+0
            lda     #>print
            sta     print_fn+1

            lda     #' '
            jsr     display.putinplace

            lda     #WIDTH
            ldx     #print_fn
            jsr     reader.read_file

            ldx     #3
_print_crc  lda     crc,x
            eor     #$ff
            jsr     display.print_hex
            dex
            bpl     _print_crc
            jsr     put_cr
            rts

spinner     .byte   224,225
            
print
            jsr     update_crc
            dec     count
            bne     _done
            lda     #WIDTH
            sta     count
            inc     total
            lda     total
            and     #$01
            tax
            lda     spinner,x
            jsr     display.putinplace
_done
            clc
            rts

print_space
            lda     #' ' 
            jmp     putc

            ; Quick CRC computation with lookup tables
update_crc
            eor     crc
            tax
            lda     crc+1
            eor     crct0,x
            sta     crc
            lda     crc+2
            eor     crct1,x
            sta     crc+1
            lda     crc+3
            eor     crct2,x
            sta     crc+2
            lda     crct3,x
            sta     crc+3
            rts

makecrctable
            ldx     #0
_byteloop   lda     #0
            sta     crc+2
            sta     crc+1
            stx     crc
            ldy     #8
_bitloop    lsr     a
            ror     crc+2
            ror     crc+1
            ror     crc
            bcc     _noadd
            eor     #$ed
            pha
            lda     crc+2
            eor     #$b8
            sta     crc+2
            lda     crc+1
            eor     #$83
            sta     crc+1
            lda     crc
            eor     #$20
            sta     crc
            pla
_noadd      dey
            bne     _bitloop
            sta     crct3,x     ; Save CRC into table, high to low bytes
            lda     crc+2
            sta     crct2,x
            lda     crc+1
            sta     crct1,x
            lda     crc
            sta     crct0,x
            inx
            bne     _byteloop
            rts

            .send
            .endn
            
