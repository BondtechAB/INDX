; INDX_LC_RETARE - zero the reported load cell force now
; No motion. The current load becomes the new zero (reported as loadCell.preload).
; Probing does not need this: the firmware tares at the start of every probing move.

if sensors.probes[0].type != 12
  abort "INDX_LC_RETARE: probe 0 is not a load cell probe (M558 P12) - check config.g."

var dbg = exists(global.INDX_DEBUG) ? global.INDX_DEBUG : 0

M558.4 K0

if var.dbg > 0
  echo {"INDX_LC_RETARE: tared. force " ^ sensors.probes[0].loadCell.force ^ " g, preload " ^ sensors.probes[0].loadCell.preload ^ " g"}
