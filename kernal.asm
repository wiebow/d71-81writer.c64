
#importonce

// kernal jump table
// exits with carry bit set indicate an error

.const ACPTR	= $FFA5
.const CHKIN    = $FFC6
.const CHKOUT   = $FFC9
.const CHRIN    = $FFCF
.const CHROUT   = $FFD2
.const CIOUT	= $FFA8
.const CINT 	= $FF81
.const CLALL    = $FFE7
.const CLOSE    = $FFC3
.const CLRCHN   = $FFCC
.const GETIN    = $FFE4
.const LISTEN   = $FFB1
.const LOAD     = $FFD5
.const OPEN     = $FFC0
.const PLOT		= $FFF0
.const SAVE     = $FFD8
.const SETLFS   = $FFBA
.const SETNAM   = $FFBD
.const UNLSN    = $FFAE