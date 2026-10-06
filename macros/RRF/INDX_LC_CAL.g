; INDX_LC_CAL - compute the load cell scale (M558 V, grams per count)
; No motion. Run after INDX_TARE, with a tool seated by hand and locked by INDX_CLOSE_CAL.
; scale = -(locking force / (loaded reading - INDX_LC_offset)); negated so that pushing the
; nozzle towards the bed reads positive. Aborts without storing if the cell does not respond
; or the scale is outside INDX_LC_scale_limits.
; Optional S<grams> overrides global.INDX_LC_locking_force.

; --- required globals ---
if !exists(global.INDX_LC_offset) || !exists(global.INDX_LC_scale) || !exists(global.INDX_LC_samples) || !exists(global.INDX_LC_locking_force) || !exists(global.INDX_LC_calibrated)
  abort "INDX_LC_CAL: load cell globals missing. INDX_variables.g must run from config.g first."
if !exists(global.INDX_LC_scale_limits)
  abort "INDX_LC_CAL: global.INDX_LC_scale_limits missing. Re-run INDX_variables.g."

; --- preconditions (no motion, just guards) ---
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_LC_CAL: home X and Y first (G28 X Y)."
if global.INDX_State = -1
  abort "INDX_LC_CAL: latch is open. Seat a tool by hand and run INDX_CLOSE_CAL first."

; known locking force: S param overrides the global
var grams = exists(param.S) ? param.S : global.INDX_LC_locking_force
if var.grams <= 0
  abort "INDX_LC_CAL: locking force must be > 0 g."
var dbg = exists(global.INDX_DEBUG) ? global.INDX_DEBUG : 0

; INDX_TARE must have run since the last reboot; the unloaded reading is not saved
if global.INDX_LC_offset = 0
  abort "INDX_LC_CAL: no unloaded baseline. Run INDX_OPEN with no tool, then INDX_TARE, before calibrating."

var samples = global.INDX_LC_samples
if var.samples < 1
  set var.samples = 1

; --- settle, then average under load ---
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

var mean  = var.sum / var.samples
var delta = var.mean - global.INDX_LC_offset

; --- dead cell check: did the reading move at all? ---
; the reading must move by more than the ADC noise
var min_delta = 100    ; counts; below this the cell is not responding at all
if abs(var.delta) < var.min_delta
  set global.INDX_LC_calibrated = false
  abort {"INDX_LC_CAL: load cell not responding - reading moved only " ^ var.delta ^ " counts (unloaded " ^ global.INDX_LC_offset ^ ", loaded " ^ var.mean ^ "). Check the load cell wiring and the C pin in the M558 in config.g."}

; --- compute the scale ---
; negated because locking loads the cell opposite to bed contact (see SIGN in the header)
var scale = -(var.grams / var.delta)

; --- sanity check the result before storing it ---
var lo = global.INDX_LC_scale_limits[0]
var hi = global.INDX_LC_scale_limits[1]
if abs(var.scale) < var.lo || abs(var.scale) > var.hi
  set global.INDX_LC_calibrated = false
  echo {"INDX_LC_CAL: computed " ^ var.scale ^ " g/count from " ^ var.delta ^ " counts at " ^ var.grams ^ " g."}
  abort {"INDX_LC_CAL: scale outside the allowed range " ^ var.lo ^ " to " ^ var.hi ^ " g/count. Scale NOT updated, cell marked uncalibrated. Check the tool is fully seated and INDX_CLOSE_CAL locked it."}

; --- store and APPLY the scale to load-cell probe K0 ---
set global.INDX_LC_scale = var.scale
set global.INDX_LC_calibrated = true
M558 K0 V{global.INDX_LC_scale}

if var.dbg > 0
  echo {"INDX_LC_CAL: loaded mean = " ^ var.mean ^ " counts  (spread " ^ (var.vmax - var.vmin) ^ ")"}
  echo {"INDX_LC_CAL: delta = " ^ var.delta ^ " counts at " ^ var.grams ^ " g  ->  M558 V = " ^ var.scale ^ " g/count"}
  echo "INDX_LC_CAL: applied M558 K0 V. Verify the force sign (see header), persist with INDX_WRITE_STATE, then homez."
