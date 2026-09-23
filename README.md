# rom-kitchen

Tự build ROM custom **không root** cho Xiaomi **Mi 11 Lite 5G NE (`lisa`)** từ ROM gốc China + APK mod.

## Tài liệu

- [docs/BUILD_LOG.md](docs/BUILD_LOG.md) — log đầy đủ lần build 2026-09-23 (pipeline, tool, sự cố, patch list)
- [docs/PIPELINE.md](docs/PIPELINE.md) — thiết kế Git/script tự build

## Build nhanh (hiện tại)

Đã có gói flash tại:

```
D:\LISA\build\output\LISA_HyperOS2.0.16.0_CN_Mods\
  flash_format_data.bat   ← chạy file này
```

## Tự build (khi hoàn thiện script)

```powershell
.\rom-kitchen.ps1 build -RomUrl "<link OTA china lisa>" -ApkDir "D:\LISA\APk"
```

## Device

| | |
|---|---|
| Codename | `lisa` |
| Base ROM | HyperOS OS2.0.16.0.UKOCNXM (Android 14, China) |
| Super | 8.5 GiB, virtual A/B, 3 metadata slots |
| Features | Bypass chữ ký · Kaorios Toolbox · 9 APK mod |
