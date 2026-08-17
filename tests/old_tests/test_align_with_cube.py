from easy_cozmo import *

def cozmo_program():
    set_volume_low()
    if align_with_nearest_cube():
        say("Aligned success")
    else:
        say("Aligned failed")

run_program_with_viewer(cozmo_program)
