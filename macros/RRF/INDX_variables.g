; INDX_variables.g - INDX global variables
; Called at the end of config.g. Can be run again at any time to apply edits: each variable is
; declared if missing, otherwise set. Values saved by INDX_WRITE_STATE are restored at the end.
; INDX_State and INDX_TC_log keep their live values when this file is run again.

; --- Tool docks (machine coordinates) ---
; X centre of each dock; index = tool number
if !exists(global.INDX_tool_x)
  global INDX_tool_x = {-110, -65.5, -19, 27}   ; mm
else
  set global.INDX_tool_x = {-110, -65.5, -19, 27}

; Y at which a tool is fully seated, shared by every dock
if !exists(global.INDX_dock_y)
  global INDX_dock_y = -127           ; mm
else
  set global.INDX_dock_y = -127

; heaterless tool, selected only to drive the latch when no INDX tool is selected
if !exists(global.INDX_latch_tool)
  global INDX_latch_tool = 9
else
  set global.INDX_latch_tool = 9
M563 P{global.INDX_latch_tool} S"INDX latch" D0 F-1

; Y direction into the dock: -1 = docks at minimum Y, +1 = docks at maximum Y
if !exists(global.INDX_dock_dir)
  global INDX_dock_dir = -1
else
  set global.INDX_dock_dir = -1

; distance from the dock line back to the trigger line, where the latch is worked
if !exists(global.INDX_trigger_offset)
  global INDX_trigger_offset = 5.0    ; mm
else
  set global.INDX_trigger_offset = 5.0

; peel off the docking pins after a park or a pickup
if !exists(global.INDX_peel_distance)
  global INDX_peel_distance = 10.0    ; mm
else
  set global.INDX_peel_distance = 10.0

; Z raised before travelling to a dock, 0 = none
if !exists(global.INDX_z_hop)
  global INDX_z_hop = 1.0             ; mm
else
  set global.INDX_z_hop = 1.0

; minimum Y for all moves except tool changes (clear of the docked tools)
if !exists(global.safeYmin)
  global safeYmin = -100              ; mm
else
  set global.safeYmin = -100

; Y minimum from config.g, read once at boot, then the Y axis limit is raised to safeYmin
if !exists(global.INDX_Y_hard_min)
  global INDX_Y_hard_min = move.axes[1].min
M208 S1 Y{max(global.safeYmin, global.INDX_Y_hard_min)}

; --- Tool change speeds ---
if !exists(global.INDX_TC_SPEED)
  global INDX_TC_SPEED = 24000        ; mm/min; travel speed
else
  set global.INDX_TC_SPEED = 24000
; multiplier on INDX_TC_SPEED (1.0 full speed, 0.7 normal, 0.3 quiet)
if !exists(global.INDX_TC_MODE)
  global INDX_TC_MODE = 1.0
else
  set global.INDX_TC_MODE = 1.0
; XY moves within INDX_TC_slow_zone of the dock line run at no more than INDX_TC_contact_speed
if !exists(global.INDX_TC_contact_speed)
  global INDX_TC_contact_speed = 1000 ; mm/min
else
  set global.INDX_TC_contact_speed = 1000
if !exists(global.INDX_TC_slow_zone)
  global INDX_TC_slow_zone = 10       ; mm from the dock line, never less than INDX_trigger_offset
else
  set global.INDX_TC_slow_zone = 10

; --- Tool change checks ---
if !exists(global.INDX_TC_check_action)
  global INDX_TC_check_action = 0     ; 0 = report a failed check, 1 = abort the tool change
else
  set global.INDX_TC_check_action = 0
; check log file, "" = no log; set at run time, so not reset when this file is run again
if !exists(global.INDX_TC_log)
  global INDX_TC_log = ""
if !exists(global.INDX_TC_lc_samples)
  global INDX_TC_lc_samples = 4       ; load cell reads averaged per reading
else
  set global.INDX_TC_lc_samples = 4
if !exists(global.INDX_TC_lc_min_g)
  global INDX_TC_lc_min_g = 700       ; g; minimum clamp force change for a pickup or drop-off
else
  set global.INDX_TC_lc_min_g = 700
if !exists(global.INDX_TC_heat_delta)
  global INDX_TC_heat_delta = 10      ; C; pickup heat check target above the current reading
else
  set global.INDX_TC_heat_delta = 10
if !exists(global.INDX_TC_heat_rise)
  global INDX_TC_heat_rise = 3        ; C; rise that confirms a tool is present
else
  set global.INDX_TC_heat_rise = 3
if !exists(global.INDX_TC_heat_timeout)
  global INDX_TC_heat_timeout = 5     ; s
else
  set global.INDX_TC_heat_timeout = 5
if !exists(global.INDX_TC_drop_temp_min)
  global INDX_TC_drop_temp_min = 70   ; C; drop-off temperature check only above this
else
  set global.INDX_TC_drop_temp_min = 70
if !exists(global.INDX_TC_drop_temp_dx)
  global INDX_TC_drop_temp_dx = -20   ; mm; X move from the dock along safeYmin before the drop-off temperature reading
else
  set global.INDX_TC_drop_temp_dx = -20
if !exists(global.INDX_TC_drop_temp_fall)
  global INDX_TC_drop_temp_fall = 10  ; C; fall beyond the expected cooling that confirms the drop-off
else
  set global.INDX_TC_drop_temp_fall = 10
if !exists(global.INDX_TC_drop_dwell)
  global INDX_TC_drop_dwell = 1000    ; ms; wait at the clear position before reading
else
  set global.INDX_TC_drop_dwell = 1000

; --- Tool change state, used by the tool-change macros ---
; INDX_State: -1 = latch open, no tool; 0..n = that tool locked on; 99 = latch closed, tool unknown
; set from indx-state.g at startup; when this file is run again the live value is kept
var startup = !exists(global.INDX_State)
if var.startup
  global INDX_State = -1
if !exists(global.INDX_TC_count)
  global INDX_TC_count = 0            ; tool changes since boot, written to the check log
else
  set global.INDX_TC_count = 0
if !exists(global.INDX_TC_in_active)
  global INDX_TC_in_active = 0
else
  set global.INDX_TC_in_active = 0
if !exists(global.INDX_TC_restore_z)
  global INDX_TC_restore_z = -1
else
  set global.INDX_TC_restore_z = -1
; check results of the last tool change: 1 pass, 0 fail, -1 not run
if !exists(global.INDX_TC_drop_lc_ok)
  global INDX_TC_drop_lc_ok = -1
else
  set global.INDX_TC_drop_lc_ok = -1
if !exists(global.INDX_TC_drop_temp_ok)
  global INDX_TC_drop_temp_ok = -1
else
  set global.INDX_TC_drop_temp_ok = -1
if !exists(global.INDX_TC_pick_lc_ok)
  global INDX_TC_pick_lc_ok = -1
else
  set global.INDX_TC_pick_lc_ok = -1
if !exists(global.INDX_TC_pick_heat_ok)
  global INDX_TC_pick_heat_ok = -1
else
  set global.INDX_TC_pick_heat_ok = -1
if !exists(global.INDX_TC_lc_before)
  global INDX_TC_lc_before = 0
else
  set global.INDX_TC_lc_before = 0
if !exists(global.INDX_LC_raw)
  global INDX_LC_raw = 0              ; counts, written by INDX_LC_RAW
else
  set global.INDX_LC_raw = 0
; empty-head load cell reading at each dock (dock X, safeYmin), stored after a verified change
if !exists(global.INDX_LC_empty_ref)
  global INDX_LC_empty_ref = vector(#global.INDX_tool_x, null)
else
  set global.INDX_LC_empty_ref = vector(#global.INDX_tool_x, null)
if !exists(global.INDX_LC_raw_spread)
  global INDX_LC_raw_spread = 0
else
  set global.INDX_LC_raw_spread = 0

; --- Load cell calibration (saved values are restored at the end) ---
if !exists(global.INDX_LC_offset)
  global INDX_LC_offset = 0           ; counts; unloaded reading, set by INDX_TARE during calibration
else
  set global.INDX_LC_offset = 0
if !exists(global.INDX_LC_scale)
  global INDX_LC_scale = 0.11         ; g/count; the M558 V value, set by INDX_LC_CAL
else
  set global.INDX_LC_scale = 0.11
if !exists(global.INDX_LC_scale_limits)
  global INDX_LC_scale_limits = {0.05, 0.5} ; g/count; accepted range of the scale magnitude
else
  set global.INDX_LC_scale_limits = {0.05, 0.5}
if !exists(global.INDX_LC_locking_force)
  global INDX_LC_locking_force = 1600 ; g; calibration force from Bondtech
else
  set global.INDX_LC_locking_force = 1600
if !exists(global.INDX_LC_samples)
  global INDX_LC_samples = 16         ; reads averaged per calibration reading
else
  set global.INDX_LC_samples = 16
if !exists(global.INDX_LC_calibrated)
  global INDX_LC_calibrated = false
else
  set global.INDX_LC_calibrated = false

; --- Load cell probing ---
if !exists(global.INDX_LC_trigger_grams)
  global INDX_LC_trigger_grams = 50   ; g; trigger force, applied as G31 K0 P
else
  set global.INDX_LC_trigger_grams = 50
; M558 K0 U preload window in g; disabled when hi <= lo
if !exists(global.INDX_LC_preload_lo)
  global INDX_LC_preload_lo = 0
else
  set global.INDX_LC_preload_lo = 0
if !exists(global.INDX_LC_preload_hi)
  global INDX_LC_preload_hi = 0
else
  set global.INDX_LC_preload_hi = 0

; --- Mesh area in probe coordinates, shared by both probes ---
if !exists(global.INDX_mesh_min)
  global INDX_mesh_min = {-100, -100} ; mm; X, Y
else
  set global.INDX_mesh_min = {-100, -100}
if !exists(global.INDX_mesh_max)
  global INDX_mesh_max = {100, 90}    ; mm; X, Y
else
  set global.INDX_mesh_max = {100, 90}
if !exists(global.INDX_mesh_spacing)
  global INDX_mesh_spacing = 30       ; mm
else
  set global.INDX_mesh_spacing = 30

; --- homez probe point (machine coordinates) ---
if !exists(global.INDX_LC_probe_fuzz)
  global INDX_LC_probe_fuzz = 0       ; mm; random offset of the probe point, 0 = none
else
  set global.INDX_LC_probe_fuzz = 0
if !exists(global.INDX_probe_x)
  global INDX_probe_x = 0             ; mm
else
  set global.INDX_probe_x = 0
if !exists(global.INDX_probe_y)
  global INDX_probe_y = 0             ; mm
else
  set global.INDX_probe_y = 0

; 1 = macros echo progress, 0 = quiet; the saved value is restored below
if !exists(global.INDX_DEBUG)
  global INDX_DEBUG = 0
else
  set global.INDX_DEBUG = 0

; restore the values saved by INDX_WRITE_STATE; INDX_State only at startup
if fileexists("0:/sys/indx-state.g")
  var live_state = global.INDX_State
  M98 P"0:/sys/indx-state.g"
  if !var.startup
    set global.INDX_State = var.live_state

; apply the scale, trigger force and preload window to probe K0; G31 offsets stay as set in config.g
if global.INDX_LC_calibrated
  M558 K0 V{global.INDX_LC_scale}
G31 K0 P{global.INDX_LC_trigger_grams}
if global.INDX_LC_preload_hi > global.INDX_LC_preload_lo
  M558 K0 U{global.INDX_LC_preload_lo}:{global.INDX_LC_preload_hi}
