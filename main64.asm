
// D71/D81 writer. Main module  C64 version version 1.1
// ----------------------------------------
//
// This C64 software is intended to transfer a D71/D81 file
// from the 1541 Ultimate II back to disk.
//
// Inspired by http://csdb.dk/release/?id=120666 written by Jasmin68k
//
// This version was written by Ernoman.
// WdW added in May 2017:
// - kickassembler source format
// - path selector
// - sanity checks, some error handing
// - restoration of disk write commands
// - d71 writer
//  -optimise : skip empty sectors


BasicUpstart2(MAIN)

.import source "kernal.asm"
.import source "diskwrite64.asm"
.import source "print.asm"
.import source "keyinput.asm"
.import source "ultio.asm"
.import source "reu.asm"

.pc = * "Main"

MAIN:
        jsr DISPLAY_WELCOME
        jsr DISPLAY_ULTIDOS

        // todo: check for REU

        // ask for d71 or d81

        jsr ENTER_DISK_TYPE
        lda INPUT_BUFFER
        sec
        sbc #$30
        sta disk_type
        lda disk_type
        beq error_occurred          // zero entered
        cmp #3
        bcs error_occurred          // equal or higher than 3.

        // ask for image path and select it

        jsr ENTER_PATH
        jsr DISPLAY_STATUS          // get and print status
        jsr STATUS_OK
        beq !continue+
        jmp error_occurred          // abort

!continue:
        jsr DISPLAY_CURRENT_PATH    // display current path

        // ask for file name and open it

        jsr ENTER_FILE_NAME         // name of d81 file to open
        jsr ULT_OPEN_FILE_READ      // attempt to open the file on sd card
        jsr DISPLAY_STATUS          // get and print status
        jsr STATUS_OK               // check status. 0=ok
        beq !continue+
        jmp error_occurred          // abort

!continue:
        // ask for destination device id

        lda #0                      // reset device id
        sta device
        jsr ENTER_DEVICE            // get destination id

        ldx #0                      // reset input buffer offset
        ldy INPUT_LEN               // how many digits entered?
        beq error_occurred          // nothing entered
        cpy #1
        beq device_single_digit     // single digit entered
        cpy #2
        beq device_double_digit     // double digit entered
        jmp error_occurred          // too many digits

device_double_digit:
        lda #10                     // should only be 10 or 11 so force this
        sta device
        inx                         // go to next digit

device_single_digit:
        lda INPUT_BUFFER,x
        sec
        sbc #$30            // convert to real number
        clc
        adc device          // add to what is already there
        sta device

        // sanity check for device id

        lda device
        cmp #7
        bcc error_occurred  // less or equal to 7
        cmp #11
        bcc device_entered  // less or equal to 11, but higher than 7
        jmp error_occurred  // above 11

device_entered:
        jsr DISPLAY_OK
        jmp TRANSFER_DISK
error_occurred:
        jmp ERROR

TRANSFER_DISK:

!skip:
        // Have the ultimate place the file in the REU
        // Note; reading the file using the read function seems to miss
        // every first byte on each transfer. Doing this via the REU seems to
        // work fine.

        jsr ULT_FILE_READ_REU
        jsr STATUS_OK
        beq setup_reu
        jmp ERROR

setup_reu:
        // Setup the REU transfer initial state

        jsr REU_SETUP_TRANSFER

setup_write:
        // set zero page pointer to sector buffer in ram

        lda #<sector_buffer
        sta buffer
        lda #>sector_buffer
        sta buffer+1

        // reset command string characters
        // also used for printing progress

        jsr ZERO_SECTOR
        jsr ZERO_TRACK

        // start at track 1, sector 0

        lda #1
        sta current_track
        lda #0
        sta current_sector

        // do D71 or D81 write

        lda disk_type
        cmp #2
        beq do_d81

// ----------------
// do D71

        jsr SET_1571_MODE        // make sure drive is in 1571 mode.

        jsr OPEN_BUFFER_CHANNEL

next_sector_read_d71:
        jsr DISPLAY_PROGRESS
        jsr DISPLAY_PROGRESS_HOME

        // get data from reu to memory buffer

        jsr REU_TRANSFER_SECTOR
        jsr CHECK_BUFFER_EMPTY
        bcc !skip+               // bit clear means buffer is empty
        jsr WRITE_SECTOR
!skip:
        jsr NEXT_SECTOR
        inc current_sector
        ldx current_track
        lda sectors_1571,x       // all sectors for this track done?
        cmp current_sector
        beq next_track_d71
        jmp next_sector_read_d71

next_track_d71:
        // start at sector 0 in next track

        lda #0
        sta current_sector
        jsr ZERO_SECTOR

        // go to next track
        jsr NEXT_TRACK
        inc current_track
        lda current_track
        cmp #71                  // all done?
        beq !finish+
        jmp next_sector_read_d71

// ----------------
// do D81

do_d81:
        jsr OPEN_BUFFER_CHANNEL

next_sector_read_d81:
        jsr DISPLAY_PROGRESS
        jsr DISPLAY_PROGRESS_HOME

        // get data from reu to memory buffer

        jsr REU_TRANSFER_SECTOR
        jsr WRITE_SECTOR
        jsr CHECK_BUFFER_EMPTY
        bcc !skip+                      // clear bit means buffer is empty
        jsr WRITE_SECTOR
!skip:
        inc current_sector
        lda current_sector
        cmp #40
        beq next_track_d81
        jsr NEXT_SECTOR             // advance text, and cmd string
        jmp next_sector_read_d81    // get ready for next sector
next_track_d81:
        // start at sector 0 in next track

        lda #0
        sta current_sector
        jsr ZERO_SECTOR

        // go to next track
        jsr NEXT_TRACK
        inc current_track
        lda current_track
        cmp #81                 // done?
        beq !finish+
        jmp next_sector_read_d81

// ---------

!finish:
        jsr DISPLAY_DONE
        jmp CLOSE_APP
ERROR:
        jsr DISPLAY_FAIL
CLOSE_APP:
        jsr CLOSE_BUFFER_CHANNEL
        jsr CLOSE_COMMAND_CHANNEL
        jsr ULT_CLOSE_FILE
        rts

// -----

// ---- Helper functions

// Display a nice welcome message
DISPLAY_WELCOME:
        lda #>str_welcome
        ldx #<str_welcome
        jsr PRINT
        rts

// Ask for the file name
ENTER_FILE_NAME:
        lda #>str_enter_file_name
        ldx #<str_enter_file_name
        jsr PRINT
        jsr GET_TEXT
        jsr NEW_LINE
        rts

// Ask for the disk type
ENTER_DISK_TYPE:
        lda #>str_enter_disk_type
        ldx #<str_enter_disk_type
        jsr PRINT
        jsr GET_DECIMAL
        jsr NEW_LINE
        rts

// Ask for the device number
ENTER_DEVICE:
        lda #>str_enter_device
        ldx #<str_enter_device
        jsr PRINT
        jsr GET_DECIMAL
        jsr NEW_LINE
        rts

// Display ultimate dos version
DISPLAY_ULTIDOS:
        jsr ULT_GET_DOS
        jsr DISPLAY_DATA
        jsr NEW_LINE
        rts

// Display the path the ultimate is looking at
DISPLAY_CURRENT_PATH:
        lda #>str_current_path
        ldx #<str_current_path
        jsr PRINT
        jsr ULT_GET_PATH
        jsr DISPLAY_DATA
        jsr NEW_LINE
        rts

// Ask and set the dos path.
ENTER_PATH:
        lda #>str_enter_path
        ldx #<str_enter_path
        jsr PRINT
        jsr GET_TEXT
        jsr NEW_LINE
        jsr ULT_SET_PATH
        rts

// Set cursor at a new line
NEW_LINE:
        lda #$0d
        jsr CHROUT
        rts

// Display the current track and sector
DISPLAY_PROGRESS:
        lda #>str_track
        ldx #<str_track
        jsr PRINT
        ldx #$00
!next:
        lda write_track,x   // found in diskwrite.asm
        jsr CHROUT
        inx
        cpx #$03
        beq print_sector
        jmp !next-
print_sector:
        lda #>str_sector
        ldx #<str_sector
        jsr PRINT
        ldx #$00
!next:
        lda write_sector,x    // found in diskwrite.asm
        jsr CHROUT
        inx
        cpx #$02
        beq !end+
        jmp !next-
!end:
        rts

// Set the cursor home after track and sector were displayed
DISPLAY_PROGRESS_HOME:
        ldx #18
        lda #$9d
!next:
        jsr CHROUT
        dex
        bne !next-
        rts

// Display done message
DISPLAY_DONE:
        lda #>str_done
        ldx #<str_done
        jsr PRINT
        rts

// Display fail message
DISPLAY_FAIL:
        lda #>str_fail
        ldx #<str_fail
        jsr PRINT
        rts

// Display OK message
DISPLAY_OK:
        lda #>str_ok
        ldx #<str_ok
        jsr PRINT
        rts

// Display Data read from the ultimate
DISPLAY_DATA:
        jsr ULT_READ_DATA
        bcc !end+ // no more
        beq !end+ // 0 character?
        jsr CHROUT
        jmp DISPLAY_DATA
!end:
        rts

// Display Status read from the ultimate
DISPLAY_STATUS:
        ldy #$01
        jsr read_status
        jsr NEW_LINE
        rts

// Get Status from the ultimate
GET_STATUS:
        ldy #$00
read_status:
        lda #$00
        sta status
        sta status+1
        lda #$00
        sta status_ptr
!next:
        // read next status byte
        jsr ULT_READ_STATUS
        bcc !end+ // no more
        beq !end+ // 0 character?
store_code:
        ldx status_ptr
        cpx #$02
        bcs check_print  // no store when x >= 2
        pha
        sta status,x
        lda #$30
        sec
        sbc status,x // subract '0'
        sta status,x // store
        inx          // x++
        stx status_ptr
        pla
check_print:
        cpy #$01
        beq !print+ // print when y = 1
        jmp !next-
!end:
        rts
!print:
        jsr CHROUT
        jmp !next-

// Checks if the status code is OK.
// Just as CMP the zero flag holds the result.
STATUS_OK:
        lda status
        beq !next+
        rts
!next:
        lda status+1
        rts

// checks if buffer is empty.
// carry bit is cleared if buffer is empty, set when not.

CHECK_BUFFER_EMPTY:
        ldy #0
!loop:
        lda (buffer),y
        bne !done+
        iny
        bne !loop-
        clc
        rts
!done:
        sec
        rts

// ----- Data

.encoding "petscii_mixed"

str_welcome:
        .byte $93 // clear
        .byte $0e // lowercase set (lower-> upper, upper->lower)
        .text "D71/D81 writer V1.1, by Ernoman and WdW"
        .byte $0d, 0
str_current_path:
        .text "Current path is: "
        .byte 0
str_enter_disk_type:
        .text "Select (1) D71 or (2) D81: "
        .byte 0
str_enter_path:
        .text "Enter path to file: "
        .byte 0
str_enter_file_name:
        .text "Enter file name: "
        .byte 0
str_enter_device:
        .text "Destination device (8-11): "
        .byte 0
str_fail:
        .text "Fail!"
        .byte $0d, 0
str_ok:
        .text "OK"
        .byte $0d, 0
str_track:
        .text "Track "
        .byte 0
str_sector:
        .text "sector "
        .byte 0
str_done:
        .byte $0d,$0d
        .text "Done!"
        .byte 0

// status read from the ultimate
status:
        .byte 0, 0

status_ptr:
        .byte 0

// indexes for write loop
current_track:
        .byte 0
current_sector:
        .byte 0

// the device id the user entered
device:
        .byte $09

// diskdrive type the user entered
disk_type:
        .byte 0
