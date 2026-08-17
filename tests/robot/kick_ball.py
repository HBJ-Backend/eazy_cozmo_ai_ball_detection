"""Manual robot test: kick the ball.

EXPECTED: Cozmo finds the ball, aligns with it, kicks it, then celebrates.

PREREQ: the YOLO detection server must be running (see README). It listens on
127.0.0.1:44444.
SETUP: place the orange ball a short distance in front of Cozmo.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: kick the ball ===")
    print("EXPECTED: Cozmo finds the ball, aligns, and kicks it.")
    print("PREREQ: detection server running on 127.0.0.1:44444.")
    set_volume_low()

    if scan_for_ball(360):
        if align_with_ball():
            say("kicking")
            kick()
            show_happy()
            print("  kicked: OK")
        else:
            say("could not align with the ball")
            print("  align FAILED")
    else:
        say("I could not find the ball")
        print("  ball not found")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
