import os, shutil, subprocess, sys
from pathlib import Path
import re

apktool = sys.argv[1]
work = Path(sys.argv[2])
lang_eu = Path(sys.argv[3])   # lang_eu/<tag>/res/values-vi
java = 'java'

# map: EU tag -> China APK path (relative to work)
MAP = [
    ('MiuiHome', 'product/product/priv-app/MiuiHome/MiuiHome.apk'),
    ('SecurityCenter', 'product/product/priv-app/MIUISecurityCenter/MIUISecurityCenter.apk'),
    ('MiuiGallery', 'product/product/priv-app/MIUIGallery/MIUIGallery.apk'),
    ('FileExplorer', 'product/product/app/MIUIFileExplorer/MIUIFileExplorer.apk'),
    ('ThemeManager', 'product/product/app/MIUIThemeManager/MIUIThemeManager.apk'),
    ('MIUIPackageInstaller', 'product/product/priv-app/MIUIPackageInstaller/MIUIPackageInstaller.apk'),
    ('MiuiSystemUI', 'system_ext/system_ext/priv-app/MiuiSystemUI/MiuiSystemUI.apk'),
]

for tag, rel in MAP:
    apk = work / rel
    vi = lang_eu / tag / 'res' / 'values-vi'
    if not apk.exists():
        print('skip', tag, 'target missing'); continue
    if not vi.exists():
        print('skip', tag, 'values-vi missing'); continue
    out = work / f'vi_{tag}'
    if out.exists():
        shutil.rmtree(out, ignore_errors=True)
    print('decode', tag, '...')
    subprocess.check_call([java, '-jar', apktool, 'd', '-q', '-f', '-s', '-o', str(out), str(apk)])
    res = out / 'res'
    dst = res / 'values-vi'
    if dst.exists():
        shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(vi, dst)
    print(tag, 'copied values-vi', len(list(dst.iterdir())), 'files')
    # also values-vi-rVN if present in EU
    vi2 = lang_eu / tag / 'res' / 'values-vi-rVN'
    if vi2.exists():
        dst2 = res / 'values-vi-rVN'
        if dst2.exists(): shutil.rmtree(dst2, ignore_errors=True)
        shutil.copytree(vi2, dst2)
        print(tag, 'copied values-vi-rVN')
    # drop invalid mcc/config folders that break aapt2
    for d in list(res.iterdir()):
        if not d.is_dir():
            continue
        name = d.name
        if re.search(r'mcc(9460|9998|9999|[0-9]{4}-mnc(9000|9999))', name):
            shutil.rmtree(d, ignore_errors=True)
            print(tag, 'removed', name)
    rebuilt = work / f'{tag}_vi.apk'
    print('build', tag, '...')
    try:
        subprocess.check_call([java, '-jar', apktool, 'b', '-q', '-f', '-o', str(rebuilt), str(out)])
    except subprocess.CalledProcessError as e:
        print(tag, 'BUILD FAIL — skip (giữ APK gốc)', e)
        continue
    shutil.copy2(rebuilt, apk)
    # remove stale oat
    oat = apk.parent / 'oat'
    if oat.exists():
        shutil.rmtree(oat, ignore_errors=True)
    print(tag, 'OK', apk)

print('MERGE_VI_FROM_EU_DONE')
