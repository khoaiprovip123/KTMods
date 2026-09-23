# rom-kitchen — Trình dựng ROM Xiaomi lisa

Tự động: **tải ROM gốc → giải nén → mod APK + patch → đóng gói ROM hoàn chỉnh**.

Tham khảo: [nothingsvn_xiaomi-stocktoolbuild](https://github.com/khoaiprovip123/nothingsvn_xiaomi-stocktoolbuild)

## Chạy

```powershell
cd D:\LISA\rom-kitchen

# 1. Cài tool + copy APK/Kaorios/lang
.\setup.ps1

# 2. Build từ file OTA có sẵn
.\build.ps1 -OtaZip "D:\LISA\lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip"

# 3. Hoặc build từ link tải về
.\build.ps1 -RomUrl "https://example.com/lisa-ota_full-OS2.0.16.0.zip"
```

Kết quả trong `out\`: thư mục flash + file `.7z`.

## Tính năng đã auto

| | |
|---|---|
| Bypass chữ ký | cài app khác chữ ký |
| Kaorios Toolbox | Play Integrity / spoof (không root) |
| Disable Secure Flag | chụp màn app banking/DRM |
| CN Notification Fix | hết trễ thông báo |
| APK mod | theo `config/apk-map.txt` |
| Tiếng Việt | ghép `values-vi` (nếu có `assets/lang`) |

## Flash

1. Giải nén `out\*.7z`
2. Vào **fastboot**
3. Chạy `flash_format_data.bat`

## Thêm APK mod

1. Bỏ `.apk` vào `assets\apks\`
2. Thêm dòng vào `config\apk-map.txt`:

```
product|priv-app/TenApp/TenApp.apk|file_mod.apk|1
```

3. Chạy `.\build.ps1` lại

## APK trên driver (không push Git)

1. Đẩy APK lên Google Drive / OneDrive → link share
2. Dán link vào `config/apk-sources.txt`
3. Chạy `.\setup.ps1` → tự tải về `assets/apks`
4. `.\build <url-rom>`

APK nặng (50–200MB) nên để driver; Git chỉ chứa code + config.

## Git tu build (GitHub Actions)

1. Push repo len GitHub
2. **Actions -> Build ROM -> Run workflow** -> nhap om_url
3. Tai ROM .7z trong **Artifacts** (hoac **Release** khi tag)

CI chay tren windows-latest — dung dung uild.ps1.

### Toan bo tren Git (APK + tool)

```powershell
git lfs install
# sua .gitignore: bo comment assets/apks + tools neu muon all-in-git
git add .
git commit -m "full: rom-kitchen + APK LFS"
```

Mac dinh: APK/tai tu config/apk-sources.txt cho nhe repo.
