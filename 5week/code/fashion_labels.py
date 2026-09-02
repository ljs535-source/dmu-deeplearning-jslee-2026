# 파일: fashion_labels.py
# 5주차 — FashionMNIST 라벨과 시각화 도우미
#
# 사용법 (노트북에서)
#   from fashion_labels import LABELS, setup_korean_font, show_grid
#
# 노트북과 같은 폴더에 두면 그대로 import 된다.
# 6·13주차에서 FashionMNIST 를 다시 쓸 때도 이 파일을 복사해 쓴다.

import matplotlib.pyplot as plt

# ------------------------------------------------------------------ 라벨

# torchvision.datasets.FashionMNIST 의 클래스 순서 그대로 (0~9)
LABELS = [
    "티셔츠",     # 0  T-shirt/top
    "바지",       # 1  Trouser
    "풀오버",     # 2  Pullover
    "드레스",     # 3  Dress
    "코트",       # 4  Coat
    "샌들",       # 5  Sandal
    "셔츠",       # 6  Shirt
    "스니커즈",   # 7  Sneaker
    "가방",       # 8  Bag
    "앵클부츠",   # 9  Ankle boot
]

# 모델이 자주 헷갈리는 조합 — 3교시 실습 9의 관찰 포인트
CONFUSING = [(2, 4), (2, 6), (4, 6)]      # 풀오버·코트·셔츠

# FashionMNIST 전체 학습셋의 실측 통계 (transforms.Normalize 에 그대로 쓴다)
MEAN = (0.2860,)
STD = (0.3530,)


def name(idx):
    """클래스 번호를 한글 이름으로. 텐서를 넣어도 동작한다."""
    return LABELS[int(idx)]


# ------------------------------------------------------------- 시각화

def setup_korean_font(font="Malgun Gothic"):
    """matplotlib 한글 깨짐 방지. 노트북 맨 위에서 한 번만 부르면 된다."""
    plt.rcParams["font.family"] = font
    plt.rcParams["axes.unicode_minus"] = False


def show_grid(images, titles=None, ncols=8, size=1.8):
    """(N,1,28,28) 또는 (N,28,28) 이미지를 격자로 그린다.

    images : 텐서 (CPU 로 옮겨져 있어야 한다)
    titles : 각 칸 제목 리스트 (없으면 제목 없음)
    """
    n = len(images)
    nrows = (n + ncols - 1) // ncols
    fig, ax = plt.subplots(nrows, ncols, figsize=(ncols * size, nrows * size))
    axes = ax.flat if n > 1 else [ax]

    for i, a in enumerate(axes):
        a.axis("off")
        if i >= n:
            continue
        img = images[i]
        if img.dim() == 3:          # (1,28,28) → (28,28)
            img = img[0]
        a.imshow(img, cmap="gray")
        if titles is not None:
            a.set_title(titles[i], fontsize=9)

    plt.tight_layout()
    plt.show()


def wrong_titles(preds, targets):
    """오분류 격자용 제목 — '예측 X / 정답 Y' 형태."""
    return [f"예측 {name(p)}\n정답 {name(t)}" for p, t in zip(preds, targets)]


# ------------------------------------------------------------------ 확인

if __name__ == "__main__":
    print("FashionMNIST 클래스 10개")
    for i, lab in enumerate(LABELS):
        mark = "  <- 자주 혼동" if i in (2, 4, 6) else ""
        print(f"  {i} : {lab}{mark}")
    print(f"\nNormalize 인자 : mean={MEAN}, std={STD}")
