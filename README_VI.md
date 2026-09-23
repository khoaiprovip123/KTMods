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
