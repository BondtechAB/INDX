; mesh.g - bed mesh with either probe, selected by K (run by G29 with no S parameter)
;   G29 or G29 K1   SZP scanning probe
;   G29 K0          INDX load cell
; Optional parameters:
;   X{min,max} Y{min,max}  area in probe coordinates (default global.INDX_mesh_min/max)
;   I<spacing> [J<Y spacing>]  point spacing in mm (default global.INDX_mesh_spacing)
;   F"name.csv"            extra copy of the height map
; Use I, not S, for the spacing: G29 reads S as its own subfunction.
; The area is trimmed to what the probe can reach with the head at or above safeYmin, with a
; warning. Height maps: heightmap.csv (active), heightmap_loadcell.csv, heightmap_SZP.csv.
; X and Y must be homed and a tool loaded (the Z datum is set with the load cell).

var szp_range = 1.7                ; mm; M558.1 calibration scan range
var clearance = 2                  ; mm; margin kept off the Y end stop at the axis maximum

var probe = exists(param.K) ? param.K : 1
if var.probe != 0 && var.probe != 1
  abort "mesh.g: K must be 0 (INDX load cell) or 1 (SZP)."
; the probe must exist and be usable
if #sensors.probes <= var.probe
  abort {"mesh.g: probe K" ^ var.probe ^ " does not exist on this machine. Only " ^ #sensors.probes ^ " probe(s) are configured - check the M558 commands in config.g."}
if sensors.probes[var.probe].type = 0
  abort {"mesh.g: probe K" ^ var.probe ^ " is type 0 (none), so it is declared but not usable. Check its M558 in config.g."}
if var.probe = 0 && sensors.probes[0].type != 12
  abort {"mesh.g: probe K0 is type " ^ sensors.probes[0].type ^ ", expected 12 (load cell)."}
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "mesh.g: home X and Y first (G28 X Y)."
if global.INDX_State = -1
  abort "mesh.g: no tool loaded - the Z datum is set by nozzle contact."
if global.INDX_LC_calibrated = false
  abort "mesh.g: load cell not calibrated (run INDX_LC_CALIBRATE)."

var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

; --- resolve the grid: the shared area, adjusted for this probe, then any X/Y/I/J parameters ---
var x0 = global.INDX_mesh_min[0]
var x1 = global.INDX_mesh_max[0]
var y0 = global.INDX_mesh_min[1]
var y1 = global.INDX_mesh_max[1]
var sx = global.INDX_mesh_spacing
var sy = var.sx
var ox = sensors.probes[var.probe].offsets[0]
var oy = sensors.probes[var.probe].offsets[1]
; X and Y must be arrays of two values
if exists(param.X)
  if #param.X != 2
    abort "mesh.g: X must be two values, e.g. X{-50,50}."
  set var.x0 = param.X[0]
  set var.x1 = param.X[1]
if exists(param.Y)
  if #param.Y != 2
    abort "mesh.g: Y must be two values, e.g. Y{-40,40}."
  set var.y0 = param.Y[0]
  set var.y1 = param.Y[1]
; Spacing: I for both axes, J to override Y separately. Single values, no arrays.
if exists(param.I)
  set var.sx = param.I
  set var.sy = param.I
if exists(param.J)
  set var.sy = param.J
if var.x1 <= var.x0 || var.y1 <= var.y0
  abort "mesh.g: grid limits must be ascending."
if var.sx <= 0 || var.sy <= 0
  abort "mesh.g: grid spacing must be greater than zero."
; --- trim the area to what this probe can reach ---
var rx0 = move.axes[0].min + var.ox
var rx1 = move.axes[0].max + var.ox
var ry0 = max(global.safeYmin, move.axes[1].min) + var.oy
var ry1 = move.axes[1].max - var.clearance + var.oy
var ax0 = var.x0
var ax1 = var.x1
var ay0 = var.y0
var ay1 = var.y1
set var.x0 = max(var.x0, var.rx0)
set var.x1 = min(var.x1, var.rx1)
set var.y0 = max(var.y0, var.ry0)
set var.y1 = min(var.y1, var.ry1)
if var.x1 - var.x0 < var.sx || var.y1 - var.y0 < var.sy
  abort {"mesh.g: probe K" ^ var.probe ^ " can reach almost none of X" ^ var.ax0 ^ ":" ^ var.ax1 ^ " Y" ^ var.ay0 ^ ":" ^ var.ay1 ^ " - its reach is X" ^ var.rx0 ^ ":" ^ var.rx1 ^ " Y" ^ var.ry0 ^ ":" ^ var.ry1 ^ "."}
; report a trimmed area (console, popup and event log) and carry on
if var.x0 != var.ax0 || var.x1 != var.ax1 || var.y0 != var.ay0 || var.y1 != var.ay1
  var req = "X" ^ var.ax0 ^ ":" ^ var.ax1 ^ " Y" ^ var.ay0 ^ ":" ^ var.ay1
  var got = "X" ^ var.x0 ^ ":" ^ var.x1 ^ " Y" ^ var.y0 ^ ":" ^ var.y1
  echo {"Warning: mesh.g probe K" ^ var.probe ^ " area trimmed to what it can reach. Requested " ^ var.req ^ ", probing " ^ var.got}
  echo {"  The head stays at or above safeYmin (" ^ global.safeYmin ^ ") and inside the axis limits."}
  M291 S1 T15 R"mesh.g: area trimmed" P{"Probe K" ^ var.probe ^ ". Requested " ^ var.req ^ ". Probing " ^ var.got ^ "."}
  M118 S{"mesh.g: probe K" ^ var.probe ^ " area trimmed. Requested " ^ var.req ^ ", probing " ^ var.got} L1

; clear any active height map before probing
G29 S2
M557 X{var.x0,var.x1} Y{var.y0,var.y1} S{var.sx,var.sy}
if var.dbg > 0
  echo {"mesh.g: probe K" ^ var.probe ^ " grid X" ^ var.x0 ^ ":" ^ var.x1 ^ " Y" ^ var.y0 ^ ":" ^ var.y1 ^ " S" ^ var.sx ^ ":" ^ var.sy}

if var.probe = 0
  ; --- INDX load cell: the nozzle probes each grid point ---
  ; level the bed (G32) first: probing dives from the configured height above Z=0
  if move.axes[2].homed = false
    abort "mesh.g: home Z first (homez), then level the bed (G32)."
  G90
  G1 Z5 F600
else
  ; --- SZP: set the Z datum with the load cell, then calibrate the coil against it ---
  G90
  G1 Z5 F600
  G1 X{global.INDX_probe_x} Y{global.INDX_probe_y} F12000
  G30                              ; home Z here by nozzle contact (probe 0)
  ; put the SZP coil over the spot where Z was homed
  G91
  G1 Y{-sensors.probes[1].offsets[1]} F12000
  ; calibrate and scan at the G31 K1 Z trigger height
  G90
  G1 Z{sensors.probes[1].triggerHeight + 0.5} F600   ; approach from above, to take out backlash
  M558.1 K1 S{var.szp_range}       ; calibrate the SZP against this datum
  G1 Z{sensors.probes[1].triggerHeight} F600

; probe the grid: writes heightmap.csv and enables mesh compensation
G29 S0 K{var.probe}

; keep a per-probe copy as well, so the last run of each is always on the card
if var.probe = 0
  G29 S3 P"heightmap_loadcell.csv"
else
  G29 S3 P"heightmap_SZP.csv"

; and a named copy if one was asked for, so a series of runs can be kept apart
if exists(param.F)
  G29 S3 P{param.F}

; lift clear and park at the X minimum + 1 mm and safeYmin, as homez does
G90
G1 Z5 F600
G1 X{move.axes[0].min + 1} Y{global.safeYmin} F12000

if var.dbg > 0
  echo {"mesh.g: done. Active map heightmap.csv, copy saved for probe K" ^ var.probe}
