"""Manual robot test: movement primitives.

EXPECTED: Cozmo drives forward, rotates each way, reverses, moves its lift
through up/down, and its head through up/down/forward, narrating each step.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: movements ===")
    print("EXPECTED: drive forward, rotate, reverse, move lift and head in order.")
    set_volume_low()

    say("moving forward 10 centimeters")
    move_forward(10)
    say("rotating 90 degrees")
    rotate_in_place(90)
    say("rotating back")
    rotate_in_place(-90)
    say("reversing 10 centimeters")
    reverse(10)

    say("lift up")
    move_lift_up()
    say("lift down")
    move_lift_ground()

    say("head up")
    move_head_looking_up()
    say("head down")
    move_head_looking_down()
    say("head forward")
    move_head_looking_forward()

    print("DONE: confirm each motion happened, in order.")


if __name__ == "__main__":
    run_program(cozmo_program)
