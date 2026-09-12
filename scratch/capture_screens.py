import os
import time
import struct
import subprocess
from PIL import Image

def capture_window(out_png_path, env_mode=None):
    env = os.environ.copy()
    if env_mode:
        env["SPROUT_START_MODE"] = env_mode

    p = subprocess.Popen(["./zig-out/bin/sprout"], env=env)
    time.sleep(1.8)

    wid = None
    try:
        out = subprocess.check_output(["xwininfo", "-root", "-tree"]).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            if "0x" in line and ("Beast" in line or "sprout" in line.lower()):
                wid = line.strip().split()[0]
                break
    except Exception as e:
        print("xwininfo error:", e)

    print(f"Captured window ID for mode={env_mode}: {wid}")
    xwd_path = f"/tmp/sprout_{env_mode or 'dungeon'}.xwd"

    if wid:
        subprocess.run(["xwd", "-id", wid, "-silent", "-out", xwd_path])
    else:
        subprocess.run(["xwd", "-root", "-silent", "-out", xwd_path])

    p.terminate()
    try:
        p.wait(timeout=2.0)
    except subprocess.TimeoutExpired:
        p.kill()

    # Convert XWD to PNG
    with open(xwd_path, "rb") as f:
        hdr = f.read(100)
        vals = struct.unpack(">25I", hdr)
        hdr_size = vals[0]
        w = vals[4]
        h = vals[5]
        bpp = vals[11]
        bpl = vals[12]
        ncolors = vals[19]
        f.seek(hdr_size + ncolors * 12)
        raw_data = f.read()

        if bpp == 32:
            img = Image.frombytes("RGBA", (w, h), raw_data, "raw", "BGRA", bpl, 1)
            img.convert("RGB").save(out_png_path)
        elif bpp == 24:
            img = Image.frombytes("RGB", (w, h), raw_data, "raw", "BGR", bpl, 1)
            img.save(out_png_path)
        print(f"Successfully saved {out_png_path} ({w}x{h}, bpp={bpp})")

artifact_dir = "/home/mypc/.gemini/antigravity-ide/brain/91dd98fe-7793-45aa-b28c-b74dd78e1b8d"
capture_window(f"{artifact_dir}/party_screen.png", "party")
capture_window(f"{artifact_dir}/battle_screen.png", "battle")
capture_window(f"{artifact_dir}/dungeon_screen.png", None)
