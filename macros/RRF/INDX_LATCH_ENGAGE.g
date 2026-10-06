; INDX_LATCH_ENGAGE - extra latch engage (E+3)
;
; A short slow E move after a tool pickup to guarantee the latch is fully engaged
; during Z-offset calibration. The latch must already be closed.

if global.INDX_State = -1
  abort "INDX_LATCH_ENGAGE: latch is open - close it first (INDX_CLOSE)."

; latch value from Bondtech
M98 P"INDX_LATCH_MOVE.g" E3.0 F300
