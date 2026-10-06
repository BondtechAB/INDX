; INDX_LC_SPEED_SWEEP - measure Z probe repeatability against probing feed rate
;
; Diagnostic macro. Probes the same spot repeatedly at each feed rate in var.feeds and reports
; the scatter, so you can choose the F value for the M558 in config.g. Results are always
; echoed, whatever INDX_DEBUG is set to.
;
; This is the one macro that changes the probe configuration, because varying the feed rate is
; the whole point. It reads the current settings from the object model first and puts them back
; at the end, so config.g remains the source of truth.
;
; Requires Z homed (homez), a tool loaded, and a calibrated load cell. It does not change the
; Z datum: every probe is G30 S-1, which reports the trigger height without setting anything.
;
; What the columns mean, per feed rate:
;   mean    average trigger height. Comparing means ACROSS feed rates shows any speed-dependent
;           bias (overshoot), which is separate from repeatability. Measured bias is only a few
;           microns up to about F500, rising at higher feeds.
;   spread  max - min, the worst-case error over the run.
;   sd      standard deviation - the number to compare when choosing a feed rate.
;   1st-off how far the discarded first probe sat from the mean, in microns.
; The first probe at each feed rate is taken and reported but excluded from the statistics,
; because the first probe after a change of direction or a tool reseat tends to be an outlier.

; --- knobs ---
var feeds = {100,200,300,400,500,600} ; mm/min; feed rates to test
var nprobe = 5                        ; probes per feed rate used for the statistics

if move.axes[2].homed = false
  abort "INDX_LC_SPEED_SWEEP: home Z first (homez)."
if global.INDX_State = -1
  abort "INDX_LC_SPEED_SWEEP: no tool loaded - the nozzle probes the bed."
if global.INDX_LC_calibrated = false
  abort "INDX_LC_SPEED_SWEEP: load cell not calibrated (run INDX_LC_CALIBRATE)."
if var.nprobe < 2
  set var.nprobe = 2

; current probe settings, so they can be restored afterwards
var s0 = sensors.probes[0].speeds[0]
var s1 = sensors.probes[0].speeds[1]
var d0 = sensors.probes[0].diveHeights[0]
var d1 = sensors.probes[0].diveHeights[1]
var taps = sensors.probes[0].maxProbeCount
var tol = sensors.probes[0].tolerance

var nf = #var.feeds
var sd_best = 0.0
var f_best = 0

; probe the configured point (bed centre), offset so the PROBE lands there. No fuzz: a
; repeatability test must stay on the same spot.
var px = (exists(global.INDX_probe_x) ? global.INDX_probe_x : 0) - sensors.probes[0].offsets[0]
var py = (exists(global.INDX_probe_y) ? global.INDX_probe_y : 0) - sensors.probes[0].offsets[1]
G90
G1 Z5 F600
G1 X{var.px} Y{var.py} F12000

echo {"INDX_LC_SPEED_SWEEP: " ^ var.nf ^ " feed rates, " ^ var.nprobe ^ " probes each (+1 discarded)"}
echo "feed    mean        spread   sd     1st-off"

var f = 0
var i = 0
var z = 0.0
var first = 0.0
var zsum = 0.0
var zsumsq = 0.0
var zmin = 0.0
var zmax = 0.0
var mean = 0.0
var variance = 0.0
var sd = 0.0
var spread = 0.0

while var.f < var.nf
  ; single probe per G30 so the scatter is visible, dive heights as configured
  M558 K0 F{var.feeds[var.f]} A1 H{var.d0}:{var.d1}

  ; first probe at this feed rate - reported, but kept out of the statistics
  G90
  G1 Z{var.d1} F600
  G30 S-1
  set var.first = move.axes[2].machinePosition

  set var.i = 0
  set var.zsum = 0.0
  set var.zsumsq = 0.0
  while var.i < var.nprobe
    G90
    G1 Z{var.d1} F600
    G30 S-1
    set var.z = move.axes[2].machinePosition
    set var.zsum = var.zsum + var.z
    set var.zsumsq = {var.zsumsq + var.z * var.z}
    if var.i = 0
      set var.zmin = var.z
      set var.zmax = var.z
    else
      if var.z < var.zmin
        set var.zmin = var.z
      if var.z > var.zmax
        set var.zmax = var.z
    set var.i = var.i + 1

  set var.mean = var.zsum / var.nprobe
  set var.variance = {var.zsumsq / var.nprobe - var.mean * var.mean}
  if var.variance < 0
    set var.variance = 0
  set var.sd = sqrt(var.variance)
  set var.spread = var.zmax - var.zmin
  echo {"F" ^ var.feeds[var.f] ^ "  " ^ var.mean ^ "  " ^ round(var.spread * 1000) ^ "um  " ^ round(var.sd * 1000) ^ "um  " ^ round((var.first - var.mean) * 1000) ^ "um"}

  ; track the quietest feed rate
  if var.f = 0
    set var.sd_best = var.sd
    set var.f_best = var.feeds[var.f]
  elif var.sd < var.sd_best
    set var.sd_best = var.sd
    set var.f_best = var.feeds[var.f]
  set var.f = var.f + 1

; put the configured probe settings back and lift clear
M558 K0 F{var.s0}:{var.s1} A{var.taps} S{var.tol} H{var.d0}:{var.d1}
G90
G1 Z5 F600

echo {"INDX_LC_SPEED_SWEEP: lowest sd at F" ^ var.f_best ^ " (" ^ round(var.sd_best * 1000) ^ "um). Set the F parameter of the M558 in config.g."}
echo "Averaging (M558 A/S in config.g) divides sd by about sqrt(number of probes averaged)."
