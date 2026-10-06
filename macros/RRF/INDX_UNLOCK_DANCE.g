; INDX_UNLOCK_DANCE - release a tool seated in its dock
; M98 P"INDX_UNLOCK_DANCE.g" X<dock X> Y<dock Y> [B<trigger offset, default 5.0>]
; X and Y are machine coordinates. Latch E moves alternate with Y moves, then a full open.

if global.INDX_State = -1
  abort "INDX_UNLOCK_DANCE: already flagged open (global.INDX_State = -1)."
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_UNLOCK_DANCE: home X and Y first (G28 X Y)."
if !exists(param.X) || !exists(param.Y)
  abort "INDX_UNLOCK_DANCE: parameters X and Y (machine X of the dock, machine Y where the tool is seated) required."

var dock_x = param.X
var dock_y = param.Y
var toff   = exists(param.B) ? param.B : 5.0
var into   = exists(global.INDX_dock_dir) ? global.INDX_dock_dir : -1
var trig   = var.dock_y - var.into * var.toff
var cs     = exists(global.INDX_TC_contact_speed) ? global.INDX_TC_contact_speed : 3000

; heater off through the selected tool (all INDX tools share heater H1)
if heat.heaters[1].state = "active" || heat.heaters[1].state = "standby"
  if state.currentTool >= 0
    M568 P{state.currentTool} A0
    echo "INDX_UNLOCK_DANCE: tool heater switched off before opening the latch."
  else
    while iterations < #global.INDX_tool_x
      M568 P{iterations} A0
    echo "INDX_UNLOCK_DANCE: no tool selected - heaters switched off across all tools."

; latch values from Bondtech
var squeeze_e   = -0.27
var wiggle_in_e = 0.27
var wiggle_out_e= -1.70
var dock_feedrate = 3000
var full_open_e = -11.0

G90

; the dock is below safeYmin, so axis limits are off for the dance
var lim = move.limitAxes
M564 S0

; 1. Squeeze release (soft current), then approach
M98 P"INDX_LATCH_MOVE.g" E{var.squeeze_e} F2000 C200
G53 G1 X{var.dock_x} Y{var.trig + var.into * 0.5} F{min(2000, var.cs)}

; 2. Wiggle in
M98 P"INDX_LATCH_MOVE.g" E{var.wiggle_in_e} F2000
G53 G1 X{var.dock_x} Y{var.trig + var.into * 1.0} F{min(2000, var.cs)}

; 3. Wiggle out
M98 P"INDX_LATCH_MOVE.g" E{var.wiggle_out_e} F2500
G53 G1 X{var.dock_x} Y{var.trig + var.into * 2.0} F{min(2500, var.cs)}

; 4. Slide to dock
G53 G1 X{var.dock_x} Y{var.dock_y} F{min(var.dock_feedrate, var.cs)}
M400

; 5. Stationary full open
M98 P"INDX_LATCH_MOVE.g" E{var.full_open_e} F1500
if var.lim
  M564 S1

set global.INDX_State = -1
