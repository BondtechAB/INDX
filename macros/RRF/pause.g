;G1 E-2 F6000
G91 			; use relative positioning
G1 H2 Z5 F5000		; lift Z 5mm
G90 			; back to absolute positioning
G1 X-168 Y{global.safeYmin} F14000	; move out the way.
