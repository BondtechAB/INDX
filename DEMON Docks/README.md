<img width="4032" height="3024" alt="INDX DEMON DOCK" src="https://github.com/user-attachments/assets/d8f38666-45f0-4694-b0a7-2330c001832c" />

# INDX DEMON DOCKS!

Add dock sensing to your INDX system! Use this modified standard INDX dock so installs & dock placement DO NOT change! You just need a MCU to manage the docks & a cable run from the docks to said MCU.

<br>

NOTE: Requires [DEMON_INDX](https://github.com/3DPrintDemon/DEMON_INDX/tree/main/macros) macros

<br>

This system allows active tool sensing with load cell confirmation for all attached docks with simple & accurate switch connection to a non-critical MCU. 

DEMON_DOCKS will auto scan for empty docks at startup & disable sensing for those docks. They can be added back into active docks (or removed again) at runtime by command/macro button. The docks can be set to warn only of a potential problem, raise errors if not printing, PAUSE the print if printing, emergency stop if not printing, or emergency stop when printing. 

The load cell dock/undock confirmation can be set on/off at runtime.

The system warns of:

- Undocked tools at startup that will be ignored
- ignored docks during tool changes
- inactive tools undocked at any time
- problems during non-printing operations
- load cell readings out of range
- docking failures - printing & non-printing
- pickup (undocking) failures - printing & non-printing

DEMON_DOCKS then takes specified actions for each type of occurrence.

It can even pause a tool change while printing if a problem is detected!

# BOM

- x1 (or more) MCU(s) capable of handling the amount of tools & dock sensors you have.
  I chose a BTT MMB (v1.0) as that's what I had, a v1.1 would be better choice. A v2.0 would also work but would appear to have reduced ready to go pins for this. Should still be fine.
  All units also provide great scope for expansion! See the BTT Github for full capabilities.

- approximately 2m of 30-32 AWG x3 colours for each tool on a 350 sized Voron 2.4 style printer
  (So 6m of wire total for each tool over 3 colours. V+ = RED, V- = BLACK, Signal = OTHER)

- x1 D2F-5L switch per tool

- x1 5v 5mm LED (with resistor) per tool - colour of your choice
  The can be bought from most good stockists including Amazon

- x2 S-03-08-N magnets per tool dock (3mmx8mm)

- 1-1.5m Nylon expandable cable sleeve 10mm(ish) for your wires

- No extra bolts or other special hardware needed outside of the requirements of standard Bondtech docks
  You will still need the spring, S-05-08-N magnet, 1515 retaining bolt & nut, also printed Magnet holder slider & dock clip.



# Printing

- Print FMD ASA or PC or better (SLS)

- No supports are required - TURN THEM OFF NOW!

- Set layer height to 0.16-0.2mm - you want clean smooth prints!

- Infill should be 40%+ Gyroid


# Wiring

- 5v+ to switch NC (Normally Closed)

- v- & LED cathode to switch NO (Normally Open)

- Signal & LED anode (with resistor) to switch C or Comm (Common)

  <img width="3024" height="4032" alt="Dock Switch" src="https://github.com/user-attachments/assets/3cc2d705-6cde-496a-b49f-41e036a1ba1c" />



# Dock Assembly

- Pass wires through hole in mounting face

- Insert LED first nearest the bottom of the dock

- Make sure the switch lever is facing DOWNWARDS & not up!!

- Gently ease the parts together checking the wires DO NOT get pinched or damaged

  <img width="4032" height="3024" alt="Fit1" src="https://github.com/user-attachments/assets/4116d752-9e58-4c51-afb0-cb7238ffa602" />


- When fully seated the system should look like this! The switch body MUST be BELOW the surface of the switch mounting recess!

  <img width="4032" height="3024" alt="Fit2" src="https://github.com/user-attachments/assets/b60917c1-1e7a-4431-9636-3a4d175d604f" />




# Install magnets

Be sure to get the polarity correct!! Use a spare tool & add the magnets you intend to use & add them to the end of the tool's magnets so the they sit the correct way. Now offer the new magnets to your new docks & VERY CAREFULLY insert them into the holes in the dock. If they don't fit, it's probably the print, use the FMD specified model then or take a 3mm drill bit & expand the holes slightly. You'll probably have to use super glue if you do this. It's better to get a good fit & not drill them out.

Finish up by installing the rest of the standard Bontech dock hardware.


# Connect

Add plugs for your chosen MCU making sure the connections are correct for the board. Don't let the runs of wires get muddled. Twist each set of wires from each switch together as you go & tie a loose knot in the end while you're working. This will stop power from switch 7 getting hooked up to plug 0 or signal from switch 4 going to switch 2 for example! Keep things organised!

# Klipper setup

- Include the `DEMON_DOCKS.cfg` file & set your serial ID & switch count

- Include the `DEMON_DOCK_GUARDIANS.cfg` file

- open index.cfg & set `variable_demon_docks: True`

## If your Load Cell settings need changing...

- Home the printer then with a tool still loaded send...

```
LOAD_CELL_CHECK
```

- After the reading is shown in the console, look for the first number ending (g) `Load cell force`. So for example "Load cell force 138.0g" & add it to `variable_lc_loaded:`
  NOTE: the number doesn't have to be exactly the same as we have a wide tolerance range so 140 would be fine, we're looking for a rough average in the readings.

- Next `PARK_TOOL` so the toolhead is empty then send

```
LOAD_CELL_CHECK
```

- After the reading is shown in the console, look for the first number ending (g) `Load cell force`. So for example "Load cell force 1674.2g" & add it to `variable_lc_empty:`
  NOTE: the number doesn't have to be exactly the same as we have a wide tolerance range so 1700 would be fine, we're looking for a rough average in the readings.
  

- Save & Restart

# Testing the Docks

- The LED should light when a tool is removed & the console should tell you an inactive tool has been removed.

- The LED should go out when a tool is docked, there will be no console message.
