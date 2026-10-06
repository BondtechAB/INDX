; INDX_TOOL_CHECK - confirm a tool is on the head before the nozzle is used as the probe
; M98 P"INDX_TOOL_CHECK.g" [S"<caller name>"]
; global.INDX_State must be a tool number and that tool must be selected. A short heat check
; then confirms the tool is physically there: the nozzle reading must rise by
; INDX_TC_heat_rise within INDX_TC_heat_timeout. The heater is returned to its previous target.

var who = exists(param.S) ? param.S : "INDX_TOOL_CHECK"
var t = global.INDX_State
if var.t < 0 || var.t >= #global.INDX_tool_x || state.currentTool != var.t
  abort {var.who ^ ": no tool loaded and selected (global.INDX_State = " ^ var.t ^ ", selected tool " ^ state.currentTool ^ ")."}
if heat.heaters[1].state = "fault"
  abort {var.who ^ ": heater fault. Check the head, then clear it with M562 P1."}

var old_s = tools[var.t].active[0]
var was_on = heat.heaters[1].state = "active"
var t0 = heat.heaters[1].current
M568 P{var.t} S{max(var.old_s, var.t0 + global.INDX_TC_heat_delta)} A2
var peak = var.t0
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
    break

; heater back to its previous target and state
if var.was_on && !var.faulted
  M568 P{var.t} S{var.old_s} A2
else
  M568 P{var.t} S{var.old_s} A0

if var.faulted || var.peak - var.t0 < global.INDX_TC_heat_rise
  abort {var.who ^ ": global.INDX_State is " ^ var.t ^ " but the heat check found no tool (rise " ^ (var.peak - var.t0) ^ " C). Check the head, correct global.INDX_State, and clear any heater fault with M562 P1."}

if global.INDX_DEBUG > 0
  echo {var.who ^ ": T" ^ var.t ^ " confirmed on the head (rise " ^ (var.peak - var.t0) ^ " C in " ^ var.waited ^ " ms)"}
