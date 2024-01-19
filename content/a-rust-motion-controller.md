+++
title = "Motion Control for Everything"
date = "2024-01-19 11:11:13"
draft = true
+++

# I need your help

- Monthly income to pay the bills so I can focus on this project
- Hardware for testing
  - Will gladly accept anything that might help
  - But I'm specifically looking for:
    - Desktop(-ish) robot arms to test more complex kinematics
      - 5R parallel robots
      - Scara
      - Mini "normal" robot arms
    - Compact EtherCAT servo drives like the Beckhoff ELM72xx series
    - Dead cartesian machines (3D printers, cheapo CNCs, etc). Doesn't have to be beefy. It's just
      to test motion.
    - Any other specific kinematic setups you'd like to pay me to add support for.

# Scope of the project

- Open source
- Modular and hackable
- A Rust alternative to LinuxCNC
  - More modern trajectory planner. To my knowledge LinuxCNC is still trapezoidal - someone please
    correct me!
  - Much more modular so it can be improved more easily over time
  - Code that's easier to understand (IMO) - I'm a layman so be prepared for a lot of inline
    comments

# First stage goals

- A core of a motion controller with a pluggable architecture
- Initial plugins
  - Simple trajectory planner with circular blends and straight lines. Infinite jerk for now.
  - Cartesian kinematics module (passthrough)
  - GCode input supporting a small subset, i.e. straight lines and feed rate changes only
  - Basic UI _a la_ LinuxCNC's main window showing a DRO (position, velocity) and 3D view. Maybe
    some run/stop/reset buttons.
  - Both a simulator and some kind of simple driver system. Either EtherCrab or some
    minimal-yak-shave step gen hardware

# Immediate next goals

- Jerk limited trajectory planner with blends that are at least acceleration continuous
- Arc and spiral support in the trajectory planner

# Future aspirations

- Obtain/build a robot arm and add a more complex kinematics plugin

# Current progress

- Trapezoidal straight line trajectories coming on well. Jerk limited trajectories with better
  blends (not arcs) are an explicit next goal as this is a step up from LCNC.

- Arc blends.

- Currently in the `tp` repository. Code is extremely poor quality right now, but let's just say
  it's in the "research" phase ;)
