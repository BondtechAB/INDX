; INDX_TC_REPORT - log one tool-change check and act on a failure
; M98 P"INDX_TC_REPORT.g" E"<check>" T<tool> B<before> A<after> D<delta> X<extra> K<result>
; K: 1 pass, 0 fail, -1 not evaluated. On a fail, INDX_TC_check_action 0 reports, 1 aborts.
; Log columns: time_s,change,check,tool,before,after,delta,extra,result

if global.INDX_TC_log != ""
  if !fileexists(global.INDX_TC_log)
    echo >{global.INDX_TC_log} "time_s,change,check,tool,before,after,delta,extra,result"
  echo >>{global.INDX_TC_log} {(state.upTime + state.msUpTime / 1000) ^ "," ^ global.INDX_TC_count ^ "," ^ param.E ^ "," ^ param.T ^ "," ^ param.B ^ "," ^ param.A ^ "," ^ param.D ^ "," ^ param.X ^ "," ^ param.K}

if param.K = 0
  if global.INDX_TC_check_action > 0
    abort {"INDX tool change: " ^ param.E ^ " check FAILED for T" ^ param.T ^ " (before " ^ param.B ^ ", after " ^ param.A ^ ", change " ^ param.D ^ "). Check the head and dock by hand."}
  echo {"INDX tool change WARNING: " ^ param.E ^ " check failed for T" ^ param.T ^ " (before " ^ param.B ^ ", after " ^ param.A ^ ", change " ^ param.D ^ ")"}
elif global.INDX_DEBUG > 0
  echo {"INDX tool change: " ^ param.E ^ " T" ^ param.T ^ " before " ^ param.B ^ " after " ^ param.A ^ " change " ^ param.D ^ " result " ^ param.K}
