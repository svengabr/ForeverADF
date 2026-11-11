"""Builds the gallery images (1920x1080 JPG) from one /adf shots run.

    python media/gallery/gallery.py "<WoW folder>/_forever_/Screenshots"

/adf shots (Shots.lua) takes three screenshots, two seconds apart: the frame in the game world, the frame alone
in front of a plain dark sheet, and the options in front of that sheet. This script takes the newest such run
from the game's Screenshots folder, copies it unchanged to src/ (git-ignored: the pictures show your character
and chat) and makes two pictures from it:

  01-ingame.jpg   a 16:9 cut-out of the world picture around the frame. Where the frame is on the screen is
                  read from the second picture. The cut-out is enlarged to 1920x1080.
  02-options.jpg  the options with the frame above them, centred on the sheet's colour, not enlarged.

Options:

  --shift X Y     move the world cut-out by X and Y screenshot pixels (negative: left, up), to get the mob and
                  the frame into the picture together
  --only NAME     build only "ingame" or "options"; the other picture and its screenshots in src/ stay

Nothing is retouched; the debuffs in the pictures are the made-up ones /adf shots shows. The folder can also
come from the environment variable ADF_SCREENSHOTS. Needs Pillow and numpy.
"""
import argparse
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(HERE, "src")
W, H = 1920, 1080
GAP = 6        # seconds: pictures of one run are two seconds apart; a longer pause ends the run
ZOOM = 5.0     # the world cut-out is this many frame widths wide (at least 960 px)
MARGIN = 60


def shot_names():
    lua = open(os.path.join(ROOT, "Shots.lua"), encoding="utf-8").read()
    return re.findall(r'^\s*\{ "(\d\d-[a-z-]+)",', lua, re.M)


def collect(folder, wanted):
    names = shot_names()
    files = [os.path.join(folder, f) for f in os.listdir(folder) if f.lower().endswith((".jpg", ".png", ".tga"))]
    files.sort(key=os.path.getmtime)
    run = files[-1:]
    for path in reversed(files[:-1]):
        if os.path.getmtime(run[0]) - os.path.getmtime(path) > GAP:
            break
        run.insert(0, path)
    # /adf shots typed twice in a row: the last run counts
    if len(run) > len(names) and len(run) % len(names) == 0:
        run = run[-len(names):]
    if len(run) != len(names):
        sys.exit("The newest run has %d pictures, /adf shots takes %d. Nothing copied.\n"
                 "Run /adf shots again and take no other screenshot right before or after it." % (len(run), len(names)))
    os.makedirs(SRC, exist_ok=True)
    out = {}
    for name, path in zip(names, run):
        if name not in wanted:
            out[name] = os.path.join(SRC, name + ".jpg")
            continue
        target = os.path.join(SRC, name + os.path.splitext(path)[1].lower())
        shutil.copy2(path, target)
        out[name] = target
        print("%s  <-  %s" % (os.path.relpath(target, ROOT), os.path.basename(path)))
    return out


def content_box(img):
    """Bounding box of everything that is not the plain sheet."""
    a = np.asarray(img.convert("RGB")).astype(int)
    sheet = a[-3, 3]  # bottom left corner: never covered
    mask = np.abs(a - sheet).sum(axis=2) > 30
    ys, xs = np.where(mask)
    if len(xs) == 0:
        sys.exit("Nothing found in front of the sheet. Was the frame visible during /adf shots?")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1, tuple(int(v) for v in sheet)


def save(img, name):
    path = os.path.join(HERE, name)
    img.convert("RGB").save(path, quality=92, optimize=True, progressive=True, subsampling=0)
    print(os.path.relpath(path, ROOT))


def ingame(world_path, frame_path, shift):
    world = Image.open(world_path)
    x0, y0, x1, y1, _ = content_box(Image.open(frame_path))
    width = min(world.width, max(960, round((x1 - x0) * ZOOM)))
    height = round(width * H / W)
    if height > world.height:
        height = world.height
        width = round(height * W / H)
    # the frame sits in the lower middle of the picture, the mob it describes above it
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    left = min(max(0, round(cx - width / 2) + shift[0]), world.width - width)
    top = min(max(0, round(cy - height * 0.66) + shift[1]), world.height - height)
    cut = world.crop((left, top, left + width, top + height))
    print("world cut-out %d x %d at %d,%d (%d%%)" % (width, height, left, top, round(100 * W / width)))
    save(cut.resize((W, H), Image.LANCZOS), "01-ingame.jpg")


def options(path):
    img = Image.open(path)
    x0, y0, x1, y1, sheet = content_box(img)
    cut = img.crop((x0, y0, x1, y1))
    scale = min(1.0, (W - 2 * MARGIN) / cut.width, (H - 2 * MARGIN) / cut.height)
    if scale < 1.0:
        cut = cut.resize((round(cut.width * scale), round(cut.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), sheet)
    canvas.paste(cut, ((W - cut.width) // 2, (H - cut.height) // 2))
    print("options %d x %d (%d%%)" % (cut.width, cut.height, round(scale * 100)))
    save(canvas, "02-options.jpg")


def main():
    parser = argparse.ArgumentParser(description="Builds the gallery images from one /adf shots run.")
    parser.add_argument("folder", nargs="?", default=os.environ.get("ADF_SCREENSHOTS"))
    parser.add_argument("--shift", nargs=2, type=int, default=(0, 0), metavar=("X", "Y"))
    parser.add_argument("--only", choices=("ingame", "options"))
    args = parser.parse_args()
    if not args.folder or not os.path.isdir(args.folder):
        sys.exit("Give the game's Screenshots folder as argument (or in ADF_SCREENSHOTS).")
    wanted = {"ingame": ("01-world", "02-frame"), "options": ("03-options",)}
    names = wanted[args.only] if args.only else wanted["ingame"] + wanted["options"]
    shots = collect(args.folder, names)
    if args.only != "options":
        ingame(shots["01-world"], shots["02-frame"], args.shift)
    if args.only != "ingame":
        options(shots["03-options"])


if __name__ == "__main__":
    main()
