# Matriks hardware & catatan risiko

## Identifikasi model

```bash
cat /sys/class/dmi/id/product_name    # unit ini: OMEN by HP Laptop 15-dc0xxx
cat /sys/class/dmi/id/board_name      # unit ini: 84DA  <- nomor ini yang dipakai driver
cat /sys/class/dmi/id/bios_version    # unit ini: F.19
```

`board_name` adalah kunci: driver `hp-wmi` mencocokkan **board name**, bukan nama produk.

## Model target: Omen 15-dc00036tx (2018)

| Aspek | Nilai / keputusan |
|---|---|
| Seri | 15-dc0000 (~15-dc0999), 2018 |
| SKU unit ini | **4NT40PA#AR6** |
| Board | **84DA** (terverifikasi dari unit fisik), 84DA/84DB ada di `omen_thermal_profile_boards` |
| CPU | **i7-8750H** 6C/12T, HM370 |
| GPU | **GTX 1050 Ti 4 GB** (GP107, `10de:1c8c`) — SKU lain seri ini bisa 1050/1060/1070 Max-Q |
| RAM | 16 GB DDR4-2667, satu keping (single-channel) |
| Disk | NVMe 128 GB (sistem) + HDD 1 TB (`/data`) |
| Jaringan | Intel Wireless-AC 9560 (`iwlwifi`), Realtek RTL8168 (`r8169`) |
| Audio | Realtek ALC295 (`103c:84da`) |
| Driver GPU | `nvidia-580xx-dkms` (AUR) — **bukan** `nvidia-open` |
| Fan | **EC, tanpa PWM** (`IsSwFanControlSupport=False` dari firmware HP); kalau kernel mengekspos `pwm1_enable`, backend `pwm-boost` |
| RGB | **tidak ada** di SKU ini (`keyboardType=0`, backlight putih 1 warna); backend tetap ada untuk model lain |
| Suspend | `mem_sleep_default=deep` (s2idle tidak andal) |

Detail lengkap: [MODEL-15-dc00036tx.md](MODEL-15-dc00036tx.md).
Bukti dari aplikasi OMEN asli: [OMEN-APP-RE.md](OMEN-APP-RE.md).

## Dukungan fan

| Sumber | Cakupan | Catatan |
|---|---|---|
| `hp-wmi` bawaan kernel | monitor RPM + `pwm1_enable` auto/max; `platform_profile` di model lain | 84DA/84DB: `platform_profile` **tidak terdaftar** (query desain WMI `0x28` gagal); RPM lewat hwmon `hp` (`0x10`/`0x11`, belum pasti) |
| `hp-wmi-sensors` bawaan kernel | hwmon `hp_wmi_sensors`: RPM kipas + suhu | **tidak aktif di 84DA**: GUID `8F1F6435…` punya `instance_count=0`, kernel melewatinya |
| `ec_sys` (debugfs) | baca/tulis profil termal EC `0x95` | khusus 84DA/84DB; `0x00` balanced, `0x01` performance, `0x02` cool; eksplisit, bukan daemon |
| TUXOV `hp-wmi-fan-and-backlight-control` | PWM manual 0-255 + RGB 4 zona | manual bergantung model; `pwm1_max` tidak ada, diuji `pwm1_enable=1` |
| kernel ≥ 6.19/7.x (`hp-wmi` upstream) | PWM manual + keep-alive untuk Omen/Victus baru | belum tentu untuk 15-dc |
| `omen-rgb-keyboard` (OmenLinux) | RGB + fan RPM/curve + preset termal | driver komunitas, DKMS |
| pelrun `hp-omen-linux-module` | RGB 4 zona (`rgb_zones/`) | tanpa fan; fallback terakhir |
| `OpenOMEN` | Ubuntu/Arch/NixOS, fan + stats + RGB parsial | alternatif, v0.4 belum stabil |
| `nbfc-linux` | model non-Omen / laptop lain | daftar config terbatas |

Model yang dilaporkan berhasil di proyek `omen-fan-control`:
Omen Max 16-AH0xxxNT (8D41), Transcend 16-u1xxx (8C4D), 16-u0xxx (8BB3),
Omen 16-xf0xxx (8BCA)¹, Victus 16-s1xxx (8C9C), Omen 15-ek1xxx (88C8), Omen 16-ap0000 (8E35).

¹ board 8BCA: fan control **hanya** berjalan di sebagian unit; lihat bagian ACPI.

## NVIDIA: Pascal vs Turing

Branch 590 (Desember 2025) menghapus Pascal. Aturan paket:

| GPU | Contoh | Paket |
|---|---|---|
| Pascal/Maxwell/Kepler | GTX 10xx/9xx, GT 10xx, MX 1xx–3xx, Quadro K/M/P | `nvidia-580xx-dkms` + `nvidia-580xx-utils` (AUR) |
| Turing ke atas | GTX 16xx, RTX 20xx+ | `nvidia-open-dkms` + `nvidia-utils` (repo resmi) |

`nvidia-prime` **tidak dipakai** di kedua jalur karena bergantung pada
`nvidia-utils` (590). OmenOS mengirim `/usr/local/bin/prime-run` sendiri.

Cek cepat:

```bash
lspci -nn | grep -i nvidia          # 10de:1bxx/1cxx/1dxx = Pascal
pacman -Q | grep -i nvidia
nvidia-smi
dkms status
```

## Bug ACPI yang tidak bisa diperbaiki dari software

Gejala: `hp_wmi` load tanpa error, tapi `/sys/firmware/acpi/platform_profile` tidak ada,
RPM selalu 0, semua tool fan gagal.

> Pada 84DA/84DB (15-dc0000) ketiadaan `platform_profile` juga **normal** dan
> bukan bug ACPI ini: query desain WMI `0x28` memang mengembalikan
> `returnCode=3`, tanpa pesan `AE_NOT_FOUND`. Bedakan lewat
> `dmesg | grep -i 'ACPI BIOS Error'`; detail di
> [OMEN-APP-RE.md](OMEN-APP-RE.md) §7.2.

```
ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PEP.DETY], AE_NOT_FOUND
```

Penyebab: tabel ACPI BIOS tidak mengekspos simbol yang dipakai method termal WMI.
Windows memakai driver HP sendiri sehingga tidak terpengaruh. Perbaikan hanya lewat
update BIOS dari HP; ada patch DSDT komunitas
(`OmenLinux/ACPI-Fix-for-HP-Omen-16-u0000sl`) tapi **mengganti tabel ACPI berisiko
brick** dan tidak disertakan di ISO ini.

## Risiko yang perlu disadari

1. **Menulis PWM/EC** adalah perintah langsung ke embedded controller. Nilai ekstrem
   yang dikirim terus menerus bisa membuat fan berisik permanen atau, pada kasus
   langka, membuat EC perlu reset (cabut baterai/BIOS reset). Karena itu `omen-control`:
   - memakai antarmuka resmi `pwm1`/`pwm1_enable`, **bukan** tulis EC mentah;
   - punya histeresis dan interval 5 detik, bukan loop rapat;
   - mengembalikan mode otomatis saat service berhenti (SIGTERM);
   - berhenti dengan exit 0 kalau backend tidak ada (tidak restart-loop).
2. **Driver RGB komunitas tidak bertanda tangan.** Dengan Secure Boot aktif, modul
   ditolak. Jangan memaksa `mokutil --disable-validation`; matikan Secure Boot atau
   tandatangani sendiri.
3. **TUXOV menggantikan `hp-wmi` kernel.** Kalau driver gagal load, fan monitoring
   dan hotkey bisa hilang. `omen-setup` menyimpan laporan probe sebelum/sesudah.
4. **Build AUR di boot pertama** butuh internet dan waktu 5–15 menit. Kalau gagal,
   sistem tetap bisa boot dengan nouveau/llvmpipe; jalankan ulang `sudo omen-setup`.
5. **Model dengan MUX switch**: profil termal bisa ditolak EC saat GPU discrete aktif.
   Ini perilaku firmware, bukan bug daemon.

## Kalau build gagal

| Gejala | Sebab umum |
|---|---|
| `pacstrap` gagal unduh paket | mirror lambat; `reflector --latest 10 > /etc/pacman.d/mirrorlist` lalu ulangi |
| `pacstrap: target not found: lib32-*` | multilib belum aktif di live ISO — paket lib32 sengaja tidak ada di daftar; dipasang `omen-setup` setelah multilib |
| `mkarchiso: command not found` | `pacman -S archiso` di container/host |
| ISO > 4 GB | buang `plasma-meta` (pakai `plasma-desktop`), atau turunkan level zstd |
| Docker: `operation not permitted` | butuh `--privileged`; pastikan Docker Desktop mode Linux container |
| `omen-aur` gagal: `makepkg` menolak root | jalankan lewat `omen-aur`, bukan `makepkg` langsung |
| DKMS gagal untuk kernel LTS | pastikan `linux-lts-headers` terpasang (ada di daftar paket) |

## Diagnostik

```bash
sudo omen-probe > ~/omen-probe.txt
```

Isi: DMI, GPU + PCI ID, Wi-Fi, modul, hwmon, platform_profile, LED class,
rgb_zones, dmesg ACPI, nvidia-smi/dkms, baterai, status service, dan
`omen-control status`.
