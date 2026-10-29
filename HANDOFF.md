# HANDOFF — status & cara melanjutkan

Dokumen ini untuk melanjutkan pekerjaan OmenOS di mesin lain (mis. di laptop Omen
setelah OmenOS terpasang) atau setelah percakapan lama tidak tersedia.

## 1. Tujuan

Distro Linux berbasis **Arch Linux** (remaster `archiso`) untuk **HP OMEN
15-dc00036tx** (seri 15-dc0000, 2018, Coffee Lake + GTX 1060/1070 Max-Q Pascal,
keyboard RGB 4 zona). Yang wajib jalan: driver NVIDIA, kontrol fan, kontrol RGB.

## 2. Status per 2026-10-29

| Item | Nilai |
|---|---|
| ISO | `omenos-2026.10.29-x86_64.iso`, 3.790.602.240 byte (3,8 GB) |
| SHA256 | `a21e4e561e5cfacf4ae64dda9cc0d6546c936cdc1e25d633c56f0001c23f40e7` |
| Link | https://gofile.io/d/1UVA59Zh (publik, mungkin kedaluwarsa) |
| Build | GitHub Actions `success`, ±9 menit |
| Repo | https://github.com/bottjar/omenos |
| Run | https://github.com/bottjar/omenos/actions/runs/40809835551 |

ISO **belum pernah di-boot** di hardware Omen. Semua uji sejauh ini: `bash -n`,
`shellcheck -S warning`, dan `tests/selftest.py` (9 skenario, semua lolos).

Build ulang kapan saja: push ke `main`, atau Actions → **Build ISO** → *Run
workflow*. Hasil: link gofile di ringkasan run; cadangan artifact/Release.

## 3. Keputusan teknis yang sudah final

- Basis **archiso releng**, bukan from-scratch. Profil = releng + `overlay/`.
- **NVIDIA**: Pascal butuh `nvidia-580xx-dkms` dari AUR (Arch 590+ & `nvidia-open`
  hanya Turing+). Driver **tidak** ada di ISO; `omen-setup` membangunnya di boot
  pertama (butuh internet, 5–15 menit).
- `prime-run` milik sendiri; paket `nvidia-prime` tidak dipakai.
- **Fan 15-dc**: hanya auto/max lewat `pwm1_enable` (atau `pwm1`) → backend
  `pwm-boost` dengan histeresis: ON 76 °C, OFF 68 °C, safety 93 °C, release 87 °C.
- **RGB** prioritas: LED kernel `hp::kbd_backlight*` → TUXOV
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
tests/selftest.py           # 9 skenario sysfs palsu
docs/HARDWARE.md            # matriks model & risiko
docs/MODEL-15-dc00036tx.md  # detail model ini
```

## 5. Rencana uji di hardware (belum dilakukan)

1. Tulis ISO ke USB ≥ 8 GB: **Rufus mode DD** atau `dd bs=4M oflag=sync`.
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
   omen-install /dev/nvme0n1     # konfirmasi "ERASE"
   ```
6. Boot pertama: `journalctl -u omen-setup-once -f` (driver NVIDIA dari AUR).
   Retry otomatis tiap 15 menit sampai `/var/lib/omen/setup-done` ada.
7. Setelah driver terpasang: reboot, cek `prime-run glxinfo | grep "OpenGL renderer"`.

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
- Backend fan aktual di 15-dc (`pwm1_enable` vs `pwm1`+`pwm1_enable`) — daemon
  memprobe saat start.
- Nama zona LED aktual (TUXOV: `right,center,left,wasd`; pelrun: `rgb_zones/`).
- Ketersediaan PWM manual TUXOV di 15-dc.
- Kualitas Wi-Fi/BT (`rtl8822be`/`iwlwifi`?) dan suspend (`mem_sleep_default=deep`).
- GUI fan/RGB belum ada (CLI + TOML).
- Undervolt CPU tidak disertakan.

## 7. Lingkungan pembuat

PC build: **ASUS desktop i5-10400 + RTX 2060**, Windows, **VT-x nonaktif**
(`Virtualization Enabled In Firmware: No`) → Docker/WSL2 tidak bisa; build
dilakukan di GitHub Actions. Jangan mengandalkan build lokal di mesin itu.
