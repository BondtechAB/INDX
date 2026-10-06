; INDX_CLOSE - tool-change lock (E+11)
;
; Normal tool-loading lock. Does NOT seat the heavier calibration force - use
; INDX_CLOSE_CAL for load-cell calibration.
;

if global.INDX_State > -1
  abort "INDX_CLOSE: already flagged closed (global.INDX_State > -1)."

; latch value from Bondtech
M98 P"INDX_LATCH_MOVE.g" E11.0 F1500

set global.INDX_State = 99   ; closed; tool identity set by the tool-change macro later
