# OmenOS

Distro Linux berbasis **Arch Linux** (remaster `archiso`) yang dikonfigurasi untuk
**HP OMEN 15-dc00036tx** (seri 15-dc0000, 2018): driver NVIDIA Pascal, kontrol fan,
dan RGB keyboard 4 zona sudah disiapkan.

Bukan from-scratch: membangun distro dari nol (LFS) butuh berminggu-minggu dan hasilnya
tidak lebih baik untuk kebutuhan ini. Yang menentukan kualitas di sini adalah
**pemilihan paket, parameter kernel, dan daemon fan/RGB** — semuanya ada di repo ini.

Detail model dan keputusan teknis: **[docs/MODEL-15-dc00036tx.md](docs/MODEL-15-dc00036tx.md)**.
Status terakhir, link ISO, dan cara melanjutkan pekerjaan di mesin lain:
**[HANDOFF.md](HANDOFF.md)**.

Unit acuan sudah diperiksa langsung (2026-10-29): SKU `4NT40PA#AR6`, board
**84DA**, i7-8750H, **GTX 1050 Ti 4 GB**, 16 GB single-channel, NVMe 128 GB +
HDD 1 TB, Wi-Fi **Intel AC 9560**, audio **ALC295**, panel 1080p 60 Hz. Profil
ISO, `omen-install`, dan `omen-probe` disesuaikan dengan konfigurasi itu.

---

## Unduh ISO

**Rilis permanen (disarankan, tanpa login):**
<https://github.com/bottjar/omenos/releases/latest>

Setiap build menghasilkan satu rilis `build-YYYYMMDD-HHMMSS` berisi:

| Asset | Keterangan |
|---|---|
| `omenos-*.iso.part-00`, `.part-01`, … | ISO dipecah <2 GB per file (batas aset GitHub) |
| `omenos-*.iso.sha256` | checksum ISO utuh |

Rilis juga menyimpan SHA256 + commit sumber di deskripsinya. Build terbaru juga
diunggah ke **gofile.io** sebagai unduhan satu file; link-nya hanya ada di
ringkasan run Actions untuk build tersebut (mudah kedaluwarsa, jadi rilis GitHub
yang jadi acuan).

### Menyiapkan USB

```bash
# 1. gabungkan bagian-bagian ISO (Linux/macOS/Git Bash)
cat omenos-*.iso.part-* > omenos.iso

# 2. verifikasi — hasilnya harus sama dengan SHA256 di deskripsi rilis
sha256sum omenos.iso

# 3. tulis ke USB (Linux) — /dev/sdX HARUS disk USB, bukan partisi
sudo dd if=omenos.iso of=/dev/sdX bs=4M oflag=sync status=progress
```

Di Windows: gabungkan dengan `copy /b omenos.iso.part-00+omenos.iso.part-01 omenos.iso`
(atau PowerShell `Get-Content -AsByteStream`), lalu tulis dengan **Rufus mode DD**
(bukan ISO mode) atau balenaEtcher. ISO hibrida: bisa boot UEFI maupun BIOS.

> USB 8 GB tidak cukup — ISO ±3,8 GB, pakai USB ≥8 GB (unit ini memakai
> SanDisk Ultra 29 GB).

---

## Isi

| Komponen | Implementasi |
|---|---|
| Basis | Arch Linux rolling, kernel `linux` + `linux-lts` (cadangan) |
| Desktop | KDE Plasma + SDDM (Wayland) |
| NVIDIA | Pascal/15-dc → `nvidia-580xx-dkms` dari AUR (otomatis); Turing+ → `nvidia-open-dkms` |
| Fan | `omen-control daemon-fan` — backend `pwm-boost` (auto/max), `pwm-manual`, atau `platform-profile` |
| RGB | `omen-control daemon-rgb` — 4 zona, LED kernel / TUXOV / pelrun / omen-rgb-keyboard |
| Hybrid GPU | `prime-run` sendiri (tanpa paket `nvidia-prime`) |
| Boot | systemd-boot, UEFI + GPT, dua entri kernel; Secure Boot harus **off** |

Fan dan RGB **tidak** mengandalkan satu driver tertentu. `omen-control` mendeteksi
backend yang ada:

1. `hp-wmi` bawaan kernel — `platform_profile` + monitor RPM; pada 15-dc hanya
   auto/max lewat `pwm1_enable` (atau `pwm1`) → kurva on/off dengan histeresis
2. TUXOV `hp-wmi-fan-and-backlight-control` — PWM manual (0-255) + 4 zona LED
3. pelrun `hp-omen-linux-module` — 4 zona via `rgb_zones/`
4. `omen-rgb-keyboard` — RGB + animasi + brightness
5. `hp::kbd_backlight*` multicolor dari kernel — RGB statis

Kalau tidak ada satu pun, daemon berhenti dengan pesan jelas (exit 0, bukan
restart-loop), bukan gagal diam-diam.

---

## Build

### Di cloud (GitHub Actions) — tanpa Docker lokal

Mesin ini tidak bisa membangun ISO (VT-x nonaktif, tanpa Docker), jadi build
dijalankan di runner GitHub: `ubuntu-latest` + container `archlinux:latest`
(`--privileged`), lalu ISO diunggah ke **gofile.io** dan link-nya muncul di
ringkasan run. Tidak perlu secret apa pun.

1. Buat repo **kosong** (tanpa README) di GitHub, mis. `omenos`, dan biarkan
   **public** (menit Actions gratis; link rilis bisa diunduh tanpa login).
2. Dari folder `omen-os/`:

   ```bash
   git init -b main
   git add .
   git commit -m "OmenOS: profil archiso untuk OMEN 15-dc00036tx"
   git remote add origin https://github.com/<user>/omenos.git
   git push -u origin main
   ```

3. Push ke `main` langsung memicu build. Atau: tab **Actions** → **Build ISO**
   → **Run workflow**. Durasi ± 20–45 menit.
4. Buka run yang selesai dan lihat **Summary**: ada nama file, ukuran, SHA256,
   dan **link download**.

Alur workflow (`.github/workflows/build-iso.yml`):

| Langkah | Isi |
|---|---|
| Cek skrip | `bash -n`, `shellcheck`, `tests/selftest.py` — gagal cepat sebelum build panjang |
| Kosongkan disk | hapus toolchain bawaan runner (hanya ~14 GB bebas) |
| Build | `docker run --privileged archlinux:latest` → `pacman -S archiso` → `build.sh` |
| Upload | gofile.io; kalau gagal → GitHub Release (dipecah <2 GiB per file); artifact sebagai cadangan |

Kalau link gofile gagal, ringkasan menampilkan link Release; unduh semua
`*.part-*` lalu `cat *.part-* > omenos-*.iso` sebelum menulis USB.

### Dari Windows

Butuh **Docker Desktop** (mode Linux container) dan ~10 GB disk.

```powershell
cd omen-os
.\build.ps1
```

Hasil: `out\omenos-YYYY.MM.DD-x86_64.iso` (± 2–3 GB, 15–40 menit). Driver NVIDIA
**tidak** dikompilasi saat build ISO; itu dilakukan `omen-setup` di boot pertama.

### Di Arch / container Arch

```bash
sudo pacman -S archiso
sudo ./build.sh
```

`build.sh` menyalin profil `releng` resmi lalu menimpanya dengan folder `overlay/`,
sehingga konfigurasi boot selalu ikut versi `archiso` yang terpasang.

### Uji tanpa USB

```powershell
winget install SoftwareFreedomConservancy.QEMU
.\scripts\test-qemu.ps1 -Ram 8192
```

Di QEMU tidak ada hardware Omen, jadi `omen-control status` akan melaporkan backend
`none` — itu normal.

---

## Instalasi

1. Tulis ISO ke USB: **Rufus mode DD** atau balenaEtcher.
2. Boot USB (F9 boot menu di Omen), pilih **UEFI**, matikan Secure Boot di BIOS.
3. Live session login otomatis ke user **omen** (password `omen`); root di tty2 (`omen`).
4. Pasang:

```bash
lsblk                        # pastikan nama disk benar
omen-install /dev/nvme0n1    # MENGHAPUS SELURUH DISK, minta konfirmasi "ERASE"
```

Installer mempartisi GPT (1 GiB ESP + ext4), memasang paket, menyalin
`pacman.conf` + mirrorlist, mengaktifkan **multilib**, dan membuat entri boot
untuk `linux` dan `linux-lts`.

5. Reboot. Boot pertama menjalankan `omen-setup` otomatis (butuh internet). Kalau
   internet belum siap (Wi-Fi baru dikonfigurasi setelah login), timer
   `omen-setup-retry.timer` mencoba lagi setiap 15 menit sampai berhasil.
   Pantau progres (build AUR bisa 5–15 menit):

   ```bash
   journalctl -u omen-setup-once -f
   systemctl list-timers omen-setup-retry.timer
   ```

   Yang dilakukan:
   - `pacman -Syu` sekali agar tidak partial upgrade
   - deteksi GPU: Pascal → build `nvidia-580xx-*` dari AUR (5–15 menit), Turing+ → `nvidia-open-dkms`
   - aktifkan driver RGB (kernel → TUXOV → pelrun)
   - tulis `nvidia-drm.modeset=1`, `mem_sleep_default=deep` (board 84DA/84DB)
   - rebuild initramfs untuk kedua kernel, aktifkan service, simpan `omen-probe`

Kalau grafis bermasalah, pilih entri **OmenOS (linux-lts)** di boot menu.

---

## Pemakaian

```bash
omen-control status            # model, GPU, suhu, RPM, backend fan/RGB
omen-control fan auto          # kembalikan ke EC
omen-control fan max           # fan penuh
omen-control fan 40            # 15-dc: dipetakan ke auto (<70%) / max (>=70%)
omen-control fan boost on      # eksplisit untuk backend pwm-boost
omen-control fan performance   # profil termal (bila tersedia)
omen-control rgb set FF0000    # semua zona merah
omen-control rgb set 00FF00 2  # zona 2 hijau (wasd,left,center,right)
omen-control rgb brightness 60
omen-control rgb off

prime-run glxinfo | grep "OpenGL renderer"   # jalankan app di dGPU NVIDIA
```

Konfigurasi: `/etc/omen/fan.conf` dan `/etc/omen/rgb.conf` (TOML), lalu
`sudo systemctl restart omen-fan omen-rgb`.

Nilai default untuk 15-dc: boost ON 76 °C, OFF 68 °C, safety 93 °C,
release 87 °C.

---

## Struktur repo

```
omen-os/
├─ build.sh / build.ps1        # pembangun ISO
├─ .github/workflows/build-iso.yml  # build di cloud + link gofile
├─ scripts/test-qemu.ps1
├─ overlay/                    # ditimpa ke profil releng
│  ├─ profiledef.sh            # nama ISO, bootmode, permission
│  ├─ packages.x86_64          # daftar paket (tanpa driver NVIDIA)
│  └─ airootfs/
│     ├─ root/omen-customize.sh     # dijalankan saat build
│     ├─ etc/omen/{fan,rgb}.conf
│     ├─ etc/modprobe.d/nvidia.conf
│     ├─ etc/systemd/zram-generator.conf
│     ├─ etc/systemd/system/omen-{fan,rgb}.service
│     └─ usr/local/bin/
│        ├─ omen-control        # CLI + daemon fan/RGB
│        ├─ omen-setup          # konfigurasi boot pertama
│        ├─ omen-install        # installer disk
│        ├─ omen-aur            # build paket AUR tanpa helper
│        ├─ omen-probe          # dump diagnostik
│        └─ prime-run           # offload ke dGPU
├─ tests/selftest.py           # uji tanpa hardware
└─ docs/
   ├─ HARDWARE.md              # matriks model, quirk ACPI, risiko
   └─ MODEL-15-dc00036tx.md    # detail model ini
```

---

## Troubleshooting

**Layar hitam setelah boot NVIDIA**
Boot ke **linux-lts**, lalu:

```bash
lspci -nn | grep -i nvidia        # pastikan GPU Pascal (10de:1bxx/1cxx)
pacman -Q | grep -i nvidia       # harus 580xx; kalau ada nvidia-utils 590, hapus
sudo omen-setup --gpu=legacy
```

Jangan memasang `nvidia`, `nvidia-open-dkms`, `nvidia-utils`, atau `nvidia-prime`:
branch 590 tidak mendukung Pascal.

**Fan tidak mau diatur (`backend: none`)**
Model tertentu (board `8BCA`, Omen 16-xf0xxx) punya tabel ACPI rusak: simbol
`\_SB.PEP.DETY` hilang. Cek `sudo dmesg | grep -i 'AE_NOT_FOUND\|PEP'`. Tidak ada
software yang bisa memperbaikinya — butuh update BIOS dari HP.
Untuk 15-dc, backend normal adalah `pwm-boost`; `fan 40` memang tidak berarti 40%.

**RGB tidak muncul**
Cek backend:

```bash
ls /sys/class/leds/ | grep -i kbd
ls /sys/devices/platform/hp-wmi/rgb_zones 2>/dev/null
sudo omen-probe | sed -n '/LED CLASS/,/ACPI/p'
```

Kalau kosong, jalankan `sudo omen-setup --rgb-driver=auto`. Driver komunitas
menggantikan `hp-wmi`; kalau bentrok, reboot setelah pemasangan.

**Suspend lalu aplikasi crash**
Pastikan `mem_sleep_default=deep` ada di entri boot dan
`NVreg_PreserveVideoMemoryAllocations=1` aktif. Service `nvidia-suspend`,
`nvidia-resume`, `nvidia-hibernate` diaktifkan `omen-setup`.

**AUR gagal dibangun**
`omen-aur` memakai `aurbuilder` dan hanya mengizinkan `sudo pacman`. Kalau gagal,
cek koneksi dan `dkms status`. Build ulang aman (idempoten).

**Secure Boot**
ISO dan modul DKMS tidak bertanda tangan. Matikan Secure Boot, atau daftarkan
kunci sendiri dengan `sbctl` lalu tanda tangani `nvidia*.ko` dan modul RGB.

---

## Pengujian

```bash
python3 tests/selftest.py
```

Selftest membuat sysfs palsu untuk 9 skenario: PWM manual (`pwm1_max`), auto/max
15-dc (`pwm1` + `pwm1_enable`), kernel lama (`pwm1_enable` saja), TUXOV (LED 4
zona + PWM manual tanpa `pwm1_max`), LED tunggal kernel, tanpa backend fan,
pelrun (`rgb_zones` warna saja), hanya `platform_profile`, dan fungsi murni
`decide_fan()`/`interpolate()`/`hotspot()`.

Hasil yang diverifikasi:

- PWM 60% → `pwm1=153`, `pwm1_enable=1`
- `fan max` → mode MAX; `fan auto` → `pwm1_enable=2`
- Profil termal tidak ditimpa saat backend PWM aktif (PPD/pilihan pengguna tetap)
- Backend `platform-profile`: `max` → performance, `auto` → balanced, `quiet` → low-power
- 15-dc: 80% → `pwm1_enable=0` (boost), 30% → `pwm1_enable=2` (auto)
- Kernel lama tanpa `pwm1`: `fan max`/`auto` tetap bekerja lewat `pwm1_enable`
- TUXOV: 50% → `pwm1=128`, probe manual berhasil
- LED: urutan zona `wasd,left,center,right`; `multi_intensity="R G B"`;
  brightness 0 dinaikkan otomatis
- pelrun: warna `rgb_zones` berfungsi; `brightness`/`animation` ditolak dengan pesan
- Histeresis boost: ON 76 °C, OFF 68 °C; safety 93 °C, release 87 °C
- Tanpa backend → exit code ≠ 0 dengan pesan jelas

Skrip `.sh` sudah lolos `bash -n` dan `shellcheck -S warning`. Yang **belum**
teruji: boot ISO di hardware Omen sungguhan dan pembangunan ISO itu sendiri.

---

## Yang belum ada (jujur)

- Tidak ada GUI fan/RGB (CLI + TOML).
- Undervolt CPU tidak disertakan (`intel-undervolt` bisa ditambah, tapi rawan).
- Dukungan fan manual TUXOV pada 15-dc belum diketahui; daemon menguji saat start.
- ISO belum diuji di unit 15-dc00036tx fisik. Profil sekarang sudah dicocokkan
  dengan hardware unit tersebut (board 84DA, GTX 1050 Ti, AC 9560, ALC295,
  NVMe+HDD), tapi boot pertama tetap harus dilakukan. Jalankan
  `sudo omen-probe > ~/omen-probe.txt` di live session dan kirim hasilnya;
  kurva fan, zona RGB, dan quirk disesuaikan dari data itu.
