# HANDOFF — status & cara melanjutkan

Dokumen ini untuk melanjutkan pekerjaan OmenOS di mesin lain (mis. di laptop Omen
setelah OmenOS terpasang) atau setelah percakapan lama tidak tersedia.

## 1. Tujuan

Distro Linux berbasis **Arch Linux** (remaster `archiso`) untuk **HP OMEN
15-dc00036tx** (seri 15-dc0000, 2018, Coffee Lake i7-8750H + GTX 1050 Ti Pascal).
Yang wajib jalan: driver NVIDIA dan termal/power yang benar. Kontrol fan dan RGB
**tidak** dijanjikan: hasil bongkar aplikasi OMEN (lihat
[docs/OMEN-APP-RE.md](docs/OMEN-APP-RE.md)) menunjukkan firmware unit ini
melaporkan `IsSwFanControlSupport=False` dan keyboard bukan 4 zona.

## 2. Status per 2026-10-29

| Item | Nilai |
|---|---|
| Hardware | **terverifikasi** 2026-10-29: board 84DA, i7-8750H, GTX 1050 Ti 4 GB, 16 GB single-channel, NVMe 128 GB + HDD 1 TB, Intel AC 9560, ALC295 |
| ISO | `omenos-2026.10.29-x86_64.iso`, **3.800.973.312 byte** (3,8 GB) |
| SHA256 | `0acad2621025b30c02f0c6ae2efa5b410ad044251a0ba9b19665b1ca96e47d72` |
| Link (permanen) | https://github.com/bottjar/omenos/releases/tag/build-20261029-052649 (2 part + `.sha256`) |
| Link (1 file) | https://gofile.io/d/lxl8rJqQ (publik, bisa kedaluwarsa) |
| Build | GitHub Actions `success`, ±14 menit (05:12→05:28 UTC) |
| Repo | https://github.com/bottjar/omenos |
| Run | https://github.com/bottjar/omenos/actions/runs/40822270085 (commit `d2c3b14`) |
| USB | sudah ditulis 2026-10-29 ke SanDisk Ultra 29 GB (disk 2) mode DD, baca-balik SHA256 identik; berisi build **`4d9994c`** (bukan yang terbaru); **belum** boot-test |

ISO **belum pernah di-boot** di hardware Omen. Semua uji sejauh ini: `bash -n`,
`shellcheck -S warning`, dan `tests/selftest.py` (11 skenario, semua lolos).

Rilis sekarang dibuat sebagai **draft**, semua asset diunggah, baru
dipublikasikan (`gh release edit --draft=false`). Build yang dibatalkan saat
upload tidak lagi meninggalkan rilis publik kosong; draft sisa dibersihkan
otomatis di awal run berikutnya.

Build ulang kapan saja: push ke `main`, atau Actions → **Build ISO** → *Run
workflow*. Hasil: link gofile di ringkasan run; cadangan artifact/Release.

## 3. Keputusan teknis yang sudah final

- Basis **archiso releng**, bukan from-scratch. Profil = releng + `overlay/`.
- **NVIDIA**: Pascal butuh `nvidia-580xx-dkms` dari AUR (Arch 590+ & `nvidia-open`
  hanya Turing+). Driver **tidak** ada di ISO; `omen-setup` membangunnya di boot
  pertama (butuh internet, 5–15 menit).
- `prime-run` milik sendiri; paket `nvidia-prime` tidak dipakai.
- **Fan 15-dc**: firmware HP sendiri menyatakan `IsSwFanControlSupport=False`
  (board 84DA, platform Gamora10) → kipas milik EC, tanpa PWM. Kalau kernel
  mengekspos `pwm1_enable` (hwmon `hp`, butuh WMI `0x10`/`0x11`), backend
  `pwm-boost` dipakai dengan histeresis ON 76 °C, OFF 68 °C, safety 93 °C,
  release 87 °C; `pwm1_enable=0` memakai WMI `0x27`, bukan `0x28` yang gagal.
  Kalau tidak ada node sama sekali, daemon keluar dengan pesan jujur +
  `ec_only_note()`, dan tuas manual satu-satunya adalah byte EC `0x95`
  (`sudo omen-control fan cool` lewat `ec_sys write_support=1`). Jalur termal
  normal tetap `thermald` + governor `intel_pstate` + `power-profiles-daemon`.
  `hp-wmi-sensors` **tidak** terdaftar di 84DA (`instance_count=0`).
- **RGB**: SKU `4NT40PA#AR6` hanya punya backlight putih 1 warna (`keyboardType=0`,
  tidak ada perangkat FourZone) → `omen-rgb` berhenti dengan pesan jelas. Backend
  tetap ada untuk model lain: LED kernel `hp::kbd_backlight*` → TUXOV
  `hp::kbd_zoned_backlight-{wasd,left,center,right}` → pelrun `rgb_zones/` →
  `omen-rgb-keyboard`.
- Nama hwmon chip untuk hp-wmi adalah `hp` (sudah masuk `HWMON_NAMES`).
- `hp-wmi` TUXOV dan pelrun sama-sama bernama `hp-wmi` → `omen-setup` menjalankan
  `drop_dkms_hp_wmi()` sebelum memasang pelrun.
- `NVreg_DynamicPowerManagement=0x00` (RTD3 hanya Turing+).
- Live ISO pakai **NetworkManager**; `systemd-networkd`, `systemd-resolved`, `iwd`
  dimatikan; `/etc/resolv.conf` file kosong (bukan symlink).
- Tidak ada paket `lib32-*` di ISO; `omen-setup` mengaktifkan multilib lalu
  memasangnya.
- Daemon keluar dengan kode 0 kalau tidak ada backend (hindari restart loop).

## 4. Struktur repo

```
build.sh / build.ps1        # pembangun ISO (lokal)
.github/workflows/build-iso.yml  # build cloud + upload gofile
overlay/
  profiledef.sh             # nama ISO, bootmode, permission
  packages.x86_64           # daftar paket (tanpa driver NVIDIA)
  airootfs/root/omen-customize.sh
  airootfs/etc/omen/{fan,rgb}.conf
  airootfs/etc/systemd/system/omen-{fan,rgb}.service
  airootfs/usr/local/bin/{omen-control,omen-setup,omen-install,omen-aur,omen-probe,prime-run}
tests/selftest.py           # 11 skenario sysfs palsu
docs/HARDWARE.md            # matriks model & risiko
docs/MODEL-15-dc00036tx.md  # detail model ini
docs/OMEN-APP-RE.md         # hasil bongkar aplikasi OMEN (fan/termal/RGB)
```

## 5. Rencana uji di hardware (belum dilakukan)

1. ~~Tulis ISO ke USB~~ **sudah**: 2026-10-29, SanDisk Ultra 29 GB (disk 2),
   mode DD dari Windows, verifikasi baca-balik SHA256 **identik** dengan ISO.
   USB sekarang berisi 1 partisi 514 MB (EFI) — normal untuk ISO Arch hibrida;
   Windows tidak memberi huruf drive. Tidak perlu Rufus (lihat di bawah).
2. Omen: **F9** → USB **UEFI**; Secure Boot **off**.
3. Live session: autologin user `omen`, password `omen`.
4. Uji cepat:
   ```bash
   sudo omen-probe > ~/omen-probe.txt
   omen-control status
   omen-control rgb set FF0000
   omen-control fan max
   ls /sys/class/leds | grep -i kbd
   ls /sys/devices/platform/hp-wmi/ 2>/dev/null
   ```
5. Install (menghapus seluruh disk):
   ```bash
   lsblk
   omen-install /dev/nvme0n1 --data-disk /dev/sda   # konfirmasi "ERASE" + "FORMAT"
   ```
   Unit ini: sistem ke NVMe 128 GB, HDD 1 TB jadi `/data` (ext4, label
   `OMENOS_DATA`). Tanpa `--data-disk`, HDD tidak disentuh sama sekali.
   Disk USB/media instalasi otomatis ditolak sebagai target.
6. Boot pertama: `journalctl -u omen-setup-once -f` (driver NVIDIA dari AUR).
   Retry otomatis tiap 15 menit sampai `/var/lib/omen/setup-done` ada.
7. Setelah driver terpasang: reboot, cek `prime-run glxinfo | grep "OpenGL renderer"`.

### Menulis USB dari Windows tanpa Rufus

Rufus mode DD memang jalur biasa, tetapi tidak wajib. Yang dipakai 2026-10-29
(berhasil, terverifikasi): PowerShell **sebagai Administrator** → `diskpart`
`clean` pada disk yang benar → tulis ISO mentah ke `\\.\PhysicalDriveN` →
baca balik dan bandingkan SHA256. Skrip sementaranya ada di
`%TEMP%\opencode\write-usb.ps1` dan `verify-usb.ps1` (tidak masuk repo karena
berisi nomor disk khusus mesin ini).

Pengaman yang dipakai sebelum menghapus: pastikan hanya **satu** disk USB,
nama mengandung `SanDisk`, ukuran 25–32 GB, dan ukuran ISO tepat
`3800973312` byte. Jangan pernah menjalankan `clean` pada nomor disk yang belum
dicek ulang dengan `Get-Disk`.

Hasil tulis: 3.800.973.312 byte dalam ±9,5 menit (≈6,7 MB/s, USB 2.0),
verifikasi baca-balik 41 detik.

### Akses jarak jauh untuk pengujian

Live ISO sudah punya `openssh`. Dari PC lain di jaringan yang sama:

```bash
sudo systemctl start sshd
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo '<public key>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ip -4 -o addr show scope global
```

Lalu dari PC penguji: `ssh omen@<ip>`. Root SSH password diblokir
(`PermitRootLogin prohibit-password`), jadi pakai user `omen`.

## 6. Yang belum terverifikasi / TODO

- Boot ISO dan instalasi di 15-dc00036tx fisik.
- Backend fan aktual di 15-dc: apakah hwmon `hp` terdaftar (`fan_count > 0` dari
  WMI `0x10`) dan apakah `pwm1_enable=0` (WMI `0x27`) benar-benar menaikkan
  kipas. Kalau tidak ada keduanya, satu-satunya tuas = EC `0x95` manual.
  `hp-wmi-sensors` dipastikan **tidak** ada (`instance_count=0` di `_WDG`).
- Apakah EC menerima `0x95=0x02` (Cool) tanpa langsung dikembalikan; hasil
  `sudo omen-control fan cool` di live session yang menentukan.
- Nama zona LED aktual untuk model lain (TUXOV: `right,center,left,wasd`;
  pelrun: `rgb_zones/`) — tidak berlaku untuk SKU ini yang bukan 4 zona.
- Kualitas Wi-Fi/BT (`iwlwifi` AC 9560) dan suspend (`mem_sleep_default=deep`).
- GUI fan/RGB belum ada (CLI + TOML).
- Undervolt CPU tidak disertakan.
- Mode termal firmware **Cool** belum otomatis; hanya lewat `fan cool` eksplisit
  (daemon tidak menulis EC karena risiko bentrok dengan firmware).

## 7. Lingkungan pembuat

Dua mesin, dua-duanya Windows, **tidak ada Linux lokal** (WSL tidak terpasang di
laptop; VT-x nonaktif di desktop) → ISO **selalu** dibangun di GitHub Actions.

| Mesin | Peran | Catatan |
|---|---|---|
| Laptop **OMEN 15-dc00036tx** (`DESKTOP-OKNQFE1`, 192.168.18.31) | unit uji + tempat kerja sekarang | 12 GB bebas di C:; git ada di `C:\Program Files\Git` |
| Desktop **fajarPC** (`192.168.18.6`) | mesin lama, punya repo + OpenCode serve | ASUS i5-10400 + RTX 2060 |

Sesi OpenCode dari fajarPC sudah diimpor ke laptop ini (ID sama,
`ses_e7aa54175ffdjS2RT11jC8v6bo`) supaya riwayat kerja tidak hilang. Server di
fajarPC tetap hidup di `0.0.0.0:4096` dengan password sendiri — matikan kalau
tidak dipakai:

```bash
opencode service stop     # di fajarPC
```

Jangan mengandalkan build lokal di kedua mesin.
