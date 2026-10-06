; INDX_LATCH_MOVE - move the latch motor (the extruder drive) by E mm
; M98 P"INDX_LATCH_MOVE.g" E<mm> F<mm/min> [C<motor current mA>]
; RRF discards E moves when no tool is selected, so if none is selected the heaterless
; latch tool (global.INDX_latch_tool) is selected for the move and deselected afterwards.

if !exists(param.E) || !exists(param.F)
  abort "INDX_LATCH_MOVE: parameters E and F required."

var sel = state.currentTool < 0
if var.sel
  T{global.INDX_latch_tool} P0

; latch moves run on a cold tool
var cet = heat.coldExtrudeTemperature
var crt = heat.coldRetractTemperature
if var.cet > 0
  M302 P1

var ecur = move.extruders[0].current
M83
if exists(param.C)
  M906 E{param.C}
G1 E{param.E} F{param.F}
M400
if exists(param.C)
  M906 E{var.ecur}

if var.cet > 0
  M302 P0 S{var.cet} R{var.crt}

if var.sel
  T-1 P0
