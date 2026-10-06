; bed.g - 3-point leadscrew levelling with the INDX load cell probe
; Run by G32. Z must already be homed (homez). The last G30 uses S3 to adjust the leadscrews
; (M671 in config.g); passes repeat until the deviation is below tol, up to maxpass.

if move.axes[2].homed = false
  abort "bed.g: home Z first (homez) - the points must share one Z frame."
if global.INDX_LC_calibrated = false
  abort "bed.g: load cell not calibrated (run INDX_LC_CALIBRATE)."
; the nozzle probes the bed, so a tool must be on the head
M98 P"INDX_TOOL_CHECK.g" S"bed.g"

; probe points, near each leadscrew
var px = {-115, 0, 104}
var py = {-100, 118, -100}
var np = #var.px
; every point must be within the axis limits; G30 P does not check them
while iterations < var.np
  var hx = var.px[iterations] - sensors.probes[0].offsets[0]
  var hy = var.py[iterations] - sensors.probes[0].offsets[1]
  if var.hx < move.axes[0].min || var.hx > move.axes[0].max || var.hy < move.axes[1].min || var.hy > move.axes[1].max
    abort {"bed.g: levelling point " ^ iterations ^ " (X" ^ var.px[iterations] ^ " Y" ^ var.py[iterations] ^ ") is outside the axis limits. Move it, keeping it near its leadscrew in M671."}

var dbg = exists(global.INDX_DEBUG) ? global.INDX_DEBUG : 0
var tol     = 0.05                  ; mm; stop once the measured corner deviation is below this
var maxpass = 5                     ; safety cap on levelling passes
var i = 0
var pass = 0
var done = false

; H2 on the positioning moves allows Z below the M208 minimum on an unlevelled bed

while var.pass < var.maxpass
  ; --- one 3-point pass ---
  set var.i = 0
  while var.i < var.np
    ; move, then wait, so the feed tube settles before probing
    G90
    G1 H2 Z5 F1200
    G1 X{var.px[var.i]} Y{var.py[var.i]} F12000
    G4 S0.5
    if var.i < var.np - 1
      G30 P{var.i} X{var.px[var.i]} Y{var.py[var.i]} Z-99999
    else
      G30 P{var.i} X{var.px[var.i]} Y{var.py[var.i]} Z-99999 S3
    set var.i = var.i + 1

  ; --- pass complete: S3 has levelled and reported the pre-correction deviation ---
  if var.dbg > 0
    echo {"bed.g pass " ^ (var.pass + 1) ^ ": deviation " ^ move.calibration.initial.deviation ^ " mm"}
  if abs(move.calibration.initial.deviation) < var.tol
    set var.done = true
    break
  set var.pass = var.pass + 1

; lift clear
G90
G1 H2 Z5 F1200

if var.dbg > 0
  if var.done
    echo {"bed.g: levelled, deviation " ^ move.calibration.initial.deviation ^ " mm"}
  else
    echo {"bed.g: still " ^ move.calibration.initial.deviation ^ " mm after " ^ var.maxpass ^ " passes"}
