#!/usr/bin/env bash
# Bagian OmenOS dari customize_airootfs.sh. File ini TIDAK menimpa skrip releng:
# build.sh menambahkan satu baris pemanggilan di akhir skrip releng.
set -euo pipefail

# --- locale & waktu
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# --- jaringan: profil releng mengaktifkan systemd-networkd + systemd-resolved
# + iwd. OmenOS memakai NetworkManager (applet Plasma + pengaturan Wi-Fi),
# jadi ketiganya dimatikan agar tidak ada dua pengelola jaringan/DNS.
for svc in systemd-networkd.service systemd-networkd.socket \
           systemd-networkd-wait-online.service systemd-resolved.service \
           iwd.service; do
  systemctl disable "$svc" 2>/dev/null || true
done
# NetworkManager menulis /etc/resolv.conf sendiri; jangan biarkan symlink
# ke stub-resolv.conf yang sudah tidak aktif.
rm -f /etc/resolv.conf && : > /etc/resolv.conf

# --- identitas live
echo "omenos-live" > /etc/hostname
echo "root:omen" | chpasswd

# user live supaya SDDM punya sasaran login (bukan root)
useradd -m -G wheel,video,render,audio,input,power,storage -s /bin/bash omen 2>/dev/null || true
echo "omen:omen" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-omenos-autologin.conf <<'EOF'
[Autologin]
User=omen
Session=plasma
Relogin=true
EOF

# --- tema OmenOS: mark berlian, wallpaper, SDDM, Plasma, GRUB.
# Sumber tetap SVG (mudah diubah); PNG dibuat di sini karena SDDM/GRUB lebih
# aman memakai raster dan Plasma tidak perlu bergantung pada plugin SVG.
THEME=/usr/share/omenos
SDDM_THEME=/usr/share/sddm/themes/omenos
PLASMA_THEME=/usr/share/plasma/look-and-feel/org.omenos.desktop
install -d "$THEME/brand" "$THEME/wallpapers" "$THEME/grub" \
           "$SDDM_THEME" "$PLASMA_THEME/contents/splash/images" \
           /usr/share/color-schemes /usr/share/applications
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 512 -h 512 "$THEME/brand/omenos-mark.svg" \
    -o "$THEME/brand/omenos-mark.png"
  rsvg-convert -w 1920 -h 1080 "$THEME/wallpapers/omenos-wallpaper.svg" \
    -o "$THEME/wallpapers/omenos-1920x1080.png"
  rsvg-convert -w 2560 -h 1440 "$THEME/wallpapers/omenos-sddm.svg" \
    -o "$SDDM_THEME/background.png"
  rsvg-convert -w 1920 -h 1080 "$THEME/wallpapers/omenos-grub.svg" \
    -o "$THEME/grub/background.png"
  rsvg-convert -w 256 -h 256 "$THEME/brand/omenos-mark.svg" \
    -o "$SDDM_THEME/omenos-mark.png"
else
  echo "peringatan: rsvg-convert tidak ada; memakai SVG langsung untuk SDDM"
  cp -f "$THEME/wallpapers/omenos-sddm.svg" "$SDDM_THEME/background.svg"
  sed -i 's/^background=.*/background=background.svg/' "$SDDM_THEME/theme.conf"
fi
chmod 644 "$THEME"/brand/* "$THEME"/wallpapers/* "$THEME"/grub/* 2>/dev/null || true
chmod 644 "$SDDM_THEME"/* 2>/dev/null || true

# Salin tema ke user live (skel sudah berisi konfigurasi yang sama).
if id omen >/dev/null 2>&1; then
  install -d -m 700 -o omen -g omen /home/omen/.config
  cp -a /etc/skel/.config/. /home/omen/.config/ 2>/dev/null || true
  chown -R omen:omen /home/omen/.config
fi

# --- layanan yang harus hidup di live session
for svc in NetworkManager.service bluetooth.service sddm.service \
           omen-fan.service omen-rgb.service power-profiles-daemon.service \
           fstrim.timer systemd-timesyncd.service avahi-daemon.service; do
  systemctl enable "$svc" 2>/dev/null || echo "peringatan: gagal enable $svc"
done

# --- overlay untuk omen-install (dipasang ke sistem hasil instalasi)
FILES=(
  etc/omen
  etc/skel
  etc/xdg/kdeglobals
  etc/sddm.conf.d/20-omenos-theme.conf
  etc/modprobe.d/nvidia.conf
  etc/modprobe.d/omen-audio.conf
  etc/modprobe.d/omen-wifi.conf
  etc/sysctl.d/99-omen-zram.conf
  etc/systemd/system/omen-fan.service
  etc/systemd/system/omen-rgb.service
  etc/systemd/zram-generator.conf
  usr/share/omenos
  usr/share/sddm/themes/omenos
  usr/share/color-schemes/OmenOS.colors
  usr/share/plasma/look-and-feel/org.omenos.desktop
  usr/share/applications/omen-nvidia.desktop
  usr/local/bin/omen-control
  usr/local/bin/omen-probe
  usr/local/bin/omen-setup
  usr/local/bin/omen-install
  usr/local/bin/omen-aur
  usr/local/bin/prime-run
  root/packages.x86_64
)
PRESENT=()
for f in "${FILES[@]}"; do
  [ -e "/$f" ] && PRESENT+=("$f")
done
if [ ${#PRESENT[@]} -gt 0 ]; then
  tar -C / -cf /root/omen-overlay.tar "${PRESENT[@]}"
else
  echo "peringatan: tidak ada file overlay yang ditemukan"
fi

# --- modul nvidia ke initramfs bila paket driver sudah ada di ISO
# (normalnya TIDAK ada: driver dipasang omen-setup di sistem target)
if pacman -Qq nvidia-580xx-dkms >/dev/null 2>&1 \
   || pacman -Qq nvidia-open-dkms >/dev/null 2>&1 \
   || pacman -Qq nvidia-utils >/dev/null 2>&1; then
  grep -q '^MODULES=.*nvidia' /etc/mkinitcpio.conf || \
    sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
fi

# --- hemat ukuran ISO
pacman -Scc --noconfirm >/dev/null 2>&1 || true
echo "OmenOS: omen-customize selesai."
