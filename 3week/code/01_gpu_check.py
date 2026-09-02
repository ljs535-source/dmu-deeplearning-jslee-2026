# 파일: 01_gpu_check.py
# 3주차 — PyTorch · GPU 환경 진단 스크립트
#
# 사용법 (PowerShell)
#   1) 작업 폴더로 이동   :  Set-Location $env:DL2026_HOME
#   2) 가상환경 활성화    :  .\venv\Scripts\Activate.ps1
#   3) 실행               :  python 01_gpu_check.py
#
# torch.cuda.is_available() 이 False 여도 그 자체는 실패가 아니다.
# 이 스크립트는 "어디에서 어긋났는지"를 순서대로 짚어 준다.

import platform
import sys
import unicodedata

WIDTH = 62


# ---------------------------------------------------------------- 도구

def dwidth(s):
    """터미널에서 실제로 차지하는 폭. 한글은 두 칸으로 센다."""
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def row(label, value):
    """  라벨 ......... : 값   형태로 한 줄 출력."""
    dots = "." * max(2, 20 - dwidth(label))
    print(f"  {label} {dots} : {value}")


def rule(ch="-"):
    print(ch * WIDTH)


def title(text):
    rule()
    print(f"  {text}")
    rule()


# ------------------------------------------------------------ [1] 파이썬

def section_python():
    print("\n[1] 파이썬")
    row("실행 파일", sys.executable)
    row("버전", platform.python_version())

    in_venv = sys.prefix != sys.base_prefix
    row("가상환경 안?", "YES" if in_venv else "NO  <-- 주의")

    if not in_venv:
        print("      -> venv 가 활성화되지 않았습니다.")
        print("         Set-Location $env:DL2026_HOME")
        print("         .\\venv\\Scripts\\Activate.ps1")
    return in_venv


# ----------------------------------------------------------- [2] PyTorch

def section_torch():
    print("\n[2] PyTorch")
    try:
        import torch
    except ImportError:
        row("torch", "설치되지 않음  <-- 실패")
        print("      -> 1교시 실습 2 의 설치 명령을 다시 실행하세요.")
        return None, None

    ver = torch.__version__
    row("torch 버전", ver)

    if "+cu" in ver:
        build = f"CUDA 빌드 ({ver.split('+')[1]})"
    elif "+cpu" in ver:
        build = "CPU 빌드 (cpu)  <-- GPU 사용 불가"
    else:
        build = "접미사 없음 (플랫폼 기본)"
    row("빌드 종류", build)

    try:
        import torchvision
        row("torchvision", torchvision.__version__)
    except ImportError:
        row("torchvision", "설치되지 않음")

    return torch, ver


# --------------------------------------------------------------- [3] GPU

def section_gpu(torch):
    print("\n[3] GPU")
    avail = torch.cuda.is_available()
    row("cuda.is_available", str(avail))

    if not avail:
        row("GPU 이름", "-")
        return False

    props = torch.cuda.get_device_properties(0)
    row("GPU 이름", props.name)
    row("VRAM", f"{props.total_memory / 1024**3:.2f} GB")
    row("CUDA(런타임)", torch.version.cuda)
    row("장치 개수", str(torch.cuda.device_count()))
    return True


# ------------------------------------------------------ [4] False 진단 순서

def diagnose(ver):
    """is_available() 이 False 일 때 어디를 봐야 하는지 순서대로 안내한다."""
    print("\n[4] False 진단 순서")

    if ver and "+cpu" in ver:
        print("  ① torch.__version__ 에 +cpu 가 있다  -> 여기서 끝. 더 볼 것 없다")
        print("     CPU 빌드를 잘못 설치한 것입니다. GPU 문제가 아닙니다.")
        print("     복구 : 03_install_commands.ps1 블록 4")
        return

    print("  ① torch.__version__ 에 +cpu 는 없다  (OK)")
    print("  ② nvidia-smi 가 실행되는가?")
    print("       PowerShell 에서 nvidia-smi 를 쳐 보세요.")
    print("       안 되면 -> NVIDIA 드라이버가 없거나 GPU 가 없는 PC 입니다.")
    print("  ③ nvidia-smi 의 CUDA Version 이 설치한 빌드보다 낮은가?")
    print("       낮으면 -> 더 낮은 CUDA 빌드로 재설치")
    print("  ④ 위가 다 정상인데 False  -> 손을 드세요")
    print("\n  * 오늘 False 가 나온 것 자체는 실패가 아닙니다.")
    print("    어디를 봐야 하는지 아는 것이 3주차의 목표이고, 2교시가 그 시간입니다.")
    print("    텐서 실습은 CPU 로 전부 가능합니다.")


# ------------------------------------------------------------------ 실행

def main():
    print()
    title("PyTorch · GPU 환경 진단   (01_gpu_check.py)")

    in_venv = section_python()
    torch, ver = section_torch()

    if torch is None:
        rule()
        print("  결론: PyTorch 가 설치되지 않았습니다. 먼저 설치하세요.")
        rule()
        return

    gpu_ok = section_gpu(torch)

    if not gpu_ok:
        diagnose(ver)

    print()
    rule()
    if gpu_ok and in_venv:
        print("  결론: GPU 학습이 가능한 상태입니다.")
    elif gpu_ok and not in_venv:
        print("  결론: GPU 는 되지만 가상환경 밖입니다. venv 를 활성화하세요.")
    else:
        print("  결론: CPU 로 진행합니다. 텐서 실습(2교시)은 전부 가능하며,")
        print("        속도·메모리 실습(3교시)은 Colab 으로 대체할 수 있습니다.")
    rule()
    print()

    # 과제 제출용 한 줄 요약
    print("[과제 제출용 한 줄]")
    print(f"  python={platform.python_version()} / torch={ver} / "
          f"cuda_available={torch.cuda.is_available()}")
    print()


if __name__ == "__main__":
    main()
