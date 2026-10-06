; INDX_OPEN - plain latch open (E-11)
;
; The open used by tool pickup and by load-cell calibration - a plain E-11 with
; no Y wiggle. To release a tool seated in its dock use INDX_UNLOCK_DANCE.

if global.INDX_State = -1
  abort "INDX_OPEN: already flagged open (global.INDX_State = -1)."

; heater off before opening the latch (all INDX tools share heater H1)
if heat.heaters[1].state = "active" || heat.heaters[1].state = "standby"
  if state.currentTool >= 0
    M568 P{state.currentTool} A0
  else
    while iterations < #global.INDX_tool_x
      M568 P{iterations} A0
  echo "INDX_OPEN: tool heater switched off before opening the latch."

; latch value from Bondtech
M98 P"INDX_LATCH_MOVE.g" E-11.0 F1500

set global.INDX_State = -1
M98 P"INDX_WRITE_STATE.g"

; the head no longer holds the selected tool, so deselect it (standby 0 so nothing heats)
if state.currentTool >= 0
  M568 P{state.currentTool} A0 R0
  T-1 P0
