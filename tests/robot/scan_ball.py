"""Manual robot test: detect the ball.

EXPECTED: Cozmo scans, finds the orange ball, and reports its distance (mm).

PREREQ: the YOLO detection server must be running (see README). It listens on
127.0.0.1:44444.
SETUP: place the orange ball in view, on the floor.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: detect the ball ===")
    print("EXPECTED: Cozmo finds the ball and reports a distance.")
    print("PREREQ: detection server running on 127.0.0.1:44444.")
    set_volume_low()

    if scan_for_ball(360):
        say("I see the ball")
        d = distance_to_ball()
        print(f"  ball distance (mm): {d}")
        if d is not None:
            say("the ball is " + str(int(d)) + " millimeters away")
    else:
        say("I could not find the ball")
        print("  ball not found")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
