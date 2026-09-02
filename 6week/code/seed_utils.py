# 파일: seed_utils.py
# 6주차 — 재현성 도구 모음
#
# 사용법 (노트북에서)
#   from seed_utils import set_seed, describe_env
#   set_seed(42)          # ★ 모델을 만들기 "직전"에 부른다
#
# 9주차 LoRA, 12주차 BERT 파인튜닝처럼 학습이 수십 분 걸리는 주차에서
# 이 파일이 없으면 실험을 통제할 수 없다. 매 노트북 맨 위에 두는 습관을 들인다.

import os
import platform
import random

import numpy as np
import torch


# ------------------------------------------------------------ 시드 고정

def set_seed(seed=42, deterministic=False):
    """무작위성의 출처 네 곳을 한 번에 고정한다.

    seed          : 아무 정수. 팀에서는 하나로 통일해 두는 편이 좋다
    deterministic : True 면 GPU 연산까지 결정적으로 강제한다. **느려진다**

    ⚠️ GPU 에서는 시드를 고정해도 결과가 완전히 같지 않을 수 있다.
       병렬 연산의 덧셈 순서가 실행마다 달라질 수 있기 때문이다.
       실무에서는 "거의 같으면 충분"으로 두고, 대신 조건을 전부 기록한다.
    """
    random.seed(seed)                    # ① 파이썬 기본 난수
    np.random.seed(seed)                 # ② NumPy
    torch.manual_seed(seed)              # ③ PyTorch (CPU)
    torch.cuda.manual_seed_all(seed)     # ④ PyTorch (모든 GPU)

    if deterministic:
        os.environ["CUBLAS_WORKSPACE_CONFIG"] = ":4096:8"
        torch.use_deterministic_algorithms(True)
        torch.backends.cudnn.benchmark = False

    return seed


def seed_worker(worker_id):
    """DataLoader(num_workers>0) 를 쓸 때 워커별 시드까지 고정한다.

    Windows + JupyterLab 에서는 num_workers=0 이 기본이라 보통 필요 없다.
    쓸 일이 생기면 DataLoader(..., worker_init_fn=seed_worker) 로 넘긴다.
    """
    s = torch.initial_seed() % 2**32
    np.random.seed(s)
    random.seed(s)


# ------------------------------------------------------- 실험 조건 기록

def describe_env():
    """실험 조건을 한 줄로 요약한다. 과제 비교표의 맨 위에 붙이면 좋다."""
    gpu = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    return (f"python={platform.python_version()} / torch={torch.__version__} / "
            f"device={gpu}")


def log_config(**kwargs):
    """조건을 보기 좋게 출력한다.

    예)  log_config(optimizer="Adam", lr=1e-3, epochs=5, batch=128, seed=42)
    """
    print("[실험 조건]")
    print("  " + describe_env())
    for k, v in kwargs.items():
        print(f"  {k:14s} : {v}")


# ------------------------------------------------------------ 체크포인트

def save_checkpoint(path, epoch, model, optimizer, **extra):
    """모델 + 옵티마이저 + epoch 를 함께 저장한다.

    ★ 옵티마이저 상태를 빼면 재개 직후 손실이 튄다 —
      Momentum 이 쌓아 둔 관성, Adam 이 쌓아 둔 통계가 전부 0 이 되기 때문이다.
    """
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    payload = {
        "epoch": epoch,
        "model": model.state_dict(),
        "optimizer": optimizer.state_dict(),
    }
    payload.update(extra)
    torch.save(payload, path)
    return path


def load_checkpoint(path, model, optimizer=None, device="cpu"):
    """save_checkpoint 로 저장한 것을 되살린다. 다음 epoch 번호를 반환한다."""
    ckpt = torch.load(path, map_location=device)      # ★ GPU→CPU 이동에 필요
    model.load_state_dict(ckpt["model"])
    if optimizer is not None:
        optimizer.load_state_dict(ckpt["optimizer"])
    return ckpt["epoch"]


# ------------------------------------------------------------------ 확인

if __name__ == "__main__":
    print(describe_env())

    print("\n[시드 고정 안 함]")
    for i in range(2):
        print(f"  {i+1}회차 : {torch.randn(3).tolist()}")

    print("\n[시드 고정]")
    for i in range(2):
        set_seed(42)
        print(f"  {i+1}회차 : {torch.randn(3).tolist()}")
    print("\n→ 아래 두 줄이 같으면 정상")
