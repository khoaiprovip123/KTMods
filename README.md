# rom-kitchen — Xiaomi lisa ROM builder

Tự build ROM custom **không root** từ link/file ROM gốc + APK mod, đóng gói flashable.

Mô phỏng theo [nothingsvn_xiaomi-stocktoolbuild](https://github.com/khoaiprovip123/nothingsvn_xiaomi-stocktoolbuild) — bản Windows/PowerShell cho **Mi 11 Lite 5G NE (`lisa`)** trước.

## Cài nhanh

```powershell
cd D:\LISA\rom-kitchen
.\setup.ps1          # copy tool + APK + Kaorios + lang
.\build.ps1 -OtaZip "D:\LISA\lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip"
# hoặc
.\build.ps1 -RomUrl "https://.../lisa-ota_full-....zip"
```

## Pipeline

```
Download OTA → payload.bin → images/*.img
    → unpack EROFS (system/product/system_ext)
    → thay APK theo config/apk-map.txt
    → patch framework: chữ ký + Kaorios + Secure Flag + CN Notification
    → (tuỳ chọn) values-vi tiếng Việt
    → mkfs.erofs → lpmake super 8.5GB virtual A/B
    → pack flashable + 7z
```

## Config

Sửa `config.env`:

| Key | Ý nghĩa |
|---|---|
| `install_toolbox` | Kaorios (Play Integrity / spoof) |
| `install_mods` | thay APK từ `assets/apks` |
| `disable_signature` | cài app khác chữ ký |
| `disable_secure_flag` | chụp/ghi màn app banking |
| `cn_notification_fix` | hết trễ thông báo |
| `add_vietnamese` | ghép `values-vi` |

APK map: `config/apk-map.txt` — thêm dòng `partition|dst|src|1`

## Super layout (bắt buộc)

```
device_size=9126805504   # 8.5 GiB — KHÔNG đổi
metadata_slots=3
virtual_ab=1
```

Sai size/layout → flash fail / bootloop.

## Output

```
out/LISA_OS_MOD_1.0.0_YYYYMMDD/
  images/super.img + firmware
  bin/fastboot.exe
  flash_format_data.bat
  flash_keep_data.bat
out/LISA_OS_MOD_1.0.0_YYYYMMDD.7z
```

## Docs

- [docs/BUILD_LOG.md](docs/BUILD_LOG.md) — log build 2026-09-23
- [docs/PIPELINE.md](docs/PIPELINE.md) — thiết kế CI / multi-device

## Git sau này

```
git init && git add . && git commit -m "rom-kitchen lisa"
```

Cấu trúc `build.sh` / `.github/workflows` (Linux CI) có thể port từ repo NothingsVN khi cần.
