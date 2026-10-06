; INDX_LC_CALIBRATE - guided full load-cell calibration
;
; Walks the whole sequence with M291 dialogs, calling the step macros:
;   home X/Y (if needed) -> INDX_OPEN -> INDX_TARE -> [seat tool by hand]
;   -> INDX_CLOSE_CAL -> INDX_LC_CAL (computes + applies M558 V) -> [sign check] -> INDX_WRITE_STATE
; Z is NOT homed here - Z homing needs the calibrated load cell.
;
; M291 modes used: S3 = OK/Cancel (blocking), S2 = OK (blocking). Cancel on a
; confirmation aborts; Cancel on the save step just skips saving.
;
; A scale outside INDX_LC_scale_limits aborts INDX_LC_CAL and this macro; nothing is saved.

if !exists(global.INDX_State) || !exists(global.INDX_LC_scale) || !exists(global.INDX_LC_offset)
  abort "INDX_LC_CALIBRATE: INDX globals missing - is INDX_variables.g loaded from config.g?"
var dbg = exists(global.INDX_DEBUG) ? global.INDX_DEBUG : 0

; 1. intro + safety confirmation
M291 P"Calibrate INDX load cell. Ensure NO tool is mounted. X/Y home if needed. OK to start?" R"INDX Load Cell" S3
if result != 0
  abort "INDX_LC_CALIBRATE: cancelled by user."

; 2. home X and Y if not already homed (Z stays unhomed - it needs the calibrated cell)
if move.axes[0].homed = false || move.axes[1].homed = false
  if var.dbg > 0
    echo "INDX_LC_CALIBRATE: homing X and Y (Z not homed - needs the calibrated cell)..."
  G28 X Y

; 3. open the latch on the empty head, then tare
M291 P"Confirm there is NO tool on the Smart Head. OK to open the latch and capture the baseline." R"INDX Load Cell" S3
if result != 0
  abort "INDX_LC_CALIBRATE: cancelled by user."
if global.INDX_State != -1
  M98 P"INDX_OPEN.g"
; the head is empty, so no tool may stay selected
if state.currentTool >= 0
  M568 P{state.currentTool} A0 R0
  T-1 P0
M98 P"INDX_TARE.g"

; 4. manual step: seat a tool by hand
M291 P"Seat a passive tool on the Smart Head BY HAND, pushed fully home. OK when seated." R"INDX Load Cell" S3
if result != 0
  abort "INDX_LC_CALIBRATE: cancelled - latch left open, no tool locked."
M291 P{"Which tool was seated? 0 to " ^ (#global.INDX_tool_x - 1) ^ ", or -1 for a tool that has no dock."} R"INDX Load Cell" S5 L-1 H{#global.INDX_tool_x - 1} F-1
var seated = input

; 5. lock + seat the calibration force, then compute + apply the scale (M558 V)
M98 P"INDX_CLOSE_CAL.g"
; record and select the tool now locked on the head; a tool with no dock stays 99 (unknown)
if var.seated >= 0
  set global.INDX_State = var.seated
  T{var.seated} P0
  M568 P{var.seated} A0
M98 P"INDX_LC_CAL.g"

; 6. confirm the force sign; the inversion is for a head built the other way round
M291 P{"Scale applied: M558 V = " ^ global.INDX_LC_scale ^ " g/count. Press the nozzle UP by hand. The probe force in DWC should go POSITIVE. Does it?"} R"INDX Load Cell" S4 K{"Yes","No"}
if input = 1
  ; unexpected: force went the wrong way - invert the scale sign, re-apply, and re-check
  set global.INDX_LC_scale = -global.INDX_LC_scale
  M558 K0 V{global.INDX_LC_scale}
  if var.dbg > 0
    echo {"INDX_LC_CALIBRATE: inverted scale to " ^ global.INDX_LC_scale ^ " g/count and re-applied M558 V."}
  M291 P{"Scale inverted: M558 V = " ^ global.INDX_LC_scale ^ " g/count. Press the nozzle UP again. Does the force now go POSITIVE?"} R"INDX Load Cell" S4 K{"Yes","Cancel"}
  if input = 1
    abort "INDX_LC_CALIBRATE: force sign wrong in BOTH directions - the load cell is not responding correctly. Check wiring and V; not saved."

; 7. offer to persist the result
M291 P{"Done. offset " ^ global.INDX_LC_offset ^ ", scale " ^ global.INDX_LC_scale ^ " g/count. OK to save, Cancel to skip."} R"INDX Load Cell" S3
if result = 0
  M98 P"INDX_WRITE_STATE.g"
  if var.dbg > 0
    echo "INDX_LC_CALIBRATE: saved via INDX_WRITE_STATE."
else
  if var.dbg > 0
    echo "INDX_LC_CALIBRATE: not saved (INDX_WRITE_STATE skipped)."

; 8. re-zero the cell at the current resting load
M98 P"INDX_LC_RETARE.g"

; 9. done - tool stays loaded for Z homing
M291 P"Load cell calibrated. Tool is loaded - run homez to home Z. Test-probe in the air first!" R"INDX Load Cell" S2
if var.dbg > 0
  echo "INDX_LC_CALIBRATE: complete. If you seated a dummy tool, load a real tool before homing Z."
