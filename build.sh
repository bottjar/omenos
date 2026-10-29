#!/usr/bin/env bash
# build.sh — bangun ISO OmenOS. Jalankan di Arch Linux (atau container archlinux).
#   sudo ./build.sh
# Hasil: out/omenos-<versi>-x86_64.iso
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE="${PROFILE:-$HERE/build/profile}"
OUT="${OUT:-$HERE/out}"
WORK="${WORK:-$HERE/work}"
RELENG="${RELENG:-/usr/share/archiso/configs/releng}"

[[ $EUID -eq 0 ]] || { echo "mkarchiso butuh root"; exit 1; }
[[ -d "$RELENG" ]] || { echo "profil releng tidak ada: $RELENG (pacman -S archiso)"; exit 1; }

echo "==> menyiapkan profil"
rm -rf "$PROFILE"
mkdir -p "$PROFILE" "$OUT" "$WORK"
cp -a "$RELENG/." "$PROFILE/"
cp -a "$HERE/overlay/." "$PROFILE/"

echo "==> menggabungkan daftar paket"
{
  grep -vE '^\s*(#|$)' "$RELENG/packages.x86_64"
  grep -vE '^\s*(#|$)' "$HERE/overlay/packages.x86_64"
} | awk '!seen[$0]++' > "$PROFILE/packages.x86_64"
cp "$PROFILE/packages.x86_64" "$PROFILE/airootfs/root/packages.x86_64"

echo "==> menyambungkan skrip kustomisasi"
CUSTOM="$PROFILE/airootfs/root/customize_airootfs.sh"
if [[ -f "$CUSTOM" ]]; then
  grep -q 'omen-customize' "$CUSTOM" || printf '\n/root/omen-customize.sh\n' >> "$CUSTOM"
else
  # archiso versi baru menghapus hook ini: pakai skrip kita langsung
  printf '#!/usr/bin/env bash\n/root/omen-customize.sh\n' > "$CUSTOM"
fi
chmod +x "$CUSTOM" "$PROFILE/airootfs/root/omen-customize.sh"
chmod +x "$PROFILE/airootfs/usr/local/bin/"* 2>/dev/null || true

echo "==> mkarchiso (unduh paket + buat squashfs; 15-40 menit)"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

echo
echo "==> selesai"
ls -lh "$OUT"/*.iso
echo "Tulis ke USB (Linux):  sudo dd if=$(ls "$OUT"/*.iso | head -1) of=/dev/sdX bs=4M status=progress oflag=sync"
