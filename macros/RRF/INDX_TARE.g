; INDX_TARE - store the unloaded load cell reading for calibration
; No motion. Run with the latch open and no tool, as part of INDX_LC_CALIBRATE.
; Stores the raw reading (M558.4, then value[1]) in global.INDX_LC_offset for INDX_LC_CAL.

; --- required globals ---
if !exists(global.INDX_LC_offset) || !exists(global.INDX_LC_samples)
  abort "INDX_TARE: load cell globals missing. INDX_variables.g must run from config.g first."

; --- preconditions (no motion, just guards) ---
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_TARE: home X and Y first (G28 X Y)."
if global.INDX_State != -1
  abort "INDX_TARE: latch must be OPEN with NO tool. Run INDX_OPEN first (global.INDX_State must be -1)."

var samples = global.INDX_LC_samples
if var.samples < 1
  set var.samples = 1
var dbg = exists(global.INDX_DEBUG) ? global.INDX_DEBUG : 0

; --- settle, then average several latched baselines ---
G4 P500

var i = 0
var reading = 0.0
var sum = 0.0
var vmin = 0.0
var vmax = 0.0

while var.i < var.samples
  M558.4 K0                        ; latch the raw rolling average as the baseline
  G4 P100                          ; let the ~50ms rolling average refresh before the next latch
  set var.reading = sensors.probes[0].value[1]
  set var.sum = var.sum + var.reading
  if var.i = 0
    set var.vmin = var.reading
    set var.vmax = var.reading
  else
    if var.reading < var.vmin
      set var.vmin = var.reading
    if var.reading > var.vmax
      set var.vmax = var.reading
  set var.i = var.i + 1
  G4 P50

var mean = var.sum / var.samples
set global.INDX_LC_offset = var.mean

if var.dbg > 0
  echo {"INDX_TARE: offset = " ^ var.mean ^ " counts  (mean of " ^ var.samples ^ " reads, spread " ^ (var.vmax - var.vmin) ^ ")"}
  echo "INDX_TARE: done. Seat a passive tool by hand, run INDX_CLOSE_CAL, then INDX_LC_CAL."
