# 파일: sample_data.py
# 9주차 — 연습용 이미지 데이터셋(mydata_sample/) 만들기
#
# 본인 이미지(mydata/)를 준비하지 못한 학생용입니다. 감점은 없습니다.
# CIFAR-10 에서 3개 클래스만 골라 mydata/ 와 똑같은 폴더 구조로 저장합니다.
#
# 사용법 (Git Bash)
#   cd "$DL2026_HOME"
#   source venv/Scripts/activate
#   python sample_data.py
#
# 사용법 (PowerShell)
#   Set-Location $env:DL2026_HOME
#   .\venv\Scripts\Activate.ps1
#   python sample_data.py
#
# 노트북 14_image_project 의 셀 1 은 mydata/ 가 없으면 이 파일을 자동으로 불러 씁니다.
#
# 만들어지는 구조
#   mydata_sample/
#   ├── train/  비행기/ 자동차/ 고양이/   (클래스당 60장)
#   └── val/    비행기/ 자동차/ 고양이/   (클래스당 20장)
#
# ※ CIFAR-10 원본(약 170MB)을 data/ 에 내려받습니다. 실습실 공유 폴더의 data/ 를
#   복사해 두었다면 다운로드 없이 바로 끝납니다.

import os

CIFAR_KO = ["비행기", "자동차", "새", "고양이", "사슴", "개", "개구리", "말", "배", "트럭"]
PICK = [0, 1, 3]            # 비행기 · 자동차 · 고양이
N_TRAIN, N_VAL = 60, 20     # 클래스당 장수 (학생 본인 데이터 권장 규모와 같게)


def make_sample(out="mydata_sample", data_root="data"):
    """CIFAR-10 에서 PICK 클래스만 골라 out/train|val/<클래스>/ 에 png 로 저장한다."""
    if os.path.isdir(os.path.join(out, "train")):
        print(f"이미 있습니다 : {out}/  (다시 만들려면 폴더를 지우세요)")
        return out

    from torchvision import datasets

    raw = datasets.CIFAR10(data_root, train=True, download=True)
    count = {c: 0 for c in PICK}
    for img, y in raw:                       # 앞에서부터 순서대로 → 어느 PC 에서나 같은 사진
        if y not in count or count[y] >= N_TRAIN + N_VAL:
            continue
        split = "train" if count[y] < N_TRAIN else "val"
        folder = os.path.join(out, split, CIFAR_KO[y])
        os.makedirs(folder, exist_ok=True)
        img.save(os.path.join(folder, f"{count[y]:03d}.png"))
        count[y] += 1
        if all(v >= N_TRAIN + N_VAL for v in count.values()):
            break

    print(f"완료 : {out}/  ({', '.join(CIFAR_KO[c] for c in PICK)} · "
          f"train {N_TRAIN}장 / val {N_VAL}장씩)")
    return out


if __name__ == "__main__":
    make_sample()
