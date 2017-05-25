
.import source "kernal.asm"

.label buffer   = $fb  // sector buffer zero page pointer

// --------------------------------------------------------------------------
// writes memory buffer to disk.
// write_track and write_sector strings need to be up to date.
// assumes channels 2 (buffer) and 15 (command) are open.

WRITE_SECTOR:
        jsr RESET_BLOCK_POINTER

        // send 256 bytes to the drive buffer.

        ldx #2
        jsr CHKOUT              // use file 2 (buffer) as output.

        ldy #0
!loop:
        lda (buffer),y
        jsr CHROUT
        iny
        bne !loop-

        // send drive buffer to disk.

        ldx #15
        jsr CHKOUT              // use file 15 (command) as output.

        ldy #0
!loop:
        lda u2_command,y        // read byte from command string.
        jsr CHROUT              // send to command channel.
        iny
        cpy #u2_command_end - u2_command
        bne !loop-

        jsr CLRCHN              // execute sent command
        rts

u2_command:     .text "U2 2 0 "
write_track:    .text "00 "
write_sector:   .text "00"
u2_command_end:

// --------------------------------------------------------------------------
// resets block pointer to position 0
// assumes channel 15 is open, and channel 2 is used for block operations

RESET_BLOCK_POINTER:
        ldx #15
        jsr CHKOUT          // use file 15 (command) as output.

        ldy #0
!loop:
        lda bp_command,y    // read byte from command string
        jsr CHROUT          // send to command channel
        iny
        cpy #bp_command_end - bp_command
        bne !loop-
        jsr CLRCHN          // execute sent command
        rts

bp_command:
        .text "B-P 2 0"
bp_command_end:

// --------------------------------------------------------------------------
// Sets 1571 drive in double sided mode

SET_1571_MODE:
        ldx #15
        jsr CHKOUT          // use file 15 (command) as output.

        ldy #0
!loop:
        lda ds_command,y    // read byte from command string
        jsr CHROUT          // send to command channel
        iny
        cpy #ds_command_end - ds_command
        bne !loop-
        jsr CLRCHN          // execute sent command
        rts

ds_command:
        .text "U0>M1"
ds_command_end:


// --------------------------------------------------------------------------
// opens drive buffer (#) as logical file 2.

OPEN_BUFFER_CHANNEL:
        lda #2          // logical file number
        ldx device     // device number
        ldy #2          // command number
        jsr SETLFS

        lda #1
        ldy #>buffer_name
        ldx #<buffer_name
        jsr SETNAM
        jsr OPEN
!exit:
        rts

buffer_name:
        .text "#"

// --------------------------------------------------------------------------
// closes the buffer channel (2)

CLOSE_BUFFER_CHANNEL:
        lda #2
        jmp CLOSE

// --------------------------------------------------------------------------
// opens a command channel (15)

OPEN_COMMAND_CHANNEL:
        lda #15         // logical file number
        ldx device      // device number
        ldy #15         // command number
        jsr SETLFS

        lda #0          // no file name
        jsr SETNAM

        jsr OPEN        // open channel, using parameters
!exit:
        rts

// --------------------------------------------------------------------------
// closes command channel (15) and files and resets all i/o

CLOSE_COMMAND_CHANNEL:
        lda #15
        jmp CLOSE

// --------------------------------------------------------------------------

// Zero track administration. put 01 in string.
ZERO_TRACK:
        lda #$30
        sta write_track+0
        lda #$31
        sta write_track+1
        rts

// Zero sector administration. put 00 in string.
ZERO_SECTOR:
        lda #$30
        sta write_sector+0
        sta write_sector+1
        rts

// text Advance one track
NEXT_TRACK:
        inc write_track+1
        lda write_track+1
        cmp #$3a
        beq !skip+
        rts
!skip:
        inc write_track+0
        lda #$30
        sta write_track+1
        rts

// text Advance one sector
NEXT_SECTOR:
        inc write_sector+1
        lda write_sector+1
        cmp #$3a
        beq !skip+
        rts
!skip:
        inc write_sector+0
        lda #$30
        sta write_sector+1
        rts

// --------------------------------------------------------------------------
// 1571 sectors per track
// sectors start at 0, tracks start at 1

sectors_1571:
        .byte 0
        // side 1, track 1
        .byte 21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21 // 17
        .byte 19,19,19,19,19,19,19 // 7
        .byte 18,18,18,18,18,18    // 6
        .byte 17,17,17,17,17       // 5
        // side 2, track 36
        .byte 21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21
        .byte 19,19,19,19,19,19,19
        .byte 18,18,18,18,18,18
        .byte 17,17,17,17,17

// --------------------------------------------------------------------------

sector_buffer:
        .fill 256,$f0
