# BUILD LOG — ROM Custom Xiaomi Mi 11 Lite 5G NE (`lisa`)

> Log đầy đủ quá trình build ROM **không root** từ ROM gốc China, dùng làm tài liệu gốc để tự động hoá (Git CI / script build).
>
> Ngày: 2026-09-23  
> Nền: HyperOS **OS2.0.16.0.UKOCNXM** Android 14 (OTA official China)  
> Thiết bị: Xiaomi Mi 11 Lite 5G NE — codename **`lisa`** — Snapdragon 778G

---

## 1. Mục tiêu

| # | Yêu cầu | Kết quả |
|---|---|---|
| 1 | Nền **ROM gốc China** mới nhất, không dùng ROM custom khác | ✅ `lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0` |
| 2 | **Bypass chữ ký** — cài app khác chữ ký / APK mod | ✅ Patch `framework.jar` + `services.jar` |
| 3 | **Kaorios Toolbox** (Play Integrity / spoof) — **không root** | ✅ Hook framework + `KaoriosToolbox.apk` priv-app |
| 4 | Thay APK hệ thống từ `D:\LISA\APk` (Launcher, Security, Game Turbo…) | ✅ 9 APK |
| 5 | Máy hoạt động bình thường sau flash | ✅ super layout khớp stock 8.5GB virtual A/B |
| 6 | Nâng cấp APK mới khác chữ ký sau này không cần build lại ROM | ✅ Bypass đủ → `adb install -r` |

---

## 2. Kết quả cuối

```
D:\LISA\build\output\LISA_HyperOS2.0.16.0_CN_Mods\
├── images\
│   ├── super.img          8.5 GB  (system/product/system_ext/vendor/odm/mi_ext)
│   ├── boot.img           192 MB
│   ├── vendor_boot.img    96 MB
│   ├── vbmeta.img         8 KB
│   ├── vbmeta_system.img  4 KB
│   ├── modem.img          198 MB
│   └── … (abl, aop, xbl, tz, dsp, dtbo, …)
├── bin\                   fastboot.exe
├── flash_format_data.bat  ← FLASH LẦN ĐẦU
├── flash_keep_data.bat    ← giữ data (cùng bản 2.0.16.0)
├── framework_final.jar    bản framework đã patch (backup)
└── README.md
```

---

## 3. Công cụ đã dùng

| Tool | Phiên bản / nguồn | Vai trò |
|---|---|---|
| payload-dumper-go | 2.0.2 (ssut) | Giải nén `payload.bin` → partition images |
| extract.erofs / mkfs.erofs | 1.8.10 (littlecoca/erofs_tool_win) | Đóng/mở EROFS (HyperOS dùng EROFS) |
| lpunpack / lpmake / lpdumps | AOSP 15 r25 (Rprop/aosp15_partition_tools) | Đóng/mở `super.img` |
| apktool | FrameworkPatcher bundled | Decompile/recompile `framework.jar`, `services.jar` |
| FrameworkPatcher | FrameworksForge master | Patch chữ ký + inject Kaorios |
| Kaorios Toolbox | V2.0.4 (Wuang26) | App + class smali + permission XML |
| Git Bash | MSYS2 | Chạy bash patch script trên Windows |
| Java | OpenJDK 21 | apktool |
| Python | MIMO_PYTHON 3.14 | Script phụ (strip fs_config, fix smali) |

Workspace build: `D:\LISA\build\`  
ROM nguồn: `D:\LISA\lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip`

---

## 4. Pipeline đầy đủ (tái hiện được)

### B0 — Chuẩn bị workspace

```
D:\LISA\build\
├── tools\          payload-dumper-go, erofs, lp*, apktool, kaorios
├── rom_extract\    payload.bin + images\ (28 partition)
├── work\           system\, product\, system_ext\ (đã unpack EROFS)
└── output\         system.img, product.img, super.img, package flash
```

### B1 — Giải nén ROM gốc

```powershell
# 1. Lấy payload.bin từ OTA zip
python -c "zipfile extract payload.bin"

# 2. Dump partitions
payload-dumper-go.exe -o rom_extract\images rom_extract\payload.bin
```

**Partition trong payload (28):**  
`abl aop bluetooth boot cpucp devcfg dsp dtbo featenabler hyp imagefv keymaster modem odm product qupfw shrm system system_ext tz uefisecapp vbmeta vbmeta_system vendor vendor_boot xbl xbl_config mi_ext`

**Định dạng:** `system/product/system_ext/vendor/odm/mi_ext` = **EROFS** (magic `0xE0F5E1E2` @ offset 1024).  
`boot` = `ANDROID!`, `vbmeta` = `AVB0`.

### B2 — Unpack EROFS

```powershell
extract.erofs.exe -i system.img   -o work\system     -x
extract.erofs.exe -i product.img  -o work\product    -x
extract.erofs.exe -i system_ext.img -o work\system_ext -x
```

**Layout quan trọng:**
```
work\product\product\priv-app\MiuiHome\MiuiHome.apk   ← content = image root
work\product\config\product_fs_config                  ← path prefix "product/"
```

> `fs_config` có prefix `product/`, `system/`, `system_ext/`. Khi `mkfs.erofs` phải **strip prefix** hoặc set source đúng.

### B3 — Thay APK mod (9 app)

Map từ `D:\LISA\APk` → ROM:

| APK mod | Target trong ROM | Ghi chú |
|---|---|---|
| `MiuiHome.apk` | `product/priv-app/MiuiHome/MiuiHome.apk` | Launcher |
| `SecurityMod_v13.5.3_PeaceModss.apk` | `product/priv-app/MIUISecurityCenter/MIUISecurityCenter.apk` | Bảo mật |
| `JoyoseMod_v2.5.20_PeaceModss.apk` | `product/pangu/system/app/Joyose/Joyose.apk` | Game Turbo |
| `[LLions] HyperOS File Manager Mod` | `product/app/MIUIFileExplorer/MIUIFileExplorer.apk` | |
| `[LLions] HyperOS Gallery Mod` | `product/priv-app/MIUIGallery/MIUIGallery.apk` | |
| `[LLions] HyperOS Gallery Editor Mod` | `product/data-app/MIMediaEditor/MIMediaEditor.apk` | |
| `[LLions] HyperOS Recorder Mod` | `product/data-app/MIUISoundRecorderTargetSdk30/` | |
| `[LLions] HyperOS AI Engine Mod` | `product/app/AiasstVision/AiasstVision.apk` | |
| `[LLions] HyperOS Bokeh Mod` | `product/priv-app/MiuiExtraPhoto/MiuiExtraPhoto.apk` | ⚠️ map suy đoán |

**Sau khi thay:** xoá `oat/` cạnh APK (odex/vdex cũ không khớp APK mới).

> **PowerShell:** tên file `[LLions] …` bị hiểu là wildcard → phải dùng `-LiteralPath`.

### B4 — Patch chữ ký + Kaorios (không root)

```bash
# Git Bash
cd FrameworkPatcher
cp <work>/framework.jar services.jar miui-services.jar .
./scripts/patcher_a14.sh 34 lisa OS2.0.16.0 \
  --framework --services --miui-services \
  --disable-signature-verification \
  --kaorios-toolbox
```

#### Patch chữ ký — danh sách method

**`framework.jar`:**
| Method | Patch | Trạng thái ban đầu |
|---|---|---|
| `ApkSignatureVerifier.getMinimumSignatureSchemeVersionForTargetSdk` | return `0x0` | ✅ tool patch được |
| `StrictJarVerifier.verifyMessageDigest` | return `0x1` | ❌ sót → **vá tay** |
| `PackageParser$SigningDetails.checkCapability` (2 overload) | return `0x1` | ❌ sót (method **instance**) → **vá tay** |
| `PackageParser$SigningDetails.checkCapabilityRecover` | return `0x1` | ❌ sót → **vá tay** |
| `ApplicationInfo.isPackageWhitelistedForHiddenApis` | return `0x1` | ✅ |
| `StrictJarFile.findEntry` | bỏ `if-eqz` check | ✅ |
| `verifyV1/V2/V3Signature`, `verifyV3AndBelowSignatures` | set `const/4 p3, 0x0` | ✅ (call-site) |

**`services.jar`:**
| Method | Patch | Trạng thái |
|---|---|---|
| `PackageManagerServiceUtils.checkDowngrade` | `return-void` | ✅ |
| `PackageManagerServiceUtils.verifySignatures` | return `0x0` | ✅ |
| `PackageManagerServiceUtils.matchSignaturesCompat` | return `0x1` | ✅ |
| `KeySetManagerService.shouldCheckUpgradeKeySetLocked` | return `0x0` | ✅ |

> **Lý do sót:** `add_static_return_patch` chỉ match method `static`. `checkCapability` là instance method → không match.

#### Kaorios Toolbox V2.0.4

- Inject **361** smali class → `framework/smali_classes5/com/android/internal/util/kaorios/`
- Hook 4 method:
  - `ApplicationPackageManager.hasSystemFeature`
  - `Instrumentation.newApplication` (2 overload)
  - `KeyStore2.getKeyEntry`
  - `AndroidKeyStoreSpi.engineGetCertificateChain`
- App: `product/priv-app/KaoriosToolbox/KaoriosToolbox.apk` + native libs
- Permission: `product/etc/permissions/com.kousei.kaorios.xml`
- Whitelist: `privapp_whitelist_com.kousei.kaorios.xml`
- Props trong `system/build.prop`:
  ```
  persist.sys.kaorios=kousei
  ro.control_privapp_permissions=
  ```

### B5 — Đóng gói EROFS

```powershell
# Strip prefix product/ system/ system_ext/ trong fs_config + file_contexts
# → *.stripped

mkfs.erofs -z lz4hc,level=9 --all-root \
  --fs-config-file=config/product_fs_config.stripped \
  --file-contexts=config/product_file_contexts.stripped \
  -T0 --mkfs-time product.img product
```

Lặp lại cho `system.img`, `system_ext.img`.

**Lưu ý layout:**
- `system.img` là **system-as-root** (chứa `init`, `system/`, `apex/`…)
- `product.img` / `system_ext.img` root = `app/`, `priv-app/`, `etc/`…

### B6 — Đóng `super.img` ⚠️ PHẢI KHỚP STOCK

Lần build đầu **SAI** → đã fix:

| Thông số | Sai (lần 1) | Đúng (khớp ZKOS/stock) |
|---|---|---|
| Size | 8 GiB | **8.5 GiB = 9.126.805.504 bytes** |
| Metadata version | 10.0 | **10.2** |
| Metadata slots | 2 | **3** |
| Header flags | (none) | **`virtual_ab_device`** |
| Block device name | `super_a` | **`super`** |
| Partitions | chỉ `_a` | **`_a` + `_b`** (`_b` size 0) |
| Groups | 1 group | **`qti_dynamic_partitions_a` + `_b`** |

```powershell
lpmake --metadata-size 65536 --metadata-slots 3 --virtual-ab `
  --device-size 9126805504 --super-name super `
  --group=qti_dynamic_partitions_a:9126805504 `
  --group=qti_dynamic_partitions_b:9126805504 `
  --partition=system_a:readonly:SIZE_A:qti_dynamic_partitions_a --image=system_a=system.img `
  --partition=system_b:readonly:0:qti_dynamic_partitions_b `
  --partition=product_a:readonly:SIZE_A:qti_dynamic_partitions_a --image=product_a=product.img `
  --partition=product_b:readonly:0:qti_dynamic_partitions_b `
  … (system_ext, vendor, odm, mi_ext) …
  --output=super.img
```

**Sizes dùng để pad (file size + 16MB):**
```
system      720371712
system_ext  591396864
product     4322230272
vendor      1553989632
odm         34603008
mi_ext      17825792
```

> `lpmake` báo `Invalid sparse file format` khi đọc EROFS raw — **bỏ qua**, vẫn ghi data OK (exit 0).

### B7 — Gói flash

Copy firmware stock + `super.img` + fastboot + script:

```
flash_format_data.bat   # format userdata + metadata, flash all, vbmeta --disable-verity
flash_keep_data.bat     # giữ data
```

**vbmeta phải flash kèm cờ:**
```
fastboot --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img
fastboot --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img
```

---

## 5. Sự cố đã gặp & cách fix

| # | Sự cố | Nguyên nhân | Fix |
|---|---|---|---|
| 1 | `curl -L` fail trên PowerShell | PowerShell alias `curl` → `Invoke-WebRequest` | Dùng `curl.exe` |
| 2 | PowerShell nuốt `[LLions]` | `[...]` là wildcard | `-LiteralPath` |
| 3 | WSL không boot | VHD `F:\WslClaw\ext4.vhdx` mất | Dùng EROFS tools Windows (cygwin) |
| 4 | `mkfs.erofs` fail `failed to find acct` | fs_config path prefix `system/` không khớp source | Tạo `*.stripped` (bỏ prefix) |
| 5 | `checkCapability` không bị patch | `add_static_return_patch` chỉ match `static` | Patch tay method instance |
| 6 | apktool `missing EOF at .end method` | Force-return làm thừa `.end method` | Gộp `.end method` trùng |
| 7 | `checkCapabilityRecover` annotation vỡ | Cắt method giữa chừng `.annotation` | Viết lại method sạch |
| 8 | `super.img` 8GB bootloop risk | Sai size + thiếu virtual A/B + thiếu `_b` | Build lại 8.5GB đúng layout ZKOS |
| 9 | `lpmake` `Partition must have a valid size` | `_b` cấp size bằng `_a` → hết chỗ | `_b` size **0** |
| 10 | `lpmake` thiếu `--device-size` | Bắt buộc với super image | Thêm `--device-size 9126805504` |

---

## 6. Checklist verify trước khi flash

- [x] `framework.jar` chứa `kaorios` (3 dex) + `getMinimumSignatureSchemeVersionForTargetSdk`
- [x] `services.jar` có `verifySignatures`/`matchSignaturesCompat`/`checkDowngrade` patched
- [x] `checkCapability` / `checkCapabilityRecover` return `0x1`
- [x] 9 APK mod đã thay đúng vị trí, `oat/` đã xoá
- [x] `KaoriosToolbox.apk` + permission XML trong product
- [x] `super.img` = **9126805504** bytes, metadata 10.2, 3 slots, `virtual_ab_device`, partitions `_a`+`_b`
- [x] Script flash có `--disable-verity --disable-verification` cho vbmeta
- [ ] Backup EFS/NVRAM / userdata trước khi flash
- [ ] Không flash ARB thấp hơn ROM đang chạy

---

## 7. Nâng cấp APK sau khi đã flash ROM

Vì đã bypass chữ ký:

```bash
adb install -r -d apk_moi.apk
```

- Cùng **package name** → ghi đè lên app system (bản update trong `/data/app`)
- Chữ ký khác → **vẫn được**
- Muốn nhúng vào system partition → thay file trong `work\product\...` rồi build lại `product.img` + `super.img` + flash

---

## 8. Kiến trúc Git tự build (thiết kế cho tương lai)

Xem [`PIPELINE.md`](PIPELINE.md).

---

## 9. Path reference nhanh

| Item | Path |
|---|---|
| ROM gốc OTA | `D:\LISA\lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip` |
| APK mod nguồn | `D:\LISA\APk\` |
| Workspace build | `D:\LISA\build\` |
| Gói flash | `D:\LISA\build\output\LISA_HyperOS2.0.16.0_CN_Mods\` |
| framework đã patch | `D:\LISA\build\output\framework_final.jar` |
| Kitchen / git skeleton | `D:\LISA\rom-kitchen\` |
