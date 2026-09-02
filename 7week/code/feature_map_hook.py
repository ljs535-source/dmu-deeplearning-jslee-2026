# 파일: feature_map_hook.py
# 7주차 — 특징맵(feature map) 시각화 도우미
#
# 사용법 (노트북에서)
#   from feature_map_hook import FeatureCatcher, show_feature_maps
#
#   with FeatureCatcher(net, {"1층": net[0], "2층": net[3]}) as catcher:
#       net(x)
#   show_feature_maps(catcher.feats["1층"], "1층")
#
# 이 실습(1교시 실습 3)의 목적은 코딩이 아니라 **보는 것**이다.
# hook 을 직접 짜느라 8분을 쓰지 않도록 완성본으로 배포한다.
#
# ── forward hook 이란 ────────────────────────────────────────────
#   층에 "이 층을 지나갈 때 나를 불러 줘"라고 등록해 두는 장치.
#   모델 코드를 고치지 않고 중간 결과를 꺼낼 수 있다.
#   9주차 Grad-CAM 도 같은 원리로 동작한다.

import matplotlib.pyplot as plt
import torch


class FeatureCatcher:
    """지정한 층들의 출력을 받아 두는 도구.

    layers : {이름: 층모듈} 사전
    with 블록을 벗어나면 hook 을 자동으로 떼어 낸다 —
    안 떼면 계속 쌓여서 메모리를 먹는다.
    """

    def __init__(self, model, layers):
        self.model = model
        self.layers = layers
        self.feats = {}
        self._handles = []

    def _make(self, name):
        def fn(module, inp, out):
            self.feats[name] = out.detach()      # ★ detach 를 빼면 그래프가 붙어 남는다
        return fn

    def __enter__(self):
        for name, layer in self.layers.items():
            self._handles.append(layer.register_forward_hook(self._make(name)))
        return self

    def __exit__(self, *args):
        self.remove()
        return False

    def remove(self):
        for h in self._handles:
            h.remove()
        self._handles = []


# ------------------------------------------------------------- 시각화

def show_feature_maps(feat, title="", n=8, cmap="viridis"):
    """(B,C,H,W) 특징맵에서 앞 n개 채널을 나란히 그린다."""
    if feat.dim() == 4:
        feat = feat[0]                            # 배치 첫 장만
    feat = feat.cpu()
    n = min(n, feat.shape[0])

    print(f"{title} 특징맵 shape : {tuple(feat.shape)}")
    fig, ax = plt.subplots(1, n, figsize=(1.8 * n, 2.2))
    for i in range(n):
        ax[i].imshow(feat[i], cmap=cmap)
        ax[i].set_title(f"ch {i}", fontsize=8)
        ax[i].axis("off")
    fig.suptitle(f"{title} 특징맵 (앞 {n}개 채널)")
    plt.tight_layout()
    plt.show()


def show_kernels(conv, n=8):
    """Conv2d 층의 커널 자체를 그린다. 학습 전/후를 비교하면 재미있다."""
    w = conv.weight.detach().cpu()                # (out_ch, in_ch, kH, kW)
    n = min(n, w.shape[0])
    fig, ax = plt.subplots(1, n, figsize=(1.5 * n, 2.0))
    for i in range(n):
        k = w[i]
        k = k.permute(1, 2, 0) if k.shape[0] == 3 else k.mean(0)   # 컬러면 RGB로
        k = (k - k.min()) / (k.max() - k.min() + 1e-8)             # 0~1 로 펴기
        ax[i].imshow(k, cmap="gray" if k.dim() == 2 else None)
        ax[i].set_title(f"k {i}", fontsize=8)
        ax[i].axis("off")
    fig.suptitle(f"커널 {n}개  (shape {tuple(w.shape[1:])})")
    plt.tight_layout()
    plt.show()


def conv_out_size(size, kernel, stride=1, padding=0):
    """출력 크기 공식. 1교시 §2-3 그대로 — 손계산 검산용.

        (입력 − 커널 + 2×패딩) // 스트라이드 + 1        ※ 나눗셈은 내림
    """
    return (size - kernel + 2 * padding) // stride + 1


# ------------------------------------------------------------------ 확인

if __name__ == "__main__":
    import torch.nn as nn

    print("출력 크기 공식 확인 (입력 32×32)")
    for k, s, p in [(3, 1, 1), (3, 1, 0), (3, 2, 1), (5, 1, 2), (7, 2, 3)]:
        calc = conv_out_size(32, k, s, p)
        real = nn.Conv2d(3, 8, k, s, p)(torch.randn(1, 3, 32, 32)).shape[-1]
        flag = "OK" if calc == real else "!! 불일치"
        print(f"  k={k} s={s} p={p} | 손계산 {calc:2d} | 실제 {real:2d}  {flag}")
