"""Fake Cozmo SDK for the no-robot test suite.

The real ``cozmo`` package targets the legacy Anki/DDL SDK, needs a phone +
robot, and does not install on modern Python.  These fakes stand in for it so
the pure-Python parts of ``easy_cozmo`` (unit conversions, geometry, image
processing, control flow) can be tested with no hardware and no network.

Only the ``cozmo`` SDK is faked.  numpy / cv2 / PIL / imutils / scipy are the
real installed packages, so geometry and image tests exercise real code.
"""

import sys
import types
from unittest.mock import MagicMock


class Q:
    """A tagged quantity recording a unit + value.

    Stand-in for cozmo.util.degrees/radians/distance_mm/speed_mmps results so
    tests can assert on unit conversions (cm->mm, sign, etc.) by equality.
    """

    def __init__(self, unit, value):
        self.unit = unit
        self.value = value

    def __eq__(self, other):
        return (isinstance(other, Q)
                and self.unit == other.unit
                and self.value == other.value)

    def __hash__(self):
        return hash((self.unit, self.value))

    def __repr__(self):
        return "Q(%r, %r)" % (self.unit, self.value)


class _AutoModule(types.ModuleType):
    """A module whose every (non-dunder) attribute auto-resolves to a Mock.

    Dunder names raise AttributeError so the import machinery / isinstance /
    pickling are not confused by phantom attributes.  Real attributes set with
    ``setattr`` take precedence over this fallback.
    """

    def __getattr__(self, name):
        if name.startswith("__") and name.endswith("__"):
            raise AttributeError(name)
        return MagicMock()


# --- Real-ish classes the library relies on at import time -------------------

class Pose:
    """Real stand-in for cozmo.util.Pose (constructed at module/func scope)."""

    def __init__(self, x=0, y=0, z=0, angle_z=None, origin_id=None, **kwargs):
        self.x = x
        self.y = y
        self.z = z
        self.angle_z = angle_z
        self.origin_id = origin_id


class LightCube:
    """Real stand-in for cozmo.objects.LightCube (used in isinstance checks)."""
    pass


class CustomObject:
    """Real stand-in for cozmo.objects.CustomObject (used in isinstance)."""
    pass


class Annotator:
    """Real base class for cozmo.annotate.Annotator.

    BallAnnotator / LineAnnotator subclass it and call super().__init__(...).
    """

    def __init__(self, *args, **kwargs):
        pass


def _identity_annotator(fn):
    """cozmo.annotate.annotator decorator: applied at module scope, returns fn."""
    return fn


# --- Building the fake cozmo package -----------------------------------------

def install_fake_cozmo():
    """Install a fake ``cozmo`` package (and submodules) into sys.modules.

    Idempotent: marked with ``_easy_cozmo_fake`` so repeated calls are no-ops.
    """
    existing = sys.modules.get("cozmo")
    if existing is not None and getattr(existing, "_easy_cozmo_fake", False):
        return

    cozmo = _AutoModule("cozmo")
    cozmo._easy_cozmo_fake = True

    # cozmo.util: conversions return Q(...) so unit math is assertable;
    #               Pose is a real class.
    util = _AutoModule("cozmo.util")
    util.degrees = lambda v: Q("degrees", v)
    util.radians = lambda v: Q("radians", v)
    util.distance_mm = lambda v: Q("distance_mm", v)
    util.speed_mmps = lambda v: Q("speed_mmps", v)
    util.Pose = Pose

    # cozmo.objects: LightCube and CustomObject are real, for isinstance;
    #                  marker enums auto-resolve to mocks.
    objects = _AutoModule("cozmo.objects")
    objects.LightCube = LightCube
    objects.CustomObject = CustomObject

    # cozmo.annotate: Annotator is a real base class, annotator is an
    #                   identity decorator applied at module scope.
    annotate = _AutoModule("cozmo.annotate")
    annotate.Annotator = Annotator
    annotate.annotator = _identity_annotator

    robot = _AutoModule("cozmo.robot")
    world = _AutoModule("cozmo.world")
    faces = _AutoModule("cozmo.faces")
    anim = _AutoModule("cozmo.anim")
    # Stable Triggers object so its attributes (e.g. Triggers.CodeLabHappy) are
    # the same object on every access, allowing identity assertions in tests.
    anim.Triggers = MagicMock(name="anim.Triggers")

    audio = _AutoModule("cozmo.audio")
    # Same idea for AudioEvents, so beep assertions can compare identity.
    audio.AudioEvents = MagicMock(name="audio.AudioEvents")

    song = _AutoModule("cozmo.song")
    # Stable too: _AutoModule hands back a NEW mock on every attribute access,
    # so NoteTypes.C3 would not equal itself between calls.
    song.NoteTypes = MagicMock(name="song.NoteTypes")
    song.NoteDurations = MagicMock(name="song.NoteDurations")
    song.SongNote = MagicMock(name="song.SongNote")

    cozmo.util = util
    cozmo.objects = objects
    cozmo.annotate = annotate
    cozmo.robot = robot
    cozmo.world = world
    cozmo.faces = faces
    cozmo.anim = anim
    cozmo.audio = audio
    cozmo.song = song

    sys.modules["cozmo"] = cozmo
    sys.modules["cozmo.util"] = util
    sys.modules["cozmo.objects"] = objects
    sys.modules["cozmo.annotate"] = annotate
    sys.modules["cozmo.robot"] = robot
    sys.modules["cozmo.world"] = world
    sys.modules["cozmo.faces"] = faces
    sys.modules["cozmo.anim"] = anim
    sys.modules["cozmo.audio"] = audio
    sys.modules["cozmo.song"] = song


# --- Fake robot / actions / cubes --------------------------------------------

def _make_action(succeed=True):
    """A fake action returned by the robot's action-producing methods."""
    action = MagicMock(name="action")
    action.has_succeeded = bool(succeed)
    action.has_failed = not bool(succeed)
    action.is_running = False
    action.is_completed = True
    action.failure_reason = (0, "fake failure reason")
    action.result = None
    return action


# Robot methods that return an action object.
_ACTION_METHODS = (
    "turn_in_place",
    "set_head_angle",
    "set_lift_height",
    "drive_straight",
    "go_to_pose",
    "pickup_object",
    "place_on_object",
    "say_text",
    "play_song",
)


def make_robot(succeed=True):
    """Build a MagicMock robot suitable for the no-robot tests."""
    robot = MagicMock(name="robot")
    action = _make_action(succeed)
    for method_name in _ACTION_METHODS:
        getattr(robot, method_name).return_value = action

    robot.are_wheels_moving = False
    robot.world.visible_objects = []
    robot.world._objects = {}
    robot.pose.origin_id = 0
    return robot


def make_cube(cube_id=1, origin_id=0):
    """A real LightCube instance with .cube_id and .pose.origin_id."""
    cube = LightCube()
    cube.cube_id = cube_id
    cube.pose = types.SimpleNamespace(origin_id=origin_id)
    return cube


def make_face(name="", is_visible=True, known_expression=None):
    """A fake face object as exposed via robot.world.visible_faces.

    name="" means an unnamed (non-teammate) face; a non-empty name marks a
    registered teammate.
    """
    return types.SimpleNamespace(
        name=name, is_visible=is_visible, known_expression=known_expression)


# Runtime module that holds the global ``_robot``.
#   Phase 1: "easy_cozmo.easy_cozmo"
#   Phase 2: "easy_cozmo.core.easy_cozmo"
_RUNTIME_MODULE = "easy_cozmo.core.easy_cozmo"


def set_robot(robot):
    """Install ``robot`` as the library's global ``_robot``."""
    import importlib
    module = importlib.import_module(_RUNTIME_MODULE)
    module._robot = robot
    return robot
