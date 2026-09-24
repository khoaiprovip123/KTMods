# CHANGELOG

## 1.0.0 — 2026-09-23

### ROM (lisa HyperOS 2.0.16.0.UKOCNXM)
- Bypass chữ ký app (framework + services)
- Kaorios Toolbox không root
- Disable Secure Flag + CN Notification Fix
- 16 APK mod (Launcher, Security, Joyose, Gallery, Camera HolyBear, AppVault, Theme…)
- Debloat 35 app rác
- Tiếng Việt (values-vi → Settings + framework-res)

### rom-kitchen
- `build <url>` 1 lệnh: tải OTA → unpack → mod → pack super 8.5GB → 7z
- `verify.ps1` check package sau build
- GitHub Actions tự build (windows-latest)
- Git LFS cho APK/tool
- Portable: không hardcode `D:\LISA` (CI chạy được)

### Tiếng Việt (nguồn xiaomi.eu)
- Settings + framework-res: values-vi
- MiuiHome + MIUISecurityCenter: values-vi (merge OK)
- MiuiGallery / FileExplorer: aapt2 fail (giữ APK gốc)
- Camera / Theme / SystemUI: không có hoặc chưa merge

Repo: https://github.com/khoaiprovip123/KTMods
