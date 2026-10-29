#!/usr/bin/env python3
"""selftest.py — uji logika omen-control tanpa hardware Omen.

Membuat sysfs palsu untuk beberapa varian driver, menjalankan CLI sebagai
subprocess, lalu memeriksa hasil tulisannya. Jalan di Linux maupun Windows:

    python3 tests/selftest.py

Yang diuji:
  1. pwm1 + pwm1_max          -> PWM manual penuh
  2. pwm1 + pwm1_enable       -> auto/max (Omen 15-dc0000 board 84DA/84DB)
  2b. pwm1_enable read-only  -> perintah gagal jujur, bukan "sukses" palsu
  3. pwm1_enable saja         -> auto/max pada kernel lama (tanpa pwm1)
  4. TUXOV (LED ber-zona)     -> PWM manual lewat pwm1_enable=1
  5. hp::kbd_backlight tunggal-> RGB satu zona (kernel multicolor)
  6. tanpa backend fan        -> pesan jelas + exit code != 0
  6b. board EC-only 84DA      -> ec_sys 0x95: cool/auto, performance ditolak
  7. pelrun rgb_zones         -> warna saja, brightness/animasi ditolak
  8. hanya platform_profile   -> profil termal sebagai kontrol fan
  9. decide_fan()             -> histeresis & prioritas safety (fungsi murni)
"""
from __future__ import annotations

import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
CTL = REPO / "overlay/airootfs/usr/local/bin/omen-control"
CONF_SRC = REPO / "overlay/airootfs/etc/omen"

failures: list[str] = []


def check(name, got, want):
    ok = got == want
    print(f"  [{'OK ' if ok else 'GAGAL'}] {name}: {got!r}" + ("" if ok else f" (harap {want!r})"))
    if not ok:
        failures.append(name)


def check_true(name, cond, detail=""):
    check(name, bool(cond), True)
    if not cond and detail:
        print(f"         detail: {detail}")


def load_module():
    # omen-control tidak berekstensi .py, jadi SourceFileLoader dipakai langsung.
    from importlib.machinery import SourceFileLoader
    loader = SourceFileLoader("omen_control", str(CTL))
    spec = importlib.util.spec_from_loader("omen_control", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def make_led(root: Path, name: str, *, multicolor=True):
    d = root / "sys/class/leds" / name
    d.mkdir(parents=True)
    (d / "brightness").write_text("255\n")
    (d / "max_brightness").write_text("255\n")
    if multicolor:
        (d / "multi_intensity").write_text("255 255 255\n")
    return d


def make_tree(root: Path, variant: str) -> Path:
    (root / "etc/omen").mkdir(parents=True)
    for f in ("fan.conf", "rgb.conf"):
        shutil.copy(CONF_SRC / f, root / "etc/omen" / f)
    fan = root / "etc/omen/fan.conf"
    fan.write_text(re.sub(r"^interval_s\s*=\s*5", "interval_s = 1",
                          fan.read_text(), flags=re.M))

    hw = root / "sys/class/hwmon/hwmon3"
    hw.mkdir(parents=True)
    (hw / "name").write_text("hp-wmi\n")
    if variant != "profile-only":
        (hw / "pwm1_enable").write_text("2\n")
        (hw / "fan1_input").write_text("2400\n")
        # Kernel lama hanya membuat pwm1_enable; kernel baru membuat keduanya.
        if variant != "enable-only":
            (hw / "pwm1").write_text("2\n")
        if variant == "pwm-manual":
            (hw / "pwm1_max").write_text("255\n")
        if variant == "tuxov":
            # pwm2_input hanya ada kalau tabel fan mendukung PWM manual.
            (hw / "pwm2_input").write_text("0\n")

    cpu = root / "sys/class/hwmon/hwmon4"
    cpu.mkdir()
    (cpu / "name").write_text("coretemp\n")
    (cpu / "temp1_input").write_text("68000\n")

    pp = root / "sys/firmware/acpi/platform_profile"
    pp.parent.mkdir(parents=True)
    pp.write_text("balanced\n")
    (pp.parent / "platform_profile_choices").write_text("low-power balanced performance\n")

    if variant == "tuxov":
        # Driver komunitas: zona LED bernama, tanpa rgb_zones.
        for suffix in ("left", "center", "right", "wasd"):
            # Nama asli di Linux memakai "hp::"; ":" ilegal di NTFS, jadi tes
            # memakai "hp-" — find_kbd_leds() hanya peduli substring "kbd".
            make_led(root, f"hp-kbd_zoned_backlight-{suffix}")
    elif variant == "led-single":
        make_led(root, "hp-kbd_backlight")
    elif variant != "no-rgb":
        zones = root / "sys/devices/platform/hp-wmi/rgb_zones"
        zones.mkdir(parents=True)
        for i in range(4):
            (zones / f"zone0{i}").write_text("000000\n")
        # omen-rgb-keyboard punya brightness/animation; pelrun tidak.
        if variant != "pelrun":
            (zones / "brightness").write_text("100\n")
            (zones / "animation").write_text("static\n")
            (zones / "animation_speed").write_text("5\n")
    return root


def run(root: Path, *args):
    env = dict(os.environ, OMEN_SYSROOT=str(root))
    return subprocess.run([sys.executable, str(CTL), *args],
                          capture_output=True, text=True, env=env, timeout=30)


def test_cli(tmp: Path):
    print("varian 1: pwm1 + pwm1_max (PWM manual)")
    r = make_tree(tmp / "a", "pwm-manual")
    check("status backend", "pwm-manual" in run(r, "status").stdout, True)
    run(r, "fan", "60")
    check("pwm1 @60%", (r / "sys/class/hwmon/hwmon3/pwm1").read_text().strip(), "153")
    check("pwm1_enable @60%", (r / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "1")
    run(r, "fan", "max")
    check("pwm1_enable @max", (r / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "0")
    # Saat PWM tersedia, daemon tidak boleh menimpa profil termal pengguna/PPD.
    check("profil tidak disentuh saat PWM", (r / "sys/firmware/acpi/platform_profile").read_text().strip(), "balanced")
    run(r, "fan", "auto")
    check("pwm1_enable @auto", (r / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "2")

    zones = r / "sys/devices/platform/hp-wmi/rgb_zones"
    run(r, "rgb", "set", "FF0000")
    check("rgb semua zona", [p.read_text().strip() for p in sorted(zones.glob("zone*"))],
          ["FF0000"] * 4)
    run(r, "rgb", "set", "00FF00", "2")
    check("rgb zona 2", (zones / "zone02").read_text().strip(), "00FF00")
    check("rgb zona lain utuh", (zones / "zone01").read_text().strip(), "FF0000")
    p = run(r, "rgb", "set", "00FF00", "9")
    check("rgb zona di luar rentang ditolak", p.returncode != 0, True)
    p = run(r, "rgb", "off")
    check("rgb off tidak crash", p.returncode, 0)
    check("rgb brightness off", (zones / "brightness").read_text().strip(), "0")

    print("varian 2: pwm1 + pwm1_enable tanpa pwm1_max (boost/auto saja)")
    r2 = make_tree(tmp / "b", "pwm-boost")
    check("status backend", "pwm-boost" in run(r2, "status").stdout, True)
    run(r2, "fan", "80")
    check("pwm1_enable @80% = boost", (r2 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "0")
    run(r2, "fan", "30")
    check("pwm1_enable @30% = auto", (r2 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "2")
    run(r2, "fan", "boost", "on")
    check("fan boost on", (r2 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "0")
    run(r2, "fan", "boost", "off")
    check("fan boost off", (r2 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "2")

    print("varian 2b: driver menolak tulis (pwm1_enable tidak bisa ditulis)")
    r10 = make_tree(tmp / "b2", "pwm-boost")
    en = r10 / "sys/class/hwmon/hwmon3/pwm1_enable"
    en.unlink()
    en.mkdir()          # direktori: write_text gagal untuk user mana pun
    p = run(r10, "fan", "max")
    check("max jujur gagal", p.returncode != 0, True)
    check("pesan node max", "menolak mode max" in (p.stdout + p.stderr), True)
    p = run(r10, "fan", "auto")
    check("auto jujur gagal", p.returncode != 0, True)
    check("pesan node auto", "menolak nilai 2" in (p.stdout + p.stderr), True)

    print("varian 3: pwm1_enable saja (kernel 6.6, tanpa pwm1)")
    r8 = make_tree(tmp / "c2", "enable-only")
    check("status backend", "pwm-boost" in run(r8, "status").stdout, True)
    run(r8, "fan", "max")
    check("enable-only max", (r8 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "0")
    run(r8, "fan", "auto")
    check("enable-only auto", (r8 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "2")
    p = run(r8, "fan", "55")
    check("enable-only persen dipetakan, bukan PWM", (r8 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "2")
    check("enable-only persen tetap sukses", p.returncode, 0)

    print("varian 4: TUXOV, 4 zona LED + PWM manual tanpa pwm1_max")
    r3 = make_tree(tmp / "c", "tuxov")
    check("status backend", "pwm-manual" in run(r3, "status").stdout, True)
    run(r3, "fan", "50")
    check("pwm1 @50% (TUXOV)", (r3 / "sys/class/hwmon/hwmon3/pwm1").read_text().strip(), "128")
    check("pwm1_enable manual", (r3 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "1")
    run(r3, "fan", "max")
    check("pwm1_enable @max (mode 0)", (r3 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "0")
    run(r3, "fan", "auto")
    check("pwm1_enable @auto", (r3 / "sys/class/hwmon/hwmon3/pwm1_enable").read_text().strip(), "2")

    leds = r3 / "sys/class/leds"
    run(r3, "rgb", "set", "112233")
    check("LED wasd", (leds / "hp-kbd_zoned_backlight-wasd/multi_intensity").read_text().strip(), "17 34 51")
    check("LED left", (leds / "hp-kbd_zoned_backlight-left/multi_intensity").read_text().strip(), "17 34 51")
    run(r3, "rgb", "set", "00FF00", "2")   # urutan: wasd,left,center,right -> center
    check("LED zona 2 = center", (leds / "hp-kbd_zoned_backlight-center/multi_intensity").read_text().strip(), "0 255 0")
    check("LED zona 0 tetap", (leds / "hp-kbd_zoned_backlight-wasd/multi_intensity").read_text().strip(), "17 34 51")
    run(r3, "rgb", "brightness", "40")
    check("LED brightness 40%", (leds / "hp-kbd_zoned_backlight-wasd/brightness").read_text().strip(), "102")
    p = run(r3, "rgb", "animation", "rainbow")
    check("animasi ditolak pada backend LED", p.returncode != 0, True)

    print("varian 5: hp::kbd_backlight tunggal (kernel multicolor)")
    r4 = make_tree(tmp / "d", "led-single")
    run(r4, "rgb", "set", "FF0000")
    led = r4 / "sys/class/leds/hp-kbd_backlight"
    check("LED tunggal merah", (led / "multi_intensity").read_text().strip(), "255 0 0")
    (led / "brightness").write_text("0\n")
    run(r4, "rgb", "set", "0000FF")
    check("brightness 0 dinaikkan otomatis", (led / "brightness").read_text().strip(), "255")

    print("varian 6: tanpa backend fan")
    r5 = make_tree(tmp / "e", "no-rgb")
    for f in (r5 / "sys/class/hwmon").glob("*"):
        shutil.rmtree(f)
    (r5 / "sys/firmware/acpi/platform_profile").unlink()
    (r5 / "sys/firmware/acpi/platform_profile_choices").unlink()
    check("status backend", "none" in run(r5, "status").stdout, True)
    p = run(r5, "fan", "60")
    check("exit code bukan nol", p.returncode != 0, True)
    check("pesan jelas", "tidak ada backend fan" in (p.stdout + p.stderr), True)

    print("varian 6b: board EC-only 84DA (tanpa PWM, tanpa platform_profile)")
    r9 = make_tree(tmp / "h", "no-rgb")
    for f in (r9 / "sys/class/hwmon").glob("*"):
        shutil.rmtree(f)
    (r9 / "sys/firmware/acpi/platform_profile").unlink()
    (r9 / "sys/firmware/acpi/platform_profile_choices").unlink()
    (r9 / "sys/class/dmi/id").mkdir(parents=True)
    (r9 / "sys/class/dmi/id/board_name").write_text("84DA\n")
    eco = r9 / "sys/kernel/debug/ec/ec0/io"
    eco.parent.mkdir(parents=True)
    eco.write_bytes(bytes(256))          # 0x95 = 0x00 (balanced)
    out = run(r9, "status").stdout
    check("status EC terbaca", "ec termal    : balanced (0x95=0x00)" in out, True)
    check("status backend none", "fan backend  : none" in out, True)
    p = run(r9, "fan", "cool")
    check("fan cool exit", p.returncode, 0)
    check("EC 0x95 @cool", eco.read_bytes()[149], 2)
    p = run(r9, "fan", "max")
    check("fan max exit", p.returncode, 0)
    check("EC 0x95 @max tetap cool", eco.read_bytes()[149], 2)
    p = run(r9, "fan", "auto")
    check("fan auto exit", p.returncode, 0)
    check("EC 0x95 @auto", eco.read_bytes()[149], 0)
    p = run(r9, "fan", "performance")
    check("performance ditolak", p.returncode != 0, True)
    check("alasan firmware", "IsBiosPerformanceControlSupport=False" in (p.stdout + p.stderr), True)
    p = run(r9, "fan", "55")
    check("persen ditolak di EC-only", p.returncode != 0, True)

    print("varian 7: pelrun (rgb_zones tanpa brightness/animation)")
    r7 = make_tree(tmp / "g", "pelrun")
    zones7 = r7 / "sys/devices/platform/hp-wmi/rgb_zones"
    run(r7, "rgb", "set", "AABBCC")
    check("pelrun warna", (zones7 / "zone00").read_text().strip(), "AABBCC")
    p = run(r7, "rgb", "brightness", "50")
    check("pelrun brightness ditolak dengan pesan", p.returncode != 0, True)
    p = run(r7, "rgb", "animation", "rainbow")
    check("pelrun animasi ditolak", p.returncode != 0, True)

    print("varian 8: hanya platform_profile (tanpa PWM)")
    r6 = make_tree(tmp / "f", "profile-only")
    check("status backend", "platform-profile" in run(r6, "status").stdout, True)
    ppf = r6 / "sys/firmware/acpi/platform_profile"
    run(r6, "fan", "max")
    check("profile-only max -> performance", ppf.read_text().strip(), "performance")
    run(r6, "fan", "auto")
    check("profile-only auto -> balanced", ppf.read_text().strip(), "balanced")
    run(r6, "fan", "quiet")
    check("profile-only quiet -> low-power", ppf.read_text().strip(), "low-power")
    run(r6, "fan", "performance")
    check("profile-only performance", ppf.read_text().strip(), "performance")
    p = run(r6, "fan", "85")
    check("persen ditolak tanpa PWM", p.returncode != 0, True)


def test_policy(tmp: Path):
    print("varian 9: decide_fan() / interpolate() (fungsi murni)")
    mod = load_module()
    with open(CONF_SRC / "fan.conf", "rb") as fh:
        cfg = tomllib.load(fh)

    check("interpolate 50C", round(mod.interpolate([[45, 22], [55, 32]], 50), 2), 27.0)
    check("interpolate batas bawah", mod.interpolate([[45, 22], [55, 32]], 10), 22)
    check("interpolate batas atas", mod.interpolate([[45, 22], [55, 32]], 99), 32)

    st = {"mode": "auto", "target": None}
    check("pwm-boost 70C -> diam", mod.decide_fan(70, cfg, "pwm-boost", st), None)
    check("pwm-boost 76C -> boost", mod.decide_fan(76, cfg, "pwm-boost", st), ("boost", None))
    st = {"mode": "boost"}
    check("boost 72C -> tetap", mod.decide_fan(72, cfg, "pwm-boost", st), None)
    check("boost 68C -> auto", mod.decide_fan(68, cfg, "pwm-boost", st), ("auto", None))

    st = {"mode": "auto", "target": None}
    check("safety 93C -> max", mod.decide_fan(93, cfg, "pwm-boost", st), ("max", None))
    st = {"mode": "max", "target": None}
    check("setelah safety 90C -> tetap max", mod.decide_fan(90, cfg, "pwm-boost", st), None)
    check("setelah safety 86C -> auto", mod.decide_fan(86, cfg, "pwm-boost", st), ("auto", None))

    st = {"mode": "auto", "target": None}
    check("profile 85C -> performance",
          mod.decide_fan(85, cfg, "platform-profile", st), ("profile", "performance"))
    st = {"mode": "auto", "target": None}
    check("profile 50C -> quiet",
          mod.decide_fan(50, cfg, "platform-profile", st), ("profile", "quiet"))
    st = {"mode": "performance"}
    check("performance 80C -> tetap", mod.decide_fan(80, cfg, "platform-profile", st), None)
    check("performance 76C -> balanced",
          mod.decide_fan(76, cfg, "platform-profile", st), ("profile", "balanced"))

    st = {"mode": "auto", "target": None}
    act = mod.decide_fan(50, cfg, "pwm-manual", st)
    check("pwm-manual 50C -> pct", act[0] if act else None, "pct")
    check("pwm-manual 50C nilai", round(act[1]) if act else None, 27)
    st = {"mode": "auto", "target": act[1]}
    check("pwm-manual histeresis", mod.decide_fan(51, cfg, "pwm-manual", st), None)

    temps = {"coretemp:Package id 0": 71.0, "nvme:Composite": 55.0, "nvidia:gpu0": 64.0}
    check("hotspot pilih CPU", mod.hotspot(temps), 71.0)


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="omen-selftest-"))
    try:
        test_cli(tmp)
        test_policy(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failures:
        print(f"GAGAL: {len(failures)} pemeriksaan -> {failures}")
        return 1
    print("Semua pemeriksaan lolos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
