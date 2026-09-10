# 파일: verify_week3.py
# 3주차 과제 자가 점검 스크립트
#
# 사용법 (PowerShell)
#   1) 작업 폴더로 이동          :  Set-Location $env:DL2026_HOME
#   2) 가상환경 활성화           :  .\venv\Scripts\Activate.ps1
#   3) 실행                      :  python verify_week3.py
#   4) 출력 전체를 복사해서 LMS 과제란에 붙여넣는다
#
# 검사에 실패한 항목에는 "바로 실행할 복구 명령"이 함께 출력된다.
# 그 명령을 그대로 실행한 뒤 이 스크립트를 다시 돌리면 된다.
#
# ★ [3] GPU 항목은 실패해도 감점하지 않는다.
#    is_available() 이 False 인 화면과 어느 단계에서 걸렸는지를 회고에 적으면 된다.

import json
import subprocess
import sys
import unicodedata
from pathlib import Path

WIDTH = 62
NOTEBOOK = "02_tensor_basics.ipynb"
MIN_CELLS_WITH_OUTPUT = 8       # 코드 셀 17개 중 최소 8개는 출력이 남아 있어야 한다


# ---------------------------------------------------------------- 도구

def dwidth(s):
    """터미널에서 실제로 차지하는 폭. 한글·한자는 두 칸으로 센다."""
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def pad(s, width):
    """dwidth 기준으로 오른쪽을 공백으로 채운다."""
    return s + " " * max(0, width - dwidth(s))


def box(text):
    """상자 안에 한 줄을 넣어 출력한다."""
    print("|" + pad(" " + text, WIDTH) + "|")


def run(args, cwd=None):
    """외부 명령을 실행하고 (성공여부, 출력) 을 돌려준다."""
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                           timeout=60, shell=False)
        return p.returncode == 0, (p.stdout + p.stderr).strip()
    except Exception as e:
        return False, f"({e})"


def git(*args):
    return run(["git", *args])


# ------------------------------------------------------------- 검사 6종
# 각 검사는 (상태, 설명, 복구명령) 을 돌려준다.
#   상태 : "PASS" / "FAIL" / "정보"   ("정보" 는 감점 대상이 아님)

def check_1_venv():
    in_venv = sys.prefix != sys.base_prefix
    if not in_venv:
        return "FAIL", "가상환경 밖에서 실행 중", (
            "Set-Location $env:DL2026_HOME ; .\\venv\\Scripts\\Activate.ps1")
    return "PASS", Path(sys.prefix).name + " 활성화됨", ""


def check_2_torch():
    try:
        import torch
    except ImportError:
        return "FAIL", "torch 가 설치되지 않음", (
            "pip install torch torchvision --index-url "
            "https://download.pytorch.org/whl/cu126")

    ver = torch.__version__
    if "+cpu" in ver:
        return "FAIL", f"{ver}  <- CPU 빌드", (
            "pip uninstall -y torch torchvision ; "
            "pip install torch torchvision --index-url "
            "https://download.pytorch.org/whl/cu126")
    if "+cu" in ver:
        return "PASS", f"{ver}  (CUDA 빌드)", ""
    return "PASS", f"{ver}  (접미사 없음)", ""


def check_3_gpu():
    """GPU 는 실패해도 감점하지 않는다. 상태만 기록한다."""
    try:
        import torch
    except ImportError:
        return "정보", "torch 없음", ""

    if torch.cuda.is_available():
        name = torch.cuda.get_device_name(0)
        vram = torch.cuda.get_device_properties(0).total_memory / 1024**3
        return "PASS", f"{name} / {vram:.1f} GB", ""

    return "정보", "is_available() = False (감점 없음)", (
        "회고에 '어느 단계에서 걸렸는지'를 적으세요. "
        "속도·메모리 실습은 Colab 결과로 대체할 수 있습니다.")


def check_4_notebook():
    p = Path(NOTEBOOK)
    if not p.exists():
        return "FAIL", f"{NOTEBOOK} 이 없음", (
            f"{NOTEBOOK} 을 작업 폴더로 복사한 뒤 셀을 실행하세요.")

    try:
        nb = json.load(open(p, encoding="utf-8"))
    except Exception as e:
        return "FAIL", f"노트북을 읽을 수 없음 ({e})", ""

    codes = [c for c in nb.get("cells", []) if c.get("cell_type") == "code"]
    with_out = sum(1 for c in codes if c.get("outputs"))

    if with_out < MIN_CELLS_WITH_OUTPUT:
        return "FAIL", f"출력이 남은 셀 {with_out}/{len(codes)}개", (
            "노트북에서 셀을 처음부터 실행한 뒤 Ctrl+S 로 저장하세요. "
            "(출력이 저장되어야 채점됩니다)")
    return "PASS", f"출력이 남은 셀 {with_out}/{len(codes)}개", ""


def check_5_requirements():
    p = Path("requirements.txt")
    if not p.exists():
        return "FAIL", "requirements.txt 가 없음", "pip freeze > requirements.txt"

    text = p.read_text(encoding="utf-8", errors="replace")
    lines = [l.strip() for l in text.splitlines() if l.strip().lower().startswith("torch")]
    if not lines:
        return "FAIL", "torch 가 들어 있지 않음 (갱신 안 됨)", (
            "pip freeze > requirements.txt")
    return "PASS", lines[0], ""


def check_6_git():
    ok_repo, _ = git("rev-parse", "--is-inside-work-tree")
    if not ok_repo:
        return "FAIL", "git 저장소가 아님", "2주차 실습 10~12 를 다시 확인하세요."

    ok_remote, remote = git("remote", "get-url", "origin")
    if not ok_remote or not remote:
        return "FAIL", "origin 원격이 없음", (
            "git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git")

    ok_cnt, cnt = git("rev-list", "--count", "HEAD")
    n = int(cnt) if ok_cnt and cnt.isdigit() else 0

    ok_st, st = git("status", "--porcelain")
    dirty = bool(st.strip()) if ok_st else False

    if dirty:
        return "FAIL", f"커밋 {n}개 / 커밋 안 된 변경이 있음", (
            'git add . ; git commit -m "week3: pytorch cuda setup + tensor basics" ; git push')
    if n < 3:
        return "FAIL", f"커밋 {n}개 (3주차까지 3개 이상 권장)", (
            'git add . ; git commit -m "week3" ; git push')
    return "PASS", f"커밋 {n}개 / 변경사항 없음", ""


CHECKS = [
    ("[1] 가상환경 실행",   check_1_venv),
    ("[2] PyTorch 빌드",    check_2_torch),
    ("[3] GPU 사용 가능",   check_3_gpu),
    ("[4] 노트북 출력",     check_4_notebook),
    ("[5] requirements",    check_5_requirements),
    ("[6] git 커밋·push",   check_6_git),
]


# ------------------------------------------------------------------ 출력

def main():
    bar = "+" + "-" * WIDTH + "+"

    print()
    print(bar)
    box("3주차 과제 자가 점검 결과")
    print(bar)

    results = []
    for label, fn in CHECKS:
        try:
            state, detail, fix = fn()
        except Exception as e:                  # 검사 자체가 죽어도 계속 진행
            state, detail, fix = "FAIL", f"검사 중 오류 ({e})", ""
        results.append((label, state, detail, fix))
        dots = "." * max(2, 40 - dwidth(label))
        box(f"{label} {dots} {state}")

    print(bar)

    graded = [r for r in results if r[1] != "정보"]
    passed = sum(1 for _, s, _, _ in graded if s == "PASS")
    box(f"채점 대상 {passed}/{len(graded)} 통과"
        + ("   (GPU 항목은 감점 대상이 아닙니다)" if any(s == "정보" for _, s, _, _ in results) else ""))
    print(bar)

    print("\n[상세]")
    for label, state, detail, _ in results:
        print(f"  {label} : {detail}")

    fails = [(l, f) for l, s, _, f in results if s == "FAIL" and f]
    infos = [(l, f) for l, s, _, f in results if s == "정보" and f]

    if fails:
        print("\n[고쳐야 할 것]")
        for label, fix in fails:
            print(f"  {label}")
            print(f"    -> {fix}")

    if infos:
        print("\n[참고]")
        for label, fix in infos:
            print(f"  {label}")
            print(f"    -> {fix}")

    if not fails:
        print("\n  모두 통과했습니다. 이 출력 전체를 복사해 LMS 과제란에 붙여넣으세요.")
    print()


if __name__ == "__main__":
    main()
