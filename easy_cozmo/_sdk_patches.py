"""Compatibility patches for the legacy Cozmo SDK and Pillow.

Applied on `import easy_cozmo`, so workshop programs get them without anyone
editing the installed cozmo or Pillow packages. Safe to call more than once,
and a failure here never stops the library importing.

Two problems are fixed, both of which break the camera viewer:

1. A cube observed at a degenerate pose can project to a NaN image box. The SDK
   passes it to PIL draw.text, int(NaN) raises ValueError, and the resulting
   async task exception spams the console and drops annotation frames. Non-finite
   boxes are skipped.

2. Pillow 10 removed ImageDraw.textsize(), which cozmo.annotate.ImageText.render
   still calls, freezing the viewer. It is restored using textbbox().
"""

import functools
import math

_applied = False


def apply():
    """Apply all SDK compatibility patches once (safe to call repeatedly)."""
    global _applied
    if _applied:
        return
    _applied = True
    for patch in (_patch_pillow_textsize, _patch_nan_image_box):
        try:
            patch()
        except Exception:
            # Never let a compatibility patch break `import easy_cozmo`.
            pass


def _patch_pillow_textsize():
    """Restore ImageDraw.textsize(), which Pillow 10 removed.

    The SDK anchors text against a bounding box using the returned height, by
    default from the bottom (y = box_bottom - height). The old textsize()
    returned the full line height, ascent plus descent. The tight ink bbox is
    shorter and would push the distance label off the bottom of the frame, so
    the full line height is what gets reproduced here.
    """
    from PIL import ImageDraw, ImageFont

    if hasattr(ImageDraw.ImageDraw, "textsize"):
        return  # Pillow < 10 still provides it.

    def textsize(self, text, font=None, *args, **kwargs):
        try:
            left, top, right, bottom = self.textbbox((0, 0), text, font=font)
        except Exception:
            left = top = right = bottom = 0
        resolved_font = font if font is not None else ImageFont.load_default()
        # Full line box per line, so bottom-anchored text stays on screen.
        try:
            ascent, descent = resolved_font.getmetrics()
            height = (text.count("\n") + 1) * (ascent + descent)
        except Exception:
            height = bottom - top
        # Width: advance width of the widest line (falls back to ink width).
        try:
            width = max(int(round(resolved_font.getlength(line)))
                        for line in text.split("\n"))
        except Exception:
            width = right - left
        return width, height

    ImageDraw.ImageDraw.textsize = textsize


def _make_safe_add_img_box(orig):
    """Wrap an add_img_box_to_image impl so it skips NaN/inf boxes."""

    @functools.wraps(orig)
    def safe_add_img_box_to_image(image, box, color, text=None):
        try:
            coords = (box.left_x, box.top_y, box.right_x, box.bottom_y)
        except Exception:
            # Unfamiliar box shape, let the original handle it.
            return orig(image, box, color, text=text)
        if not all(math.isfinite(v) for v in coords):
            return
        return orig(image, box, color, text=text)

    safe_add_img_box_to_image._easy_cozmo_patched = True
    return safe_add_img_box_to_image


def _patch_nan_image_box():
    """Make cozmo.annotate.add_img_box_to_image skip NaN/inf boxes."""
    from cozmo import annotate

    orig = getattr(annotate, "add_img_box_to_image", None)
    if not callable(orig) or getattr(orig, "_easy_cozmo_patched", False):
        return
    annotate.add_img_box_to_image = _make_safe_add_img_box(orig)
