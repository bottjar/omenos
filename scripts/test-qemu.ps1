# test-qemu.ps1 — boot ISO OmenOS di QEMU untuk uji cepat sebelum ditulis ke USB.
#   .\test-qemu.ps1 [-Iso .\out\omenos-xxxx.iso] [-Ram 8192] [-Uefi]
param(
    [string]$Iso,
    [int]$Ram = 8192,
    [switch]$Uefi
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Iso) {
    $Iso = (Get-ChildItem "$root\out\*.iso" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $Iso -or -not (Test-Path $Iso)) { Write-Error "ISO tidak ditemukan. Jalankan .\build.ps1 dulu." }

$qemu = (Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue).Source
if (-not $qemu) {
    Write-Host "QEMU belum ada. Install dulu:" -ForegroundColor Yellow
    Write-Host "  winget install SoftwareFreedomConservancy.QEMU"
    Write-Host ""
    Write-Host "Alternatif tanpa QEMU: tulis ISO ke USB dengan Rufus (mode DD), boot dari USB,"
    Write-Host "lalu jalankan 'omen-install'. ISO juga bisa diuji langsung tanpa memasang apa pun."
    exit 1
}

$qemuArgs = @(
    "-m", "$Ram",
    "-smp", "4",
    "-cdrom", $Iso,
    "-boot", "d",
    "-vga", "qxl",
    "-display", "gtk"
)
if ($Uefi) {
    $ovmf = Get-ChildItem "C:\Program Files\qemu\share\edk2-x86_64-code.fd" -ErrorAction SilentlyContinue
    if ($ovmf) { $qemuArgs += @("-bios", $ovmf.FullName) }
    else { Write-Host "OVMF tidak ditemukan, boot BIOS saja." -ForegroundColor Yellow }
}

Write-Host "==> boot $Iso"
& $qemu @qemuArgs
