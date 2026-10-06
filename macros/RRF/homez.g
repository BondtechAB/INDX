; homez - Z home with the INDX load-cell probe
;
; One probe at the configured probe point sets the Z datum. The probe settings (speed, dive
; heights, and how many probes are averaged per point) come from the M558 in config.g; this
; macro does not change them. The load cell tares automatically at the start of every probing
; move, so no manual tare is needed.
;
; A tool MUST be loaded (the nozzle is the probe contact). X and Y must be homed.

if move.axes[0].homed = false || move.axes[1].homed = false
  abort "homez: home X and Y first (G28 X Y)."
if global.INDX_State = -1
  abort "homez: no tool loaded - the nozzle probes the bed."
if global.INDX_LC_calibrated = false
  abort "homez: load cell not calibrated (run INDX_LC_CALIBRATE)."

var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

; clear the height map so the datum is set on the bed, not on the compensated surface
G29 S2

; probe point (machine coordinates) less the probe XY offset
var px = (exists(global.INDX_probe_x) ? global.INDX_probe_x : 0) - sensors.probes[0].offsets[0]
var py = (exists(global.INDX_probe_y) ? global.INDX_probe_y : 0) - sensors.probes[0].offsets[1]

; optional random offset of the probe point, to spread bed wear
var fuzz = 0.0
if exists(global.INDX_LC_probe_fuzz)
  set var.fuzz = global.INDX_LC_probe_fuzz
var fx = var.px
var fy = var.py
if var.fuzz > 0
  set var.fx = {var.px + (random(2001) - 1000) / 1000.0 * var.fuzz}
  set var.fy = {var.py + (random(2001) - 1000) / 1000.0 * var.fuzz}

; position over the (optionally fuzzed) probe point near bed centre
G91
G1 H2 Z5 F600
G90
G1 X{var.fx} Y{var.fy} F12000

; G31 Z trigger height: G30 sets machine Z to this value
var th = sensors.probes[0].triggerHeight

; probe and set the Z datum
G30
if var.dbg > 0
  echo {"homez: Z datum set at trigger height " ^ var.th ^ " mm. preload " ^ sensors.probes[0].loadCell.preload ^ " g"}

; debug only: probe again, it should stop at the trigger height
if var.dbg > 0
  G90
  G1 Z2 F600
  G30 S-1
  echo {"homez: verify Z = " ^ move.axes[2].machinePosition ^ " mm (expect " ^ var.th ^ ", error " ^ (move.axes[2].machinePosition - var.th) ^ " mm)"}

; lift clear of the bed, then park 1 mm inside the configured X and Y minimum limits
G90
G1 Z5 F600
G1 X{move.axes[0].min + 1} Y{global.safeYmin} F12000

; reload the height map
;G29 S1
