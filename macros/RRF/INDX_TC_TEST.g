; INDX_TC_TEST - cycle every tool repeatedly and check each drop-off and pickup
;
; R&D macro, lives in 0:/macros:  M98 P"0:/macros/INDX_TC_TEST.g" N5 S1 H0
;   N  cycles, default 5. One cycle picks up T0, T1 ... the last tool in turn, then parks.
;   S1 stop at the first failed check (default). The tool-change macros abort at the
;      failing step, and this macro stops on its own extra check.
;   S0 log only and carry on. Use only while watching with a hand on the emergency stop:
;      a failed drop-off that does not stop means the next pickup drives a loaded head
;      into an occupied dock.
;   H  active temperature for every tool during the test, default 0 (cold). Above
;      INDX_TC_drop_temp_min the drop-off temperature check runs too, and each pickup
;      waits for the tool to reach H.
;
; Checks on top of the ones in every tool change:
;   clamp  - after each pickup, the load cell at one fixed position (X probe point,
;            safeYmin) against an empty-head reference taken there. Same position for
;            every tool, so tools can be compared with each other.
;   park   - after each park, the same reading should return to the empty reference;
;            what is left is logged as the residual (a tool still hanging on the head
;            would show its weight).
;
; Files:
;   0:/sys/indx_tc_checks.csv  every check written by the tool-change macros
;   0:/sys/indx_tc_test.csv    one row per change from this macro
;
; To stop early: set global.INDX_TC_test_stop = true. A macro started from the console
; blocks that console until it finishes, so to keep it free start the test as a job with
; M32 "0:/macros/INDX_TC_TEST.g" (the defaults above apply). Do not use Pause.
;
; If a tool-change macro aborts, the test stops there and INDX_TC_check_action and
; INDX_TC_log keep the test values. Re-run INDX_variables.g to put them back.

var cycles = exists(param.N) ? param.N : 5
var stopmode = exists(param.S) ? param.S : 1
var heat_t = exists(param.H) ? param.H : 0
var nt = #global.INDX_tool_x

if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
  abort "INDX_TC_TEST: home all axes first."
if !global.INDX_LC_calibrated
  abort "INDX_TC_TEST: load cell not calibrated - the load-cell checks need it."
while iterations < var.nt
  if iterations >= #tools || tools[iterations] = null
    abort {"INDX_TC_TEST: T" ^ iterations ^ " has a dock position but is not defined in config.g."}
if (global.INDX_State = -1) != (state.currentTool < 0)
  abort {"INDX_TC_TEST: head state " ^ global.INDX_State ^ " does not match selected tool " ^ state.currentTool ^ ". Sort out the head by hand first."}

var sf = "0:/sys/indx_tc_test.csv"
var saved_action = global.INDX_TC_check_action
var saved_log = global.INDX_TC_log
set global.INDX_TC_check_action = var.stopmode
set global.INDX_TC_log = "0:/sys/indx_tc_checks.csv"
if !exists(global.INDX_TC_test_stop)
  global INDX_TC_test_stop = false
set global.INDX_TC_test_stop = false
echo >{global.INDX_TC_log} "time_s,change,check,tool,before,after,delta,extra,result"
echo >{var.sf} "time_s,change,cycle,from,to,duration_s,clamp_g,spread,nozzle_C,drop_lc,drop_temp,pick_lc,pick_heat"

var speed = global.INDX_TC_SPEED * global.INDX_TC_MODE
var rx = global.INDX_probe_x
var ry = global.safeYmin
var scale = global.INDX_LC_scale

; clear of the bed for the whole test
G90
if move.axes[2].machinePosition < 10
  G53 G1 Z10 F900

; test temperature for every tool; standby 0 so docked tools cool
var i = 0
while var.i < var.nt
  M568 P{var.i} S{var.heat_t} R0
  set var.i = var.i + 1

; start with an empty head and take the empty reference
if state.currentTool >= 0
  T-1
  M400
G53 G1 X{var.rx} Y{var.ry} F{var.speed}
M98 P"INDX_LC_RAW.g" N8
var ref = global.INDX_LC_raw
var count0 = global.INDX_TC_count
echo {"INDX_TC_TEST: " ^ var.cycles ^ " cycles of " ^ var.nt ^ " tools, S" ^ var.stopmode ^ ", H" ^ var.heat_t ^ ". Empty reference " ^ var.ref ^ " counts."}

var c = 0
var n = 0
var fails = 0
var t0 = 0.0
var dur = 0.0
var from = -1
var clamp = 0.0
var row = ""
var halt = false

while var.c < var.cycles && !var.halt
  set var.n = 0
  while var.n <= var.nt && !var.halt
    if global.INDX_TC_test_stop
      set var.halt = true
      break
    ; var.n = nt is the park at the end of the cycle
    set global.INDX_TC_drop_lc_ok = -1
    set global.INDX_TC_drop_temp_ok = -1
    set global.INDX_TC_pick_lc_ok = -1
    set global.INDX_TC_pick_heat_ok = -1
    set var.from = state.currentTool
    set var.t0 = state.upTime + state.msUpTime / 1000
    if var.n < var.nt
      T{var.n}
    else
      T-1
    M400
    set var.dur = state.upTime + state.msUpTime / 1000 - var.t0

    ; reading at the fixed position: clamp force after a pickup, residual after a park
    G53 G1 X{var.rx} Y{var.ry} F{var.speed}
    M98 P"INDX_LC_RAW.g" N8
    set var.clamp = (global.INDX_LC_raw - var.ref) * var.scale
    if var.n = var.nt
      set var.ref = global.INDX_LC_raw

    set var.row = (var.t0 + var.dur) ^ "," ^ global.INDX_TC_count ^ "," ^ var.c ^ "," ^ var.from ^ "," ^ state.currentTool ^ "," ^ var.dur ^ "," ^ var.clamp ^ ","
    set var.row = var.row ^ global.INDX_LC_raw_spread ^ "," ^ heat.heaters[1].current ^ "," ^ global.INDX_TC_drop_lc_ok ^ "," ^ global.INDX_TC_drop_temp_ok ^ ","
    echo >>{var.sf} {var.row ^ global.INDX_TC_pick_lc_ok ^ "," ^ global.INDX_TC_pick_heat_ok}

    if global.INDX_TC_drop_lc_ok = 0 || global.INDX_TC_drop_temp_ok = 0 || global.INDX_TC_pick_lc_ok = 0 || global.INDX_TC_pick_heat_ok = 0 || (var.n < var.nt && abs(var.clamp) < global.INDX_TC_lc_min_g)
      set var.fails = var.fails + 1
      echo {"INDX_TC_TEST: change " ^ global.INDX_TC_count ^ " (T" ^ var.from ^ " -> T" ^ state.currentTool ^ ") failed a check. Clamp " ^ var.clamp ^ " g."}
      if var.stopmode > 0
        set var.halt = true
    set var.n = var.n + 1
  set var.c = var.c + 1

; --- put things back ---
set global.INDX_TC_check_action = var.saved_action
set global.INDX_TC_log = var.saved_log
if var.heat_t > 0
  set var.i = 0
  while var.i < var.nt
    M568 P{var.i} S0 R0
    set var.i = var.i + 1
  if state.currentTool >= 0
    M568 P{state.currentTool} A0

echo {"INDX_TC_TEST: " ^ (global.INDX_TC_count - var.count0) ^ " changes, " ^ var.fails ^ " with a failed check. Logs: " ^ var.sf ^ " and 0:/sys/indx_tc_checks.csv"}
if var.halt && var.fails > 0
  abort "INDX_TC_TEST: stopped at a failed check - the head has been left where it stopped."
