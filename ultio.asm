// Ultimate IO
// -----------
//
// Have ultimate DOS perform file IO
//

.const CONTROL_STATUS = $df1c // 57116, read and write.
.const COMMAND_ID =     $df1d // 57117
.const RESPONSE_DATA =  $df1e // 57118
.const STATUS_DATA =    $df1f // 57119

// Start a command by making sure the ultimate is in the correct state
START_CMD:
check_error:
        lda #%00001000          // read bit 3 of control status (error?)
        and CONTROL_STATUS
        beq check_idle          // no error, do idle check
        sta CONTROL_STATUS      // error! write bit 3 to clear error state
check_idle:
        lda #%00110000          // read bit 4 and 5 of control status
        and CONTROL_STATUS
        beq !finished+          // bits 4 and 5 are clear, so idle.
        cmp #%00010000          // busy with a command?
        beq abort_busy          // yes. abort it.
        cmp #%00100000          // data incoming?
        beq ack_data            // acknowledge data.
        // cmp %00110000        // data more is not supported

        // all is well. return.
        rts
ack_data:
        lda #%00000010          // set the acknowledge bit,
        sta CONTROL_STATUS      // resetting all transfers
        jmp wait_idle           // wait for this to finish.
abort_busy:
        // abort busy command
        lda #%00000100          // set the abort bit, returning the
        sta CONTROL_STATUS      // ultimate to idle state
wait_idle:
        lda #%00110000          // check if idle state is reached
        and CONTROL_STATUS
        beq !finished+          // yes. all is well. return.
        jmp wait_idle           // keep waiting.
!finished:
        rts

// Finish a command and return
FINISH_CMD:
        lda #%00000001          // push the command in the command data register
        sta CONTROL_STATUS      // to the ultimate.
wait_state:
        lda #%00100000          // is the last data sent?
        and CONTROL_STATUS
        beq wait_state          // if not, keep waiting
wait_data:
        lda #%1100000           // wait for status and response bits to be set
        and CONTROL_STATUS
        beq wait_data           // not set, keep waiting.
        rts

// Get the dos version
ULT_GET_DOS:
        jsr START_CMD           // DOS_CMD_IDENTIFY
        lda #$01                // create command 01 01
        sta COMMAND_ID
        sta COMMAND_ID
        jmp FINISH_CMD          // execute it

// Get the current path the dos is at
ULT_GET_PATH:
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$12                // DOS_CMD_GET_PATH
        sta COMMAND_ID
        jmp FINISH_CMD

// Set the current path
ULT_SET_PATH:
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$11                // DOS_CMD_CHANGE_DIR
        sta COMMAND_ID

        // add path to the command
        ldy #$00
!loop:
        lda INPUT_BUFFER,y
        beq !finished+
        sta COMMAND_ID
        iny
        jmp !loop-
!finished:
        jmp FINISH_CMD


// Open file for reading from the current ultimate dos path
ULT_OPEN_FILE_READ:
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$02                // DOS_CMD_OPEN_FILE
        sta COMMAND_ID
        lda #$01                // open file read-only
        sta COMMAND_ID

        // add file name to the command
        ldy #$00
!loop:
        lda INPUT_BUFFER,y
        beq !finished+          // file name is zero terminated.
        sta COMMAND_ID
        iny
        jmp !loop-

!finished:
        jsr FINISH_CMD          // file is opened.

        // execute file seek command.
        // if file is indeed opened, this will return 00, ok.
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$06                // DOS_CMD_FILE_SEEK
        sta COMMAND_ID

        lda #$00                // place pointer at start of file
        sta COMMAND_ID
        sta COMMAND_ID
        sta COMMAND_ID
        sta COMMAND_ID
        jmp FINISH_CMD          // execute

// Transfer opened file to REU memory
ULT_FILE_READ_REU:
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$21
        sta COMMAND_ID

        // address to copy data to in REU ($00000000)
        lda #$00
        sta COMMAND_ID
        sta COMMAND_ID
        sta COMMAND_ID
        sta COMMAND_ID

        // size of the data to copy to the reu memory

        lda #$00        // len 000c 8000 = 819200 bytes.
        sta COMMAND_ID
        lda #$80
        sta COMMAND_ID
        lda #$0C
        sta COMMAND_ID
        lda #$00
        sta COMMAND_ID

        jmp FINISH_CMD

// Close file previously opened
ULT_CLOSE_FILE:
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$03         // DOS_CMD_CLOSE_FILE
        sta COMMAND_ID
        jmp FINISH_CMD

// Read a 256 byte chunk from an opened file
ULT_READ_FILE:
        jsr START_CMD
        lda #$01
        sta COMMAND_ID
        lda #$04              // DOS_CMD_READ_DATA
        sta COMMAND_ID

        // total number of bytes to read
        // $0100, which is 256 bytes. eg: one sector

        lda #$00
        sta COMMAND_ID
        lda #$01
        sta COMMAND_ID
        jsr FINISH_CMD

// Read data if available
// C more data after this is available
// A holds the data upon return
ULT_READ_DATA:
        lda #%10000000          // is there data?
        and CONTROL_STATUS
        beq no_data             // no
        lda RESPONSE_DATA       // yes. load it.
        sec                     // set carry bit to indicate more incoming
        rts
no_data:
        clc                     // clear carry bit to indicate no more data
        rts

// Read status if available
// C more data after this is available
// A holds the data
ULT_READ_STATUS:
        lda #%01000000          // is there a status?
        and CONTROL_STATUS
        beq no_status           // no
        lda STATUS_DATA         // yes. load it.
        sec
        rts
no_status:
        clc
        rts
