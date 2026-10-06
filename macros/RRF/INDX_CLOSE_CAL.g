; INDX_CLOSE_CAL - load-cell calibration lock (full seat)
;
; Drives the latch onto a hand-seated passive tool and seats the full ~1600 g
; locking force against the load cell. Run before INDX_LC_CAL. INDX_CLOSE is the
; lighter lock used for normal tool changes.

if global.INDX_State > -1
  abort "INDX_CLOSE_CAL: already flagged closed (global.INDX_State > -1)."

; lock, then a slow 1 mm seat; more than 1 mm made the clamp force unrepeatable (motor skips)
M98 P"INDX_LATCH_MOVE.g" E11.0 F1500
M98 P"INDX_LATCH_MOVE.g" E1.0 F300

set global.INDX_State = 99
