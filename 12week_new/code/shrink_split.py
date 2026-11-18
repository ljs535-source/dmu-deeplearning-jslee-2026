# 파일: shrink_split.py — mydata 의 사진을 800px 로 줄이고 클래스마다 20% 를 val 로 옮긴다
# 사용법 (Git Bash)
#   cd "$DL2026_HOME"
#   source venv/Scripts/activate
#   python shrink_split.py
#
# 사용법 (PowerShell)
#   Set-Location $env:DL2026_HOME
#   .\venv\Scripts\Activate.ps1
#   python shrink_split.py
import random, shutil
from pathlib import Path
from PIL import Image, ImageOps

root = Path("mydata"); random.seed(42); n = 0
for f in root.rglob("*"):
    if f.suffix.lower() in (".jpg", ".jpeg", ".png"):
        im = ImageOps.exif_transpose(Image.open(f)).convert("RGB")
        if max(im.size) > 800:
            im.thumbnail((800, 800)); im.save(f, quality=90); n += 1
print("줄인 사진", n, "장")
for cls in (root / "train").iterdir():
    if not cls.is_dir() or (root / "val" / cls.name).exists(): continue
    files = sorted(cls.glob("*")); random.shuffle(files)
    (root / "val" / cls.name).mkdir(parents=True)
    for f in files[:max(1, len(files) // 5)]:
        shutil.move(str(f), str(root / "val" / cls.name / f.name))
    print(cls.name, "→ val", max(1, len(files) // 5), "장")
