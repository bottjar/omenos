# Tema OmenOS

Tema dibuat agar konsisten dengan bahasa visual OMEN: sasis hitam, aksen merah
logo, dan mark berlian dengan empat shard. Semua aset dibuat sendiri (SVG di
`overlay/airootfs/usr/share/omenos/`), jadi tidak ada logo HP berhak cipta yang
diredistribusikan. Palet dan bentuknya yang dibuat mirip, bukan salinan.

## Yang dipasang

| Bagian | Berkas | Cara kerja |
|---|---|---|
| Mark / logo | `usr/share/omenos/brand/omenos-mark.svg` | empat shard berlian; dipakai SDDM, splash, wallpaper |
| Wallpaper Plasma | `usr/share/omenos/wallpapers/omenos-wallpaper.svg` | `rsvg-convert` membuat `omenos-1920x1080.png` saat build |
| Latar SDDM | `usr/share/omenos/wallpapers/omenos-sddm.svg` | dibuat jadi `background.png` di tema SDDM |
| Latar GRUB | `usr/share/omenos/wallpapers/omenos-grub.svg` | dibuat jadi `grub/background.png` |
| Skema warna | `usr/share/color-schemes/OmenOS.colors` | Plasma, aplikasi Qt/KDE, dekorasi Breeze |
| Look-and-feel Plasma | `usr/share/plasma/look-and-feel/org.omenos.desktop/` | default warna, wallpaper, splash |
| Tema SDDM | `usr/share/sddm/themes/omenos/` | layar login QML (jam, user, sesi, tombol daya) |
| Tema GRUB | `usr/share/omenos/grub/theme.txt` | dipasang `omen-setup` **hanya** kalau bootloader = GRUB |
| Default pengguna baru | `etc/skel/.config/` | `useradd -m` menyalin `kdeglobals`, `ksplashrc`, wallpaper |

Palet:

| Nama | Nilai |
|---|---|
| Merah logo | `#e00012` |
| Merah terang (hover/shard) | `#ff3a4c` |
| Merah gelap (gradien) | `#780007` |
| Latar jendela | `#09090b` |
| Latar view/panel | `#0c0c0f` |
| Teks utama | `#f4f4f6` |
| Teks redup | `#9a9aa3` |

## Kenapa bootloader tidak selalu bertema

- **systemd-boot** (dipakai `omen-install`) tidak punya mesin tema/background.
  Yang bisa diatur hanya judul entri, timeout, dan resolusi console.
- **GRUB** punya tema penuh. `omen-setup` menyalin tema ke
  `/boot/grub/themes/omenos/` dan menulis `GRUB_THEME=` lalu `grub-mkconfig`.
- **Plymouth** tidak dipakai: paketnya hanya ada di AUR, sementara ISO dibangun
  dari repo resmi Arch. Splash grafis pertama adalah Plasma (look-and-feel),
  layar login adalah SDDM.

## Mengubah tema

1. Ganti warna di `OmenOS.colors` dan `etc/skel/.config/kdeglobals`.
2. Ganti SVG di `usr/share/omenos/`; PNG dibuat otomatis saat build.
3. Sesuaikan teks/ukuran di `usr/share/sddm/themes/omenos/Main.qml`.
4. Untuk GRUB, ubah `usr/share/omenos/grub/theme.txt` (font dan posisi menu).
5. Push ke `main`; workflow membangun ISO baru dan menaruh link di ringkasan.

Tidak perlu mengedit PNG: PNG adalah hasil build (`omen-customize.sh`).

## Uji cepat di sistem terpasang

```bash
# tema login (logout dulu; autologin live akan langsung masuk Plasma)
ls /usr/share/sddm/themes/omenos/
sudo sddm --example-config | grep -A2 '\[Theme\]'

# tema Plasma
plasma-apply-colorscheme OmenOS
plasma-apply-wallpaperimage /usr/share/omenos/wallpapers/omenos-1920x1080.png

# splash berikutnya
kwriteconfig6 --file ksplashrc --group KSplash --key Engine ksplashqml
kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.omenos.desktop
```

Kalau SDDM menampilkan layar hitam setelah tema dipasang, login ke TTY
(`Ctrl+Alt+F2`), lalu:

```bash
sudo sed -i 's/^Current=.*/Current=breeze/' /etc/sddm.conf.d/20-omenos-theme.conf
sudo systemctl restart sddm
```

Itu mengembalikan tema bawaan tanpa menyentuh data pengguna.
