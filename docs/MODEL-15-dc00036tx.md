# OMEN by HP 15-dc00036tx — catatan khusus

Dokumen ini menjelaskan semua keputusan OmenOS yang berbeda dari default Arch
karena model ini. Semua angka yang belum bisa dipastikan di hardware ditandai
**verifikasi**.

## Identitas

Dibaca langsung dari unit ini lewat WMI/CIM di Windows (2026-10-29), bukan dari
spek pemasaran. Yang hanya bisa dipastikan dari Linux ditandai **verifikasi**.

| Item | Nilai |
|---|---|
| Nama pemasaran | OMEN by HP Laptop 15-dc0xxx (`product_name`), seri 2018 |
| SKU | **4NT40PA#AR6** |
| Mainboard | **84DA** (`board_name`), BIOS **AMI F.19** (2022-11-14) |
| CPU | **Core i7-8750H**, 6C/12T, 45 W |
| Chipset | Intel HM370 |
| GPU | **GeForce GTX 1050 Ti 4 GB**, GP107, `10de:1c8c` (subsystem `103c:84da`) |
| GPU terpadu | Intel UHD Graphics 630 (Coffee Lake, Gen9.5) |
| RAM | **16 GB DDR4-2667, satu keping** (slot 2) → single-channel |
| Penyimpanan | **NVMe 128 GB** (Toshiba KBG30ZMV128G) + **SATA HDD 1 TB** (ST1000LM049) |
| Wi-Fi / BT | **Intel Wireless-AC 9560**, `8086:a370`, driver `iwlwifi` |
| Ethernet | Realtek RTL8168, driver `r8169` |
| Audio | **Realtek ALC295**, subsystem `103c:84da` |
| Layar | 15.6" **1920×1080 @60 Hz** |
| Keyboard | RGB 4 zona (spesifikasi seri) — **verifikasi** `ls /sys/class/leds` |
| Baterai | **verifikasi** `omen-probe` di Linux (WMI Windows tidak melaporkan Wh) |

Koreksi penting dibanding dokumen sebelumnya: GPU unit ini **GTX 1050 Ti**, bukan
1060/1070 Max-Q, dan board-nya **84DA**, bukan 84DB. Keduanya tetap Pascal dan
tetap memakai jalur `hp-wmi` yang sama, jadi keputusan driver/fan/RGB di bawah
tidak berubah — yang jadi pasti hanya daya/panas, jalur Wi-Fi, dan audio.

Konsekuensi praktis untuk mesin ini:

- **Pascal** → tetap `nvidia-580xx-dkms` (bukan `nvidia-open`).
- **Dua disk** → sistem di NVMe 128 GB, HDD 1 TB sebagai `/data`
  (`omen-install --data-disk`). 128 GB cukup untuk sistem + dua kernel, tidak
  untuk menyimpan ISO/game besar.
- **Single-channel 16 GB** → zram tetap penting; bandwidth memori separuh
  konfigurasi dua keping, jadi compile/build terasa lebih berat.
- **iwlwifi 9560** → tidak butuh paket tambahan (firmware ada di `linux-firmware`).
- **ALC295** → butuh `alsa-ucm-conf`; pop saat idle dimatikan lewat
  `/etc/modprobe.d/omen-audio.conf`.

## 1. NVIDIA — wajib legacy 580xx

Arch Linux branch 590 (Desember 2025) **menghapus dukungan Pascal**. Paket
`nvidia`, `nvidia-open`, dan `nvidia-open-dkms` hari ini hanya untuk Turing
(RTX 20xx / GTX 16xx) ke atas. Kalau dipasang di 15-dc, hasilnya bisa layar
hitam atau `nvidia-smi` gagal.

Karena itu:

| Hal | Keputusan OmenOS |
|---|---|
| Driver | `nvidia-580xx-utils` + `nvidia-580xx-dkms` + `lib32-nvidia-580xx-utils` dari **AUR** |
| Versi yang diuji | 580.196.07-1 |
| Pembangunan | `omen-aur` (user `aurbuilder`, `makepkg -si`), bukan AUR helper |
| `nvidia-prime` | **tidak dipakai** — paket resmi bergantung pada `nvidia-utils` (590) |
| Pengganti | `/usr/local/bin/prime-run` (variabel `__NV_PRIME_RENDER_OFFLOAD`) |
| Parameter kernel | `nvidia-drm.modeset=1`, `nvidia.NVreg_PreserveVideoMemoryAllocations=1` |
| Initramfs | modul `nvidia nvidia_modeset nvidia_uvm nvidia_drm` ditambahkan **setelah** driver terpasang |
| Nouveau | diblacklist hanya setelah driver NVIDIA terpasang |

Jangan pernah menjalankan:

```bash
sudo pacman -S nvidia nvidia-open nvidia-open-dkms nvidia-utils nvidia-prime
```

`omen-setup` mendeteksi GPU lewat nama kartu **dan** PCI ID (`10de:1bxx`,
`1cxx`, `1dxx`, `13xx`, `17xx` = Pascal/Maxwell) lalu memilih jalur legacy.

## 2. Fan — hanya AUTO atau MAX

`hp-wmi` untuk board 84DA/84DB tidak punya PWM proporsional:

```
# kernel lama (mis. 6.6): hanya file mode
/sys/devices/platform/hp-wmi/hwmon/hwmonX/pwm1_enable   (0 = max, 2 = auto)

# kernel baru / TUXOV: pwm1 + pwm1_enable
/sys/devices/platform/hp-wmi/hwmon/hwmonX/pwm1          (0 = max, 2 = auto)
/sys/devices/platform/hp-wmi/hwmon/hwmonX/pwm1_enable   (0 = max, 2 = auto)
/sys/devices/platform/hp-wmi/hwmon/hwmonX/fan1_input    (RPM, read-only)
```

Tidak ada `pwm1_max` dan tidak ada PWM proporsional. Menulis `40` ke `pwm1`
tidak berarti 40% — driver memperlakukannya sebagai mode. Maka:

- Backend terdeteksi: **`pwm-boost`** (lewat `pwm1_enable` bila `pwm1` tidak ada).
- Kalau kernel sangat baru hanya mendaftarkan hwmon untuk model yang punya
  tabel fan, 15-dc bisa tidak punya file PWM sama sekali. Dalam hal itu
  `omen-control` memakai backend **`platform-profile`** (84DA/84DB terdaftar
  di `omen_thermal_profile_boards`) dan menaikkan profil termal saat panas.
  Cek hasil deteksi dengan `omen-control status`.
- Kurva menjadi on/off dengan histeresis:
  - `boost_on_c = 76` → fan MAX
  - `boost_off_c = 68` → kembali AUTO
  - `safety_temp_c = 93` → MAX
  - `safety_release_c = 87` → kembali normal
- `omen-control fan 40` tetap diterima, tetapi dipetakan ke AUTO (ambang 70%).
  Gunakan `omen-control fan boost on|off` kalau ingin eksplisit.
- `interval_s = 5` karena EC Omen bisa me-reset state sendiri.

Kalau Anda memasang driver komunitas TUXOV dan model ini ternyata mendukung
fan manual (`pwm1_enable=1` + `pwm1` 0-255 tanpa `pwm1_max`), `omen-control`
mendeteksinya saat daemon start dan otomatis pindah ke kurva PWM penuh.
Kalau driver menolak (`EOPNOTSUPP`), daemon kembali ke mode auto/max dan
menulis alasannya ke journal — tidak ada loop error.

## 3. RGB keyboard 4 zona

Urutan backend yang dipakai `omen-control`:

1. **LED multicolor kernel** — `/sys/class/leds/hp::kbd_backlight*`
   dengan `multi_intensity`. Tersedia kalau kernel sudah mengekspos RGB Omen.
2. **TUXOV hp-wmi** (`hp-wmi-fan-and-backlight-control`) — nama LED:
   `hp::kbd_zoned_backlight-wasd`, `-left`, `-center`, `-right`.
   Ini juga menambah fan manual bila didukung model.
3. **pelrun hp-omen-linux-module** — `/sys/devices/platform/hp-wmi/rgb_zones/zone00..03`.
   Hanya warna, tidak ada fan.
4. **omen-rgb-keyboard** — `rgb_zones/` + animasi + brightness.

Urutan zona fisik yang dipakai OmenOS:
`wasd → left → center → right` (nomor zona 0..3).

Perintah:

```bash
omen-control rgb set FF0000        # semua zona
omen-control rgb set 00FF00 2      # zona 2 (center) hijau
omen-control rgb brightness 60
omen-control rgb off
```

Driver komunitas tidak bertanda tangan → **Secure Boot harus off**, atau
tandatangani modul sendiri dengan `sbctl`.

## 4. Suspend / resume

Board 84DA/84DB tidak andal dengan `s2idle`. OmenOS menambahkan:

```
mem_sleep_default=deep
```

Parameter ini ditulis oleh `omen-install` (kalau board terdeteksi) dan oleh
`omen-setup`. Cek dengan:

```bash
cat /sys/power/mem_sleep     # harus ada [deep]
```

Untuk driver 580xx, service `nvidia-suspend`, `nvidia-resume`, dan
`nvidia-hibernate` diaktifkan oleh `omen-setup`; kombinasinya dengan
`NVreg_PreserveVideoMemoryAllocations=1` mencegah aplikasi crash setelah resume.

## 5. Memori dan grafis terpadu

16 GB **satu keping** berarti satu kanal memori; ini bukan sesuatu yang bisa
diperbaiki lewat software, tapi ada dua hal yang membuatnya tidak terlalu
terasa:

- **zram** (`/etc/systemd/zram-generator.conf`): `min(ram/2, 8 GiB)`, zstd.
  Tanpa partisi swap di NVMe 128 GB yang ruangnya sempit.
- **`vm.swappiness=100`** (`/etc/sysctl.d/99-omen-zram.conf`): halaman anonim
  dikompres ke RAM, bukan menunggu page cache habis. zram tidak menyentuh disk,
  jadi tidak ada risiko aus flash; `vfs_cache_pressure=50` menjaga cache
  filesystem saat compile besar.

Panel 1080p60 digerakkan **UHD 630** (`i915`), bukan GTX 1050 Ti. `omen-install`
menambahkan `i915` ke `MODULES` initramfs (early KMS) supaya tidak ada kedipan
saat SDDM mulai; `nvidia_drm` baru dimuat `omen-setup` setelah driver 580xx
terpasang. Decode video memakai `intel-media-driver` (VA-API), jadi tidak
membangunkan GPU diskrit hanya untuk menonton.

## 6. Hal yang belum terverifikasi

- `board_name` unit ini **84DA** (terverifikasi lewat WMI, bukan 84DB seperti
  dugaan awal dari simulator BIOS).
- Dukungan fan manual TUXOV pada 15-dc **belum diketahui**; daemon menguji
  sendiri saat start.
- Ketersediaan `hp::kbd_backlight` tergantung versi kernel. Kalau belum ada,
  `omen-setup` memasang TUXOV, lalu pelrun sebagai fallback.
- Watt/thermal limit CPU (PL1/PL2) tidak diubah. Undervolt tidak disertakan.

## 7. Checklist setelah instalasi

```bash
cat /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name
lspci -nn | grep -i nvidia
nvidia-smi
cat /sys/power/mem_sleep
omen-control status
omen-control fan max      # dengarkan fan naik
omen-control fan auto
omen-control rgb set FF0000
journalctl -u omen-fan -u omen-rgb -b --no-pager | tail -40
sudo omen-probe > ~/omen-probe.txt
```

Kirim `~/omen-probe.txt` kalau ada bagian yang tidak sesuai; kurva dan quirk
bisa disesuaikan dari data itu.
