"""Shared fixtures and import-time setup for the no-robot test suite.

The fake cozmo SDK MUST be installed before anything imports ``easy_cozmo``,
so it is installed here at module import time (conftest is imported by pytest
before the test modules).
"""

import os
import sys
import time

import pytest

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import sdk_fakes  # noqa: E402  (must come after sys.path tweak)

# Fake the cozmo SDK before easy_cozmo is imported anywhere.
sdk_fakes.install_fake_cozmo()

# Make the repo root importable so `import easy_cozmo` works.
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, os.pardir, os.pardir))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)


@pytest.fixture(autouse=True)
def _no_real_sleep(monkeypatch):
    """The library's pause() calls time.sleep; make it instant in tests."""
    monkeypatch.setattr(time, "sleep", lambda *args, **kwargs: None)


@pytest.fixture
def make_robot():
    """Factory: build a fake robot (succeeding or failing) and install it."""
    def _factory(succeed=True):
        robot = sdk_fakes.make_robot(succeed=succeed)
        sdk_fakes.set_robot(robot)
        return robot
    return _factory


@pytest.fixture
def robot(make_robot):
    """A succeeding fake robot, already installed as the library's _robot."""
    return make_robot(True)
