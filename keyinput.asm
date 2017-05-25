// Keyboard input
// --------------
//
// Uses the kernel to get data from the keyboard.
// Taken from http://codebase64.org/doku.php?id=base:robust_string_input
//
//======================================================================
//Input a string and store it in GOTINPUT, terminated with a null byte.
//x:a is a pointer to the allowed list of characters, null-terminated.
//max # of chars in y returns num of chars entered in y.
//======================================================================

.import source "kernal.asm"

// Get alphanumeric text
GET_TEXT:
  lda #>ALPHANUM_FILTER
  ldx #<ALPHANUM_FILTER
  ldy #32
  jmp FILTERED_INPUT

// Get decimal numbers
GET_DECIMAL:
  lda #>DECIMAL_FILTER
  ldx #<DECIMAL_FILTER
  ldy #32
  jmp FILTERED_INPUT


// Main entry
// y = max chars
// x = lsb filter string
// a = msb filter string
FILTERED_INPUT:
  sty MAXCHARS
  stx CHECKALLOWED+1
  sta CHECKALLOWED+2

  // Zero characters received.
  lda #$00
  sta INPUT_LEN

// Wait for a character.
INPUT_GET:
  jsr GETIN
  beq INPUT_GET

  sta LASTCHAR

  cmp #$14               // Delete
  beq DELETE

  cmp #$0d               // Return
  beq INPUT_DONE

  // Check the allowed list of characters.
  ldx #$00
CHECKALLOWED:
  lda $FFFF,x           // Overwritten
  beq INPUT_GET         // Reached end of list (0)
  cmp LASTCHAR
  beq INPUTOK           // Match found

  // Not end or match, keep checking
  inx
  jmp CHECKALLOWED

INPUTOK:
  lda LASTCHAR          // Get the char back
  ldy INPUT_LEN
  sta INPUT_BUFFER,y    // Add it to string
  jsr CHROUT // PRINTCHAR         // Print it

  inc INPUT_LEN         // Next character

  // End reached?
  lda INPUT_LEN
  cmp MAXCHARS
  beq INPUT_DONE

  // Not yet.
  jmp INPUT_GET

INPUT_DONE:
   ldy INPUT_LEN
   lda #$00
   sta INPUT_BUFFER,y   // Zero-terminate
   rts

//  Delete last character.
DELETE:
  // First, check if we're at the beginning.  If so, just exit.
  lda INPUT_LEN
  bne DELETE_OK
  jmp INPUT_GET

  // At least one character entered.
DELETE_OK:
  // Move pointer back.
  dec INPUT_LEN

  // Store a zero over top of last character, just in case no other
  // characters are entered.
  ldy INPUT_LEN
  lda #$00
  sta INPUT_BUFFER,y

  // Print the delete char
  lda #$14
  jsr CHROUT

  // Wait for next char
  jmp INPUT_GET


// =================================================
// Filters
// =================================================

DECIMAL_FILTER:
  .text "1234567890"
  .byte 0

ALPHANUM_FILTER:
  .text " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.,-+!#$%&'()*/"
  .byte 0

// =================================================

MAXCHARS:
  .byte 0

LASTCHAR:
  .byte 0

INPUT_LEN:
  .byte 0

INPUT_BUFFER:
  .fill 32, 0

