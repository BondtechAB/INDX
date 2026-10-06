; INDX_TC_POST - lock the new tool on and leave the dock
; Called from tpostN.g: M98 P"INDX_TC_POST.g" T<n>
; Starts at the trigger line with the latch open (INDX_TC_PRE requires INDX_State = -1).
; All XY moves are G53 (machine coordinates).
; Checks: load cell (the clamp force appears) and a heat check run after the head has left the
; dock. The heat check heats to the tool's active temperature, or INDX_TC_heat_delta above the
; current reading if none is set, and the reading must rise by INDX_TC_heat_rise within
; INDX_TC_heat_timeout. The log records the time taken (s, -1 = not reached) in the extra column.

if !exists(param.T)
  abort "INDX_TC_POST: parameter T=<tool number> required."
var t = param.T
if var.t < 0 || var.t >= #global.INDX_tool_x
  abort {"INDX_TC_POST: T" ^ var.t ^ " has no entry in global.INDX_tool_x (" ^ #global.INDX_tool_x ^ " tools defined)."}
if state.currentTool != var.t
  abort {"INDX_TC_POST: T" ^ var.t ^ " expected but tool " ^ state.currentTool ^ " is selected - the latch move needs its own tool selected."}

var into = global.INDX_dock_dir
var docky = global.INDX_dock_y
var dockx = global.INDX_tool_x[var.t]
if var.dockx < move.axes[0].min || var.dockx > move.axes[0].max
  abort {"INDX_TC_POST: T" ^ var.t ^ " dock X " ^ var.dockx ^ " is outside the X limits."}
var speed = global.INDX_TC_SPEED * global.INDX_TC_MODE
var cs = global.INDX_TC_contact_speed
var trig = var.docky - var.into * global.INDX_trigger_offset

; RRF runs tpost even when tpre has aborted, so only continue from the trigger line tpre moves to
M400
if abs(move.axes[0].machinePosition - var.dockx) > 0.1 || abs(move.axes[1].machinePosition - var.trig) > 0.1
  abort {"INDX_TC_POST: head is not at the T" ^ var.t ^ " trigger line (X" ^ var.dockx ^ " Y" ^ var.trig ^ "), so INDX_TC_PRE did not complete. T" ^ var.t ^ " is selected but not picked up."}

; limits off until the head is back at safeYmin
var lim = move.limitAxes
M564 S0

; slide into the dock at contact speed
G90
G53 G1 X{var.dockx} Y{var.docky} F{min(2500, var.cs)}
M400

; lock the tool and save the state
M98 P"INDX_LATCH_MOVE.g" E11.0 F1500
set global.INDX_State = var.t
M98 P"INDX_WRITE_STATE.g"

; peel off the pins, back to safeYmin, limits back on
G53 G1 X{var.dockx} Y{var.docky - var.into * global.INDX_peel_distance} F{min(3000, var.cs)}
G53 G1 X{var.dockx} Y{global.safeYmin} F{var.speed}
M400
if var.lim
  M564 S1

; load-cell check, at the position of the empty-head reading
if global.INDX_LC_calibrated
  M98 P"INDX_LC_RAW.g"
  var dg = (global.INDX_LC_raw - global.INDX_TC_lc_before) * global.INDX_LC_scale
  set global.INDX_TC_pick_lc_ok = abs(var.dg) >= global.INDX_TC_lc_min_g ? 1 : 0
  M98 P"INDX_TC_REPORT.g" E"pick_lc" T{var.t} B{global.INDX_TC_lc_before} A{global.INDX_LC_raw} D{var.dg} X{global.INDX_LC_raw_spread} K{global.INDX_TC_pick_lc_ok}
  ; the clamp force appeared, so the reading before the pickup was an empty head: keep it as the dock's reference
  if global.INDX_TC_pick_lc_ok = 1
    set global.INDX_LC_empty_ref[var.t] = global.INDX_TC_lc_before

; Z back to the job height
if global.INDX_TC_restore_z >= 0
  G53 G1 Z{global.INDX_TC_restore_z} F900
  M400
  set global.INDX_TC_restore_z = -1

; heat check
var t0 = heat.heaters[1].current
var tgt = max(global.INDX_TC_in_active, var.t0 + global.INDX_TC_heat_delta)
M568 P{var.t} S{var.tgt} R0 A2
var time_on = state.upTime + state.msUpTime / 1000
var peak = var.t0
var rise_s = -1
var waited = 0
var faulted = false
while var.waited < global.INDX_TC_heat_timeout * 1000
  G4 P200
  set var.waited = var.waited + 200
  set var.peak = max(var.peak, heat.heaters[1].current)
  if heat.heaters[1].state = "fault"
    set var.faulted = true
    break
  if var.peak - var.t0 >= global.INDX_TC_heat_rise
    set var.rise_s = state.upTime + state.msUpTime / 1000 - var.time_on
    break
var rise = var.peak - var.t0
set global.INDX_TC_pick_heat_ok = (var.rise >= global.INDX_TC_heat_rise && !var.faulted) ? 1 : 0

; keep heating only if the tool responded and has an active temperature
if global.INDX_TC_pick_heat_ok = 1 && global.INDX_TC_in_active > 0
  M568 P{var.t} S{global.INDX_TC_in_active}
else
  M568 P{var.t} S{global.INDX_TC_in_active} A0

M98 P"INDX_TC_REPORT.g" E"pick_heat" T{var.t} B{var.t0} A{var.peak} D{var.rise} X{var.rise_s} K{global.INDX_TC_pick_heat_ok}
if var.faulted
  echo "INDX_TC_POST: heater fault during the pickup heat check - clear it with M562 P1 once the head is checked."

if global.INDX_TC_pick_heat_ok = 1 && global.INDX_TC_in_active > 0
  M116 P{var.t}

if global.INDX_DEBUG > 0
  echo {"INDX_TC_POST: T" ^ var.t ^ " locked on, target " ^ global.INDX_TC_in_active ^ "C"}
