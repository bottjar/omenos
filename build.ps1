# build.ps1 — bangun ISO OmenOS dari Windows memakai Docker + container Arch.
#   .\build.ps1
# Prasyarat: Docker Desktop (mode Linux container) dan ~10 GB ruang disk.
#
# Catatan penting: folder repo di-mount READ-ONLY ke /src, sedangkan profil,
# work dir, dan chroot mkarchiso dibuat di dalam container (/var/tmp). Ini
# menghindari masalah permission/mknod/hardlink yang muncul kalau mkarchiso
# bekerja langsung di bind-mount NTFS. Hanya ISO hasil akhir yang ditulis ke
# out\ di Windows.
param(
    [string]$Image = "archlinux:latest"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker tidak ditemukan. Install Docker Desktop, atau jalankan build.sh di Arch/WSL."
}

Write-Host "==> cek daemon docker"
docker info --format '{{.OSType}}/{{.Architecture}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker daemon tidak berjalan. Buka Docker Desktop (mode Linux container), tunggu sampai 'Engine running'."
}

New-Item -ItemType Directory -Force -Path "$root\out" | Out-Null

$buildScript = @'
set -euo pipefail
# container archlinux:latest bisa tertinggal beberapa bulan; update keyring dulu
# supaya tanda tangan paket tidak ditolak.
pacman -Syu --noconfirm
pacman -S --noconfirm --needed archiso
export PROFILE=/var/tmp/omen-profile
export WORK=/var/tmp/omen-work
export OUT=/out
cd /src
bash build.sh
'@

Write-Host "==> menjalankan mkarchiso di container (bisa 15-40 menit)"
docker run --rm --privileged `
    -v "${root}:/src:ro" `
    -v "${root}\out:/out" `
    -w /src `
    $Image bash -lc $buildScript

if ($LASTEXITCODE -ne 0) { Write-Error "build gagal (exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "==> hasil:"
Get-ChildItem "$root\out\*.iso" | Format-Table Name, @{n = "GB"; e = { [math]::Round($_.Length / 1GB, 2) } }
Write-Host "Tulis ke USB dengan Rufus (mode DD) atau balenaEtcher."
