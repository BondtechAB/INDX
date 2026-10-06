; resurrect-prologue.g - prepare an INDX machine to resume a print from resurrect.g
; Called by resurrect.g with the machine coordinates of the stop point: X<x> Y<y> Z<z>.
; resurrect.g sets the tool temperatures before this file and selects the print tool after it
; with a normal T command. This file makes the selected tool match the head, homes X and Y,
; and sets Z: the head is taken to be pause_lift above the saved Z, where pause.g left it,
; unless Z is still homed.

var pause_lift = 5                 ; mm; must match the Z lift in pause.g

if !exists(param.X) || !exists(param.Y) || !exists(param.Z)
  abort "resurrect-prologue: X, Y and Z parameters missing - this file is called by resurrect.g."

; --- 1. heater safety, before anything else ---
; resurrect.g has already activated the print tool heater; turn it off if the head holds no tool
if global.INDX_State < 0 || global.INDX_State >= #global.INDX_tool_x
  while iterations < #global.INDX_tool_x
    M568 P{iterations} A0
if global.INDX_State = 99
  abort "resurrect-prologue: latch is closed but the tool is unknown (INDX_State 99). Sort out the head by hand and set global.INDX_State before resuming."
if global.INDX_State >= #global.INDX_tool_x
  abort {"resurrect-prologue: INDX_State " ^ global.INDX_State ^ " is not a tool defined in config.g."}

; --- 2. confirm what the head is believed to hold ---
var head = "no tool on the head"
if global.INDX_State >= 0
  set var.head = "T" ^ global.INDX_State ^ " locked on the head"
var zmsg = "Z is still homed."
if !move.axes[2].homed
  set var.zmsg = "Z is taken to be " ^ var.pause_lift ^ " mm above that, where pause.g left it."
var msg = "Saved state: " ^ var.head ^ ". Print stopped at X" ^ param.X ^ " Y" ^ param.Y ^ " Z" ^ param.Z ^ ". "
set var.msg = var.msg ^ var.zmsg ^ " Check the head matches and is clear of the docks, then OK to home X and Y."
M291 S3 R"Resume print" P{var.msg}

; --- 3. home X and Y ---
var zknown = move.axes[2].homed
G28 X Y

; --- 4. make the selected tool match the head, without running the tool-change macros ---
if global.INDX_State >= 0 && state.currentTool != global.INDX_State
  T{global.INDX_State} P0
elif global.INDX_State < 0 && state.currentTool >= 0
  T-1 P0

; --- 5. Z ---
; G92 sets the user position, so the selected tool Z offset is added
if !var.zknown
  var zoff = 0.0
  if state.currentTool >= 0
    set var.zoff = tools[state.currentTool].offsets[2]
  G92 Z{param.Z + var.pause_lift + var.zoff}

echo {"resurrect-prologue: " ^ var.head ^ ", X and Y homed, machine Z " ^ move.axes[2].machinePosition ^ ". resurrect.g now selects the print tool."}
