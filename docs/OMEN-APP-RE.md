# Reverse engineering aplikasi OMEN (Windows) — apa yang benar-benar dipakai laptop ini

Dokumen ini mencatat hasil pembongkaran **OMEN Command Center / OMEN Light Studio**
di unit acuan OmenOS:

| Item | Nilai |
| --- | --- |
| Model | OMEN by HP Laptop 15-dc0xxx, SKU `4NT40PA#AR6` |
| Board / SystemID | `84DA` |
| Nama platform internal HP | **Gamora10** |
| BIOS | AMI **F.19** |
| CPU / GPU | i7-8750H / GTX 1050 Ti + UHD 630 |

Tujuannya bukan menyalin aplikasi Windows, melainkan menjawab satu pertanyaan:
**jalur hardware mana yang dipakai HP untuk fan, termal, dan lampu keyboard?**
Jawabannya menentukan apakah `omen-control` di OmenOS bisa mengendalikan sesuatu,
atau harus jujur mengatakan "tidak bisa".

---

## 1. Komponen yang terpasang

Aplikasi (Appx, publisher `AD2F1837` / `v10z8vjag6ke6`):

| Paket | Versi | Peran |
| --- | --- | --- |
| `AD2F1837.OMENCommandCenter` | `1101.2609.11.0` | UI + background + overlay game |
| `AD2F1837.OMENLightStudio` | `1.0.69.0` | UI lampu keyboard (engine "Aurora") |
| `AD2F1837.HPSystemEventUtility` | `3.2.24.0` | event sistem HP (hotkey, dsb.) |

Layanan (`Win32_Service`):

| Layanan | Biner | Catatan |
| --- | --- | --- |
| `HPOmenCap` | `...\hpomencustomcapcomp.inf_amd64_38ec91e432e20182\x64\OmenCap\OmenCap.exe` | **HP Omen HSA Service**, RPC `HPOmenRpcEndpoint` |
| `HPAppHelperCap` | `...\hpcustomcapcomp.inf_amd64_166246cb8bd387ff\x64\AppHelperCap.exe` | helper aplikasi HP generik |
| `HPDiagsCap`, `HPNetworkCap`, `HPSysInfoCap` | DriverStore | tidak relevan untuk fan/RGB |

Driver kernel:

| Driver | Berkas | Keterangan |
| --- | --- | --- |
| `hpomencustomcapdriver` | `hpomencustomcapdriver.sys` (KMDF, ~20 KB) | jalur perintah ke BIOS/EC |
| `HpReadHWData` | DriverStore | **berjalan** di unit ini; dibaca aplikasi sebagai syarat "driver terpasang" |
| `HPCustomCapDriver` | DriverStore | framework cap HP |
| `hpdskflt` | filter disk | perlindungan disk (HP 3D DriveGuard) |

Komponen perangkat: `SWC\HPIC0004` = *HP Omen Driver Component*
(`hpomencustomcapcomp.inf`, DriverVer `11/20/2025, 1.0.838.0`, `Class=SoftwareComponent`).

---

## 2. Arsitektur

```
┌──────────────────────────────────────────────────────────────────┐
│ UI            OMEN Command Center (UWP)   OMEN Light Studio      │
│               Overlay\Plugins\PerformanceControlPlugin.dll        │
└───────────────┬──────────────────────────────────────────────────┘
                │ named pipe ("Mailroom") + shared profile store
┌───────────────▼──────────────────────────────────────────────────┐
│ Background    OmenCommandCenterBackground.exe                    │
│               HP.Omen.Background.PerformanceControl.dll          │
│               HP.Omen.Features.Hardware.PerformanceMonitorBg.dll  │
│               HP.Omen.Background.FourZone.dll                    │
│               LightStudio-background.exe                         │
└───────────────┬──────────────────────────────────────────────────┘
                │ RPC (ncalrpc) endpoint "HPOmenRpcEndpoint"
┌───────────────▼──────────────────────────────────────────────────┐
│ Service       HPOmenCap → OmenCap.exe  "HP Omen HSA Service"     │
│               Hp::Bridge::Server::HSAService                     │
│               Device.dll · Platform.dll · HIDService.dll         │
│               IntelOverclockingSDK / IntelXTUOverclockingService │
│               AmdRyzenOverclockingService · ProfileHelperModel   │
└───────────────┬──────────────────────────────────────────────────┘
                │ IOCTL / DeviceIoControl
┌───────────────▼──────────────────────────────────────────────────┐
│ Kernel        hpomencustomcapdriver.sys (KMDF, group "Base")      │
│               + HpReadHWData (service berjalan)                   │
└───────────────┬──────────────────────────────────────────────────┘
                │ SMM / EC
┌───────────────▼──────────────────────────────────────────────────┐
│ Firmware      BIOS WMI (hpqBIntM / hpqBDataIn) — TIDAK tersedia   │
│               EC + BIOS thermal policy (yang benar-benar dipakai) │
└──────────────────────────────────────────────────────────────────┘
```

Bukti string penting:

* `OmenCap.exe`: `HP Omen HSA Service`, `HPOmenRpcEndpoint`,
  `HPInc.hpOmen_v10z8vjag6ke6`, `Hp::Bridge::Server::HSAService`.
* `OmenCommandCenterBackground.exe`: `OmenHsaClient`, `HPOmenServices`,
  `HPOMENBG_.log`, `HP.Omen.Core.Common.WMI`, `FanSpeedTrace`,
  `FanSpeedEventSource`.
* `hpomencustomcapdriver.sys`: PDB path internal HP
  `C:\projects\Glide_GitHub\ISEN\HSA\win-drv-hpomencustomcapdriver_temp\x64\Release\...`
  → proyek internal bernama **HSA** ("HP System Agent").
* `LightStudio-background.exe`: PDB `...\Project-Aurora\Aurora-test-background\...`,
  tipe `Aurora.Settings.ApplicationSettings`, `Omen.OmenFourZoneLighting`.

---

## 3. Dua jalur perintah, dan yang mana yang hidup

### a. Jalur WMI BIOS langsung — mati di unit ini

Kelas WMI-nya ada, instance-nya tidak:

* `root\WMI`: `hpqBIntM`, `hpqBDataIn`, `hpqBDataOut*`, `HPBIOS_BIOSEvent`
* `root\HP\InstrumentedBIOS`: `HP_BIOSSetting`, `HP_BIOSSettingInterface`,
  `HP_BIOSInteger`, `HP_BIOSEnumeration`, sensor

Hasil enumerasi di BIOS F.19:

| Query | Hasil |
| --- | --- |
| `root\WMI: hpqBIntM` | `0x80041003` (tidak didukung) |
| `root\WMI: hpqBDataIn` | `0x8004100C` (kelas tidak valid) |
| `root\HP\InstrumentedBIOS: HP_BIOS*` | kelas ada, **0 instance** |

Artinya: setting BIOS lewat WMI (cara yang dipakai tool HP lama dan beberapa
proyek Linux) **tidak bisa** dipakai di 15-dc0xxx dengan BIOS F.19.

### b. Jalur driver — ini yang dipakai

Aplikasi tidak menyerah; ia memanggil `ExecuteBiosWmiCommandThruDriver` yang
menembak `hpomencustomcapdriver` → `HpReadHWData` → SMM/EC. Log
`HPOMENBG_*.log` menunjukkan pola ini berulang:

```
[ExecuteBiosWmiCommandThruDriver] inputData is null
[ExecuteBiosWmiCommandThruDriver] inputData=0,0,0,0,
[ExecuteBiosWmiCommandThruDriver] ret.returnCode = 3
SystemDesignData.Get(), from BIOS 00-00-...-00
```

dan untuk fan:

```
SetFanModeAsync(), mode = Default
[ExecuteBiosWmiCommandThruDriver] inputData=255,0,0,0,
```

Kesimpulan: perintah fan/termal berbentuk **blok byte** yang diteruskan driver
ke BIOS/EC. Blok itu tidak didokumentasikan HP, dan `returnCode = 3` pada
pembacaan design data menunjukkan sebagian perintah memang ditolak firmware.

---

## 4. Kemampuan yang dilaporkan aplikasi sendiri (board 84DA)

Diambil dari `HPOMENBG_20261029.log`, saat background app start:

```
DeviceLib: Platform = Gamora10
DeviceLib: DisplayName = OMEN 15 LAPTOP
SupportModeList(): ThisSystemID=84DA
IsSwFanControlSupport = False
IsBiosPerformanceControlSupport = False
IsBiosPerformanceModeSupport = False
IsAutoPerformanceModeSupport = False
IsBiosCoolModeSupported = True
IsExtremeModeSupport = False
IsPowerControlSupported = False
IsTppSupport = False
GetThermalPolicyVersion = V0
SupportModeList: mode=Eco
SupportModeList: mode=Default
SupportModeList: mode=Cool
```

Plus pembatasan lain:

| Flag | Nilai | Arti praktis |
| --- | --- | --- |
| `IsPowerLimit1/2/4Support` | False | PL1/PL2 tidak bisa diatur aplikasi |
| `IsDynamicPowerLimitSupport` | False | tanpa dynamic TDP |
| `IsIccMaxSupport`, `IsSurfaceTempSupport` | False | tanpa tuning arus/suhu permukaan |
| `IsUnleashedModeSupport`, `IsExtremeModeSupport` | False | tanpa mode "unleashed/extreme" |
| `IsHotkeySupport` (`Fn+P`, `Fn+F1`) | False | tidak ada hotkey performa |
| `IsWin11PowerModeSyncSupport` | False | tidak sinkron dengan slider Windows |
| `HasGraphicsSwitcher` | False | tanpa MUX/switch GPU |
| `IsBiosDefinedOcSupport`, `IsSystemSupportedPBO` | False | tanpa OC dari BIOS |

Jadi **satu-satunya tuas termal yang diakui firmware adalah profil `Cool`**.
`Eco` dan `Default` adalah kebijakan daya, bukan kontrol kipas. Kipas sendiri
dikendalikan EC dengan kurva tertutup; tidak ada PWM yang bisa ditulis software
(`IsSwFanControlSupport = False`).

Nilai yang tersimpan di profil (registry/FileStorage
`OmenProfile\<user>\<profile>\PerformanceControl`):

```
Mode           = 256      (Eco)
MaxFan         = 0        (Off)  → fitur ini pun tidak aktif di board ini
ThermalControl = 1        (Auto)
FanSpeed       = 50       (% default; hanya dipakai platform yang mendukung)
```

Folder log per-fitur juga membuktikan hal yang sama: `FanSpeed_*.log` dan
`Pl1Clip_*.log` isinya hanya `log Start` (fitur tidak pernah menulis), sedangkan
`HPOMENBG_*.log` penuh aktivitas umum.

---

## 5. Keyboard dan lampu

```
GetKeyboardTypeAsync(): keyboardType = 0
BiosWmiCmd_IsLightingSupported(): isSupported = 1
WindowsLightingHelper device: Cloud/Fox/Link/Samus/MegaDrive/FourZone
    -> "device not attached"
IsSupportLCD result: False
```

Modul `HP.Omen.Background.FourZone.dll` memakai perintah BIOS WMI untuk warna:

```
BiosWmiCmd_GetColor / BiosWmiCmd_SetColor
BiosWmiCmd_GetBrightness / BiosWmiCmd_SetBrightness
```

bukan HID per-tombol. Satu-satunya perangkat HID HP yang ada di unit ini adalah
`HID\HPQ6001` (tombol radio nirkabel), jadi tidak ada antarmuka HID untuk RGB.

Kesimpulan untuk SKU `4NT40PA#AR6`: keyboard hanya **backlight putih satu warna**
yang dikendalikan EC/Fn — tidak ada 4 zona, tidak ada per-key RGB, dan tidak ada
node LED/HID yang bisa ditulis dari Linux.

---

## 6. Sensor dan telemetri

`HP.Omen.Features.Hardware.PerformanceMonitorBg.dll` mengekspos nama-nama ini:

```
DtGetFanLevel        set_FanSpeed        set_FanSpeedList
get_IntakeFanSpeed   get_ExhaustFanSpeed
get_CpuFanSpeed      get_GpuFanSpeed
get_CleanCreekCpuFanSpeed / get_CleanCreekGpuFanSpeed
FanSpeedEventSource  FanSpeedTrace       SetFanDutyCycle
```

Artinya RPM kipas dibaca dari EC lewat driver yang sama, lalu dipublikasikan
sebagai event WMI ke UI/overlay. Tidak ada hwmon/PWM di sisi Windows.

---

## 7. Jalur Linux yang nyata (bukan tebakan)

Kernel mengenali WMI dari `_WDG`; dari 14 entri di `\_SB.N00E.WMID`
(DSDT `0x41A09`, buffer 280 byte) hanya beberapa yang punya driver:

| GUID | obj | Driver Linux | Yang didapat |
| --- | --- | --- | --- |
| `5FB7F034-2C63-45E9-BE91-3D44E2C707E4` | `AA` | `hp-wmi` (`HPWMI_BIOS_GUID`) | perintah BIOS (rfkill, postcode, …); jalur profil termal 84DA **gagal** |
| `95F24279-4D7B-4334-9387-ACCDC67EF61C` | – | `hp-wmi` (event) | event hotkey, bukan kontrol |
| `8F1F6435-9F42-42C8-BADC-0E9424F20C9A` | `BI` | `hp-wmi-sensors` | hwmon `hp_wmi_sensors`: `fan*_input`, `temp*_input` |
| `8F1F6436-9F42-42C8-BADC-0E9424F20C9A` | `BH` | `hp-wmi-sensors` (event) | peringatan sensor (stall/overtemp) |
| `05901221-D566-11D1-B2F0-00A0C9062910` | `AB` | `wmi-bmof` / mapper MS | hanya mapping objek, bukan kontrol |
| `1F4C91EB-…`, `2D114B49-…`, `988D08E3-…`, `14EA9746-…`, `322F2028-…`, `8232DE3D-…`, `7391A661-…`, `DF4E63B6-…` | `BA`…`BJ` | tidak ada driver kernel | sisa HP (lighting/diagnostik); tidak bisa dipakai |

### 7.1 RPM dan suhu: `hp-wmi-sensors`

`drivers/hwmon/hp-wmi-sensors.c` hanya butuh `wmi_query_block()` ke GUID
`8F1F6435…`, jadi **tidak** tergantung jalur BIOS yang rusak. Kalau instance
itu berisi deskriptor kipas/suhu, kernel membuat:

```
/sys/class/hwmon/hwmonN/name = hp_wmi_sensors
fan1_input, temp1_input, ...
```

Cek: `sensors` dan `grep . /sys/class/hwmon/*/name`. `omen-control` sudah
membaca `fan*_input` dari hwmon mana pun, jadi RPM akan muncul di `status`
tanpa perubahan kode kalau driver ini aktif.

### 7.2 `platform_profile` **tidak** muncul di board ini

`hp-wmi` memang mendaftarkan `84DA` di `omen_thermal_profile_boards`, dan
`platform_profile_omen_get_ec()` hanya membaca EC offset `0x95` (`ec_read`).
Tetapi `thermal_profile_setup()` memanggil `platform_profile_omen_set_ec()` →
`omen_get_thermal_policy_version()` → WMI cmdtype `0x28`
(`HPWMI_GET_SYSTEM_DESIGN_DATA`). Di BIOS F.19 query itu mengembalikan
`returnCode=3` (`HPWMI_RET_UNKNOWN_COMMAND`) — sama dengan log OMEN Command
Center `SystemDesignData returnCode=3`. Fungsi mengembalikan error, probe
gagal, dan `/sys/firmware/acpi/platform_profile` tidak dibuat. Board `84DA`
juga tidak ada di `omen_thermal_profile_force_v0_boards`, jadi tidak ada
shortcut. Ini **bukan** bug OmenOS dan tidak bisa diperbaiki dengan memuat
ulang modul.

### 7.3 Satu-satunya tuas: RAM EC `0x95`

Driver hp-wmi membaca profil dari EC (`HP_OMEN_EC_THERMAL_PROFILE_OFFSET 0x95`),
nilai V0: `0x00` balanced, `0x01` performance, `0x02` cool. Menulis lewat
driver memakai WMI `0x1A` (`SET_PERFORMANCE_MODE`), tetapi karena jalur desain
di atas gagal, driver tidak pernah mendaftarkan antarmuka tulis.

Dari userspace byte itu bisa dibaca/ditulis lewat `ec_sys`:

```bash
sudo modprobe ec_sys                      # baca saja
od -An -tx1 -j 149 -N1 /sys/kernel/debug/ec/ec0/io

sudo modprobe -r ec_sys
sudo modprobe ec_sys write_support=1      # izinkan tulis
sudo omen-control fan cool                # 0x95 = 0x02, diverifikasi baca ulang
```

Aturan aman yang dipakai OmenOS:

- hanya **satu byte** (`0x95`); flag `0x62` dan timer `0x63` tidak disentuh
  (itu untuk board ber-timer seperti `8A15`, bukan 84DA);
- hanya **eksplisit** dari CLI; daemon fan tidak pernah menulis EC;
- setiap tulis dibaca ulang setelah 0,4 s; kalau EC menolak, nilai lama
  dikembalikan dan perintah gagal (bukan "sukses" palsu);
- `fan max` di board ini **bukan** 100% PWM — artinya profil Cool, karena
  firmware tidak menyediakan mode kipas penuh;
- `performance` sengaja ditolak: firmware melaporkan
  `IsBiosPerformanceControlSupport=False`.

Risiko yang jujur: menulis EC di luar driver bisa bentrok dengan EC sendiri,
dan sebagian unit mengunci byte ini (tulis "berhasil" tetapi langsung kembali).
Karena itu hasilnya selalu diverifikasi. Kalau ditolak, yang tersisa hanya
jalur termal/power normal.

### 7.4 Yang tidak ada di Linux (dan tidak dibuat-buat)

1. **PWM / persen kipas.** `IsSwFanControlSupport=False`; tidak ada `pwm1`.
2. **RGB 4 zona / per-key.** `keyboardType=0`; tidak ada GUID lighting yang
   punya driver dan tidak ada HID RGB. Backlight putih tetap jalan lewat Fn/EC.
3. **Fan boost / performance dari HP.** Hanya mode Cool.

### 7.5 Perintah uji saat boot live

```bash
sudo omen-probe > ~/omen-probe.txt
omen-control status
cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || echo "tidak ada (normal)"
sensors 2>/dev/null | head -40
ls /sys/bus/wmi/devices
sudo modprobe ec_sys
od -An -tx1 -j 149 -N1 /sys/kernel/debug/ec/ec0/io
dmesg | grep -iE 'hp_wmi|hp-wmi|ec_sys|ACPI Error'
```

Yang dicari: apakah `hp_wmi_sensors` memberi RPM, nilai `0x95` saat idle
(`0x00` atau `0x02`), dan apakah `sudo omen-control fan cool` lolos verifikasi.
Hasil itu yang menentukan apakah modul `ec_sys` perlu dimuat otomatis saat
boot (hanya untuk baca) atau tetap manual.

---

## 8. Cara mereproduksi (Windows, tanpa admin)

```powershell
# paket & layanan
Get-AppxPackage | ? Name -match 'OMEN|HPSystemEvent' | % { "$($_.Name) $($_.Version)" }
Get-CimInstance Win32_Service | ? Name -match 'OmenCap|HPAppHelperCap' |
  % { "$($_.Name) $($_.State) $($_.PathName)" }

# driver
Get-CimInstance Win32_SystemDriver | ? Name -match 'omen|HpReadHWData' |
  % { "$($_.Name) $($_.State) $($_.PathName)" }

# jalur WMI BIOS (harus kosong di unit ini)
Get-CimInstance -Namespace root\WMI -ClassName hpqBIntM
Get-CimInstance -Namespace root\HP\InstrumentedBIOS -ClassName HP_BIOSSetting

# log: capability + perintah
$log = "$env:LOCALAPPDATA\Packages\AD2F1837.OMENCommandCenter_v10z8vjag6ke6\LocalCache\Local\HPOMEN\HPOMENBG_$(Get-Date -f yyyyMMdd).log"
Select-String -Path $log -Pattern 'SupportModeList|IsSwFanControlSupport|ExecuteBiosWmiCommandThruDriver|keyboardType'
```

Ekstraksi string biner (dipakai untuk bagian 2 dan 5):

```powershell
$b = [IO.File]::ReadAllBytes($exe)
[regex]::Matches([Text.Encoding]::ASCII.GetString($b), '[\x20-\x7E]{5,200}') |
  % { $_.Value.Trim() } | Select-Object -Unique
```

Log aplikasi berisi nama pengguna/SID dan ID perangkat; **jangan** menyalin isi
log mentah ke repo — ambil hanya baris kapabilitas seperti di atas.

---

## 9. Ringkasan satu paragraf

OMEN Command Center di 15-dc0xxx adalah klien UWP → RPC `HPOmenRpcEndpoint` →
`OmenCap.exe` (HP Omen HSA Service) → `hpomencustomcapdriver.sys`/`HpReadHWData`
→ SMM/EC. Jalur WMI BIOS lama tidak tersedia di BIOS F.19. Firmware melaporkan
bahwa board **Gamora10/84DA** tidak mendukung kontrol kipas software, tidak
mendukung performance mode BIOS, dan hanya mendukung mode **Cool**; lampu
keyboard bukan 4-zona. Di Linux, RPM/suhu bisa datang dari `hp-wmi-sensors`,
`platform_profile` tidak akan terdaftar (query desain `0x28` gagal), dan
satu-satunya tuas firmware adalah byte EC `0x95` — OmenOS membacanya di
`status` dan menulisnya hanya lewat perintah eksplisit `fan cool`. Tidak ada
PWM manual dan tidak ada RGB yang bisa dijanjikan di mesin ini.
