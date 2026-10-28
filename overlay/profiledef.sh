#!/usr/bin/env bash
# shellcheck disable=SC2034
# Profil OmenOS (archiso). Disalin di atas profil releng oleh build.sh.

iso_name="omenos"
iso_label="OMENOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="OmenOS <https://example.invalid/omenos>"
iso_application="OmenOS - Arch-based distribution tuned for HP OMEN laptops"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/omen-customize.sh"]="0:0:755"
  ["/etc/omen"]="0:0:755"
  ["/usr/share/omenos"]="0:0:755"
  ["/usr/share/omenos/grub"]="0:0:755"
  ["/usr/share/sddm/themes/omenos"]="0:0:755"
  ["/usr/share/plasma/look-and-feel/org.omenos.desktop"]="0:0:755"
  ["/usr/local/bin/omen-control"]="0:0:755"
  ["/usr/local/bin/omen-probe"]="0:0:755"
  ["/usr/local/bin/omen-setup"]="0:0:755"
  ["/usr/local/bin/omen-install"]="0:0:755"
  ["/usr/local/bin/omen-aur"]="0:0:755"
  ["/usr/local/bin/prime-run"]="0:0:755"
)
