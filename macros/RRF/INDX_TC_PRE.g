; INDX_TC_PRE - move the head to the trigger line of the dock of the tool about to be picked up
; Called from tpreN.g: M98 P"INDX_TC_PRE.g" T<n>
; Positions only. No tool is selected while tpre runs and RRF discards E moves without a
; selected tool, so the latch is worked in INDX_TC_POST.
; All XY moves are G53 (machine coordinates).

if !exists(param.T)
  abort "INDX_TC_PRE: parameter T=<tool number> required."
var t = param.T
if var.t < 0 || var.t >= #global.INDX_tool_x
  abort {"INDX_TC_PRE: T" ^ var.t ^ " has no entry in global.INDX_tool_x (" ^ #global.INDX_tool_x ^ " tools defined)."}
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_TC_PRE: home X and Y first."
if global.INDX_State != -1
  abort {"INDX_TC_PRE: a tool is still on the head (global.INDX_State = " ^ global.INDX_State ^ "). Park it first, or select it with T" ^ global.INDX_State ^ " P0."}

var into = global.INDX_dock_dir
var dockx = global.INDX_tool_x[var.t]
var docky = global.INDX_dock_y
var trig = var.docky - var.into * global.INDX_trigger_offset

if var.dockx < move.axes[0].min || var.dockx > move.axes[0].max
  abort {"INDX_TC_PRE: T" ^ var.t ^ " dock X " ^ var.dockx ^ " is outside the X limits."}
if var.docky < global.INDX_Y_hard_min || var.docky > move.axes[1].max
  abort {"INDX_TC_PRE: dock Y " ^ var.docky ^ " is outside the Y limits."}

var speed = global.INDX_TC_SPEED * global.INDX_TC_MODE
var cs = global.INDX_TC_contact_speed
var slow_y = var.docky - var.into * max(global.INDX_TC_slow_zone, global.INDX_trigger_offset)
if (var.slow_y - global.safeYmin) * var.into < 0
  set var.slow_y = global.safeYmin

; count the change here only if no park ran first
if move.motionSystems[0].previousTool < 0
  set global.INDX_TC_count = global.INDX_TC_count + 1
set global.INDX_TC_pick_lc_ok = -1
set global.INDX_TC_pick_heat_ok = -1

; save and zero the active target: RRF heats a tool as soon as it is selected, before tpost
set global.INDX_TC_in_active = tools[var.t].active[0]
M568 P{var.t} A0 S0 R0

; Z hop, only when no park ran first
if move.axes[2].homed && global.INDX_z_hop > 0 && global.INDX_TC_restore_z < 0
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

; empty-head load-cell reading
if global.INDX_LC_calibrated
  M98 P"INDX_LC_RAW.g"
  set global.INDX_TC_lc_before = global.INDX_LC_raw
  ; presence: the reading must be within INDX_TC_lc_min_g of this dock's empty-head reading
  if global.INDX_LC_empty_ref[var.t] != null
    var pg = abs((global.INDX_TC_lc_before - global.INDX_LC_empty_ref[var.t]) * global.INDX_LC_scale)
    var pok = var.pg < global.INDX_TC_lc_min_g ? 1 : 0
    M98 P"INDX_TC_REPORT.g" E"head_empty" T{var.t} B{global.INDX_LC_empty_ref[var.t]} A{global.INDX_TC_lc_before} D{var.pg} X{global.INDX_LC_raw_spread} K{var.pok}
    if var.pok = 0
      abort {"INDX_TC_PRE: global.INDX_State is -1 but the load cell reads " ^ var.pg ^ " g above an empty head, so a tool appears to be on the head. Check the head before any tool change."}

; limits off beyond safeYmin; fast to the slow zone, then contact speed to the trigger line
var lim = move.limitAxes
M564 S0
G53 G1 X{var.dockx} Y{var.slow_y} F{var.speed}
G53 G1 X{var.dockx} Y{var.trig} F{var.cs}
M400
if var.lim
  M564 S1

if global.INDX_LC_DEBUG > 0
  echo {"INDX_TC_PRE: at the T" ^ var.t ^ " trigger line, X" ^ var.dockx ^ " Y" ^ var.trig}
