# 파일: prepare_mydata.py
# 9주차 — 본인 이미지 데이터셋 폴더 구조 검증 스크립트
#
# 사용법 (PowerShell)
#   Set-Location $env:DL2026_HOME
#   .\venv\Scripts\Activate.ps1
#   python prepare_mydata.py                 # 기본 경로 mydata 를 검사
#   python prepare_mydata.py D:\사진\내데이터  # 다른 경로를 검사
#
# 기대하는 구조
#   mydata/
#   ├── train/
#   │   ├── 고양이/  img001.jpg ...      (클래스당 24~48장)
#   │   ├── 강아지/
#   │   └── 토끼/
#   └── val/
#       ├── 고양이/                       (클래스당 6~12장)
#       ├── 강아지/
#       └── 토끼/
#
# 수업 시작 전에 이 스크립트를 돌려 "통과"가 나오면 실습 1에서 막히지 않는다.

import sys
import unicodedata
from collections import Counter
from pathlib import Path

WIDTH = 64

# torchvision.datasets.ImageFolder 가 읽는 확장자
OK_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".ppm", ".tif", ".tiff"}
# 자주 들어오는데 못 읽는 것들
BAD_EXT = {".heic", ".heif", ".gif", ".mp4", ".mov", ".avif"}


def dwidth(s):
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def pad(s, n):
    return s + " " * max(0, n - dwidth(s))


def rule(ch="-"):
    print(ch * WIDTH)


# --------------------------------------------------------------- 검사

def scan_split(root, split, problems):
    """train/ 또는 val/ 하나를 훑어 {클래스: 장수} 를 돌려준다."""
    base = root / split
    print(f"\n[{split}]")

    if not base.is_dir():
        print(f"  '{split}' 폴더가 없습니다.  <-- 실패")
        problems.append(f"{split}/ 폴더 없음")
        return {}

    # 클래스 폴더가 아니라 이미지가 바로 들어 있는 경우
    loose = [p for p in base.iterdir() if p.is_file() and p.suffix.lower() in OK_EXT]
    if loose:
        print(f"  이미지 {len(loose)}장이 클래스 폴더 없이 바로 들어 있습니다.  <-- 실패")
        print(f"     -> {split}/<클래스명>/ 폴더를 만들어 그 안에 넣으세요")
        problems.append(f"{split}/ 아래에 클래스 폴더가 없음")

    counts, ext_bad = {}, Counter()
    for cls in sorted(p for p in base.iterdir() if p.is_dir()):
        files = [p for p in cls.rglob("*") if p.is_file()]
        good = [p for p in files if p.suffix.lower() in OK_EXT]
        bad = [p for p in files if p.suffix.lower() in BAD_EXT]
        for p in bad:
            ext_bad[p.suffix.lower()] += 1

        # 클래스 폴더 안에 또 폴더가 있는 흔한 실수
        nested = [p for p in cls.iterdir() if p.is_dir()]
        note = ""
        if nested:
            note = f"  <-- 안에 폴더가 또 있습니다 ({nested[0].name})"
            problems.append(f"{split}/{cls.name}/ 안에 하위 폴더")
        if bad:
            note += f"  <-- 못 읽는 파일 {len(bad)}개"

        counts[cls.name] = len(good)
        print(f"  {pad(cls.name, 16)}{len(good):4d}장{note}")

    if ext_bad:
        print("\n  못 읽는 확장자")
        for ext, n in ext_bad.items():
            print(f"     {ext} {n}개  -> .jpg 로 변환하세요"
                  f"{' (윈도우 사진 앱에서 일괄 가능)' if ext in ('.heic', '.heif') else ''}")
        problems.append("변환이 필요한 확장자가 있음")

    return counts


def judge(train, val, problems):
    """규모와 균형을 본다."""
    print("\n[규모 점검]")

    if not train:
        print("  train 에 클래스가 없습니다.  <-- 실패")
        problems.append("train 클래스 0개")
        return

    n_cls = len(train)
    total = sum(train.values()) + sum(val.values())
    print(f"  클래스 수 .......... : {n_cls}   (권장 3~5)")
    print(f"  전체 장수 .......... : {total}   (권장 100~300)")

    if not 3 <= n_cls <= 5:
        print("     -> 클래스 3~5개를 권장합니다 (적으면 심심하고, 많으면 장수가 모자랍니다)")
    if total < 100:
        print("     -> 100장 미만이면 학습 결과가 들쭉날쭉합니다. 조금 더 모으세요")

    if set(train) != set(val):
        only_t = sorted(set(train) - set(val))
        only_v = sorted(set(val) - set(train))
        print(f"  train 과 val 의 클래스 이름이 다릅니다.  <-- 실패")
        if only_t: print(f"     train 에만 : {only_t}")
        if only_v: print(f"     val 에만   : {only_v}")
        problems.append("train/val 클래스 이름 불일치")

    lo, hi = min(train.values()), max(train.values())
    if lo == 0:
        print("  비어 있는 클래스가 있습니다.  <-- 실패")
        problems.append("빈 클래스")
    elif hi > lo * 3:
        print(f"  클래스별 장수 편차가 큽니다 ({lo} ~ {hi}장)")
        print("     -> 6주차에 배운 클래스 불균형입니다. 정확도만 보면 속습니다")

    for cls, n in val.items():
        if n < 5:
            print(f"  val/{cls} 이 {n}장뿐입니다 -> 검증 정확도가 크게 튑니다 (권장 6~12장)")


# ------------------------------------------------------------------ 실행

def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "mydata")

    print()
    rule("=")
    print(f"  내 이미지 데이터셋 점검   ({root})")
    rule("=")

    if not root.is_dir():
        print(f"\n  '{root}' 폴더를 찾을 수 없습니다.")
        print("  현재 위치 :", Path.cwd())
        print("\n  -> 폴더를 만들거나, 경로를 인자로 주세요:")
        print("     python prepare_mydata.py D:\\사진\\내데이터")
        print("  -> 데이터를 못 모아 왔으면 대체 데이터셋 배포본을 받으세요 (감점 없음)")
        return

    problems = []
    train = scan_split(root, "train", problems)
    val = scan_split(root, "val", problems)
    judge(train, val, problems)

    print()
    rule()
    if problems:
        print("  결론: 아래를 고친 뒤 다시 실행하세요")
        for p in dict.fromkeys(problems):
            print(f"    - {p}")
    else:
        print("  결론: 통과. 실습 1의 ImageFolder 로 바로 로딩됩니다.")
        print(f"        CLASSES = {sorted(train)}")
    rule()
    print()


if __name__ == "__main__":
    main()
