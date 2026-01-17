            .cpu    "65c02"

read        .namespace

            .section    dp
print_fn    .word       ?
            .send

            .section    code

cmd
            lda     #<print
            sta     print_fn+0
            lda     #>print
            sta     print_fn+1

            lda     #16 ; Max read size
            ldx     #print_fn
            jsr     reader.read_file
            jsr     put_cr
            rts
            
print
            jmp     putc

            .send
            .endn
            
