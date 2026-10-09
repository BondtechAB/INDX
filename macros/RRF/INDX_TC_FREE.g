; INDX_TC_FREE - park the tool on the head in its dock
; Called from tfreeN.g: M98 P"INDX_TC_FREE.g" T<n>
; All XY moves are G53 (machine coordinates). Only the tool-change macros go below safeYmin.
; Checks: load cell (the clamp force is released) and, for a warm tool, nozzle temperature.

if !exists(param.T)
  abort "INDX_TC_FREE: parameter T=<tool number> required."
var t = param.T
if var.t < 0 || var.t >= #global.INDX_tool_x
  abort {"INDX_TC_FREE: T" ^ var.t ^ " has no entry in global.INDX_tool_x (" ^ #global.INDX_tool_x ^ " tools defined)."}
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_TC_FREE: home X and Y first."
if global.INDX_State = -1
  abort "INDX_TC_FREE: no tool on the head to park (global.INDX_State = -1)."
if global.INDX_State != var.t
  abort {"INDX_TC_FREE: T" ^ var.t ^ " is selected but global.INDX_State is " ^ global.INDX_State ^ " (99 = tool unknown). Set global.INDX_State to the tool on the head and select it with T<n> P0."}

var into = global.INDX_dock_dir
var dockx = global.INDX_tool_x[var.t]
var docky = global.INDX_dock_y
var trig = var.docky - var.into * global.INDX_trigger_offset

if var.dockx < move.axes[0].min || var.dockx > move.axes[0].max
  abort {"INDX_TC_FREE: T" ^ var.t ^ " dock X " ^ var.dockx ^ " is outside the X limits."}
if var.docky < global.INDX_Y_hard_min || var.docky > move.axes[1].max
  abort {"INDX_TC_FREE: dock Y " ^ var.docky ^ " is outside the Y limits."}

; travel speed outside the slow zone, contact speed inside it
var speed = global.INDX_TC_SPEED * global.INDX_TC_MODE
var cs = global.INDX_TC_contact_speed
var slow_y = var.docky - var.into * max(global.INDX_TC_slow_zone, global.INDX_trigger_offset)
if (var.slow_y - global.safeYmin) * var.into < 0
  set var.slow_y = global.safeYmin

set global.INDX_TC_count = global.INDX_TC_count + 1
set global.INDX_TC_drop_lc_ok = -1
set global.INDX_TC_drop_temp_ok = -1

; heater off; standby is not used, and RRF applies the standby target when tfree ends
M568 P{var.t} A0 R0
var temp_off = heat.heaters[1].current
var time_off = state.upTime + state.msUpTime / 1000

; Z hop; the park starts the T command, so the height saved here replaces any earlier one
set global.INDX_TC_restore_z = -1
if move.axes[2].homed && global.INDX_z_hop > 0
  set global.INDX_TC_restore_z = move.axes[2].machinePosition
  G53 G1 Z{move.axes[2].machinePosition + global.INDX_z_hop} F900
  M400

; if the head is below safeYmin, leave in Y only before any X move
M400
if (move.axes[1].machinePosition - global.safeYmin) * var.into > 0.01
  G53 G1 X{move.axes[0].machinePosition} Y{global.safeYmin} F{var.cs}
  M400

; along safeYmin to the dock X
G90
G53 G1 X{var.dockx} Y{global.safeYmin} F{var.speed}

; load-cell reading with the tool clamped
var lc = global.INDX_LC_calibrated
if var.lc
  M98 P"INDX_LC_RAW.g"
  set global.INDX_TC_lc_before = global.INDX_LC_raw
  ; presence: the reading must be at least INDX_TC_lc_min_g above this dock's empty-head reading
  if global.INDX_LC_empty_ref[var.t] != null
    var pg = abs((global.INDX_TC_lc_before - global.INDX_LC_empty_ref[var.t]) * global.INDX_LC_scale)
    var pok = var.pg >= global.INDX_TC_lc_min_g ? 1 : 0
    M98 P"INDX_TC_REPORT.g" E"head_tool" T{var.t} B{global.INDX_LC_empty_ref[var.t]} A{global.INDX_TC_lc_before} D{var.pg} X{global.INDX_LC_raw_spread} K{var.pok}
    if var.pok = 0
      abort {"INDX_TC_FREE: global.INDX_State is " ^ var.t ^ " but the load cell reads only " ^ var.pg ^ " g above an empty head. Check the head before any tool change."}

; limits off beyond safeYmin; fast to the slow zone, then contact speed to the trigger line
var lim = move.limitAxes
M564 S0
G53 G1 X{var.dockx} Y{var.slow_y} F{var.speed}
G53 G1 X{var.dockx} Y{var.trig} F{var.cs}
M400
var temp_before = heat.heaters[1].current
var time_before = state.upTime + state.msUpTime / 1000

; release the tool and save the open latch state
M98 P"INDX_UNLOCK_DANCE.g" X{var.dockx} Y{var.docky} B{global.INDX_trigger_offset}
M98 P"INDX_WRITE_STATE.g"

; peel off the pins, back to safeYmin, limits back on
G53 G1 X{var.dockx} Y{var.docky - var.into * global.INDX_peel_distance} F{min(3000, var.cs)}
G53 G1 X{var.dockx} Y{global.safeYmin} F{var.speed}
M400
if var.lim
  M564 S1

; load-cell check, at the position of the first reading
if var.lc
  M98 P"INDX_LC_RAW.g"
  var dg = (global.INDX_LC_raw - global.INDX_TC_lc_before) * global.INDX_LC_scale
  set global.INDX_TC_drop_lc_ok = abs(var.dg) >= global.INDX_TC_lc_min_g ? 1 : 0
  M98 P"INDX_TC_REPORT.g" E"drop_lc" T{var.t} B{global.INDX_TC_lc_before} A{global.INDX_LC_raw} D{var.dg} X{global.INDX_LC_raw_spread} K{global.INDX_TC_drop_lc_ok}
  ; the clamp force went away, so this reading is an empty head: keep it as the dock's reference
  if global.INDX_TC_drop_lc_ok = 1
    set global.INDX_LC_empty_ref[var.t] = global.INDX_LC_raw

; temperature check: move along safeYmin by INDX_TC_drop_temp_dx so the sensor no longer sees
; the docked tool, then compare the fall with the cooling expected from the rate before the dance
if var.temp_before >= global.INDX_TC_drop_temp_min
  var cx = min(max(var.dockx + global.INDX_TC_drop_temp_dx, move.axes[0].min), move.axes[0].max)
  G53 G1 X{var.cx} Y{global.safeYmin} F{var.speed}
  M400
  G4 P{global.INDX_TC_drop_dwell}
  var temp_after = heat.heaters[1].current
  var time_after = state.upTime + state.msUpTime / 1000
  var rate = max(0, (var.temp_off - var.temp_before) / max(0.1, var.time_before - var.time_off))
  var cooling = var.rate * (var.time_after - var.time_before)
  var excess = var.temp_before - var.temp_after - var.cooling
  set global.INDX_TC_drop_temp_ok = var.excess >= global.INDX_TC_drop_temp_fall ? 1 : 0
  M98 P"INDX_TC_REPORT.g" E"drop_temp" T{var.t} B{var.temp_before} A{var.temp_after} D{var.excess} X{var.cooling} K{global.INDX_TC_drop_temp_ok}

; park only (T-1): no pickup follows to restore Z, so Z stays raised and the saved height is cleared
if move.motionSystems[0].nextTool < 0
  set global.INDX_TC_restore_z = -1

if global.INDX_DEBUG > 0
  echo {"INDX_TC_FREE: T" ^ var.t ^ " parked at X" ^ var.dockx ^ " Y" ^ var.docky}
