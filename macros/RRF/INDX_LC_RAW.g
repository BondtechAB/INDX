; INDX_LC_RAW - read the raw load cell level into global.INDX_LC_raw
; M98 P"INDX_LC_RAW.g" [N<reads>], default N = global.INDX_TC_lc_samples
; M558.4 latches the raw rolling average as the tare baseline, read back as value[1].
; Readings are only comparable at the same XY position.

var n = exists(param.N) ? param.N : global.INDX_TC_lc_samples
if var.n < 1
  set var.n = 1

M400
G4 P300                          ; let the gantry settle after the last move

var i = 0
var r = 0.0
var sum = 0.0
var vmin = 0.0
var vmax = 0.0
while var.i < var.n
  M558.4 K0
  G4 P100
  set var.r = sensors.probes[0].value[1]
  set var.sum = var.sum + var.r
  if var.i = 0
    set var.vmin = var.r
    set var.vmax = var.r
  else
    set var.vmin = min(var.vmin, var.r)
    set var.vmax = max(var.vmax, var.r)
  set var.i = var.i + 1
  G4 P50

set global.INDX_LC_raw = var.sum / var.n
set global.INDX_LC_raw_spread = var.vmax - var.vmin
