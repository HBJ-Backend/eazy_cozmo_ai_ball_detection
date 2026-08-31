def _say_error(errormsg, *args):
    """**Say "ERROR" followed by a message**

    Cozmo will indicate using its voice that an error occurred.  It
    also prints a message in the console indicating the error
    message.

    :return: True (suceeded) or False (failed)
    """
    from .easy_cozmo import _robot

    #errormsg = "ERROR, "+errormsg
    errormsg = errormsg + ' '.join(map(str, args))
    print("ERROR ",errormsg)
#    _robot.say_text(errormsg).wait_for_completed()

def say_error(errormsg):
    """**Say "ERROR" followed by a message**

    Cozmo will indicate using its voice that an error occurred.  It
    also prints a message in the console indicating the error
    message.

    :return: True (suceeded) or False (failed)
    """
    from .easy_cozmo import _robot

    errormsg = "ERROR, "+errormsg
    print(errormsg)
    _robot.say_text(errormsg).wait_for_completed()

def say(txtmsg, *args, duration_scalar=None, voice_pitch=None,
        use_cozmo_voice=None):
    """**Say a simple message**

    Cozmo will read a message and display the message in the
    console.

    ..  note::

            This function receives a variable number or arguments. All arguments will be concatenated and delimited by a space, in order to compose the message. This is useful to compose sentences.

    :param duration_scalar: below 1.0 speaks faster, above 1.0 slower.
        Defaults to df_say_duration_scalar.
    :param voice_pitch: -1.0 to 1.0. Defaults to df_say_voice_pitch.
    :param use_cozmo_voice: False for a plain human voice instead of Cozmo's.
        Defaults to df_say_use_cozmo_voice.

    :return: True (suceeded) or False (failed)
    """

    from .easy_cozmo import _robot
    from . import defaults

    txtmsg = txtmsg + ' '.join(map(str, args))
    print("SAY: "+txtmsg)
    # Read the defaults at call time, so a program can change them mid-run.
    _robot.say_text(
        txtmsg,
        duration_scalar=(defaults.df_say_duration_scalar
                         if duration_scalar is None else duration_scalar),
        voice_pitch=(defaults.df_say_voice_pitch
                     if voice_pitch is None else voice_pitch),
        use_cozmo_voice=(defaults.df_say_use_cozmo_voice
                         if use_cozmo_voice is None else use_cozmo_voice),
    ).wait_for_completed()

def _say(txtmsg, *args):
    """**Print  a simple message **

    Cozmo will read a message and display the message in the
    console.

    ..  note::

            This function receives a variable number or arguments. All arguments will be concatenated and delimited by a space, in order to compose the message. This is useful to compose sentences.

    :return: True (suceeded) or False (failed)
    """

    from .easy_cozmo import _robot

    txtmsg = txtmsg + ' '.join(map(str, args))
    print("SAY: "+txtmsg)
