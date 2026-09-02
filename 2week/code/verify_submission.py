# 파일: verify_submission.py
# 2주차 과제 자가 점검 스크립트
#
# 사용법 (PowerShell)
#   1) 작업 폴더로 이동          :  Set-Location "<작업 폴더>"   (예: C:\dl2026)
#   2) 가상환경 활성화           :  .\venv\Scripts\Activate.ps1
#   3) 실행                      :  python verify_submission.py
#   4) 출력 전체를 복사해서 LMS 과제란에 붙여넣는다
#
# 검사에 실패한 항목에는 "바로 실행할 복구 명령"이 함께 출력된다.
# 그 명령을 그대로 실행한 뒤 이 스크립트를 다시 돌리면 된다.

import json
import os
import subprocess
import sys
import unicodedata
from pathlib import Path

WIDTH = 60
KERNEL_NAME = "dl2026"
REQUIRED_PACKAGES = ["jupyterlab", "ipykernel", "numpy", "pandas", "matplotlib",
                     "humanize"]

# .gitignore 로 제외해야 하는 가상환경 폴더들.
# wrongvenv 는 2교시 실습 6(틀린 커널 재현)에서 만든다.
VENV_DIRS = ["venv", "tmpvenv", "wrongvenv"]


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
        p = subprocess.run(
            args, cwd=cwd, capture_output=True, text=True,
            timeout=60, shell=False,
        )
        return p.returncode == 0, (p.stdout + p.stderr).strip()
    except Exception as e:
        return False, f"({e})"


def git(*args):
    """git 명령 실행 헬퍼."""
    return run(["git", *args])


def importable(name):
    """패키지를 import 할 수 있는지 확인한다 (실제 import 없이 스펙만 조회)."""
    import importlib.util
    try:
        return importlib.util.find_spec(name) is not None
    except Exception:
        return False


# ------------------------------------------------------------- 검사 7종

def check_1_venv():
    """[1] 가상환경 안에서 실행 중인가."""
    ok = sys.prefix != sys.base_prefix
    detail = sys.executable
    fix = r"가상환경을 활성화한 뒤 다시 실행:  .\venv\Scripts\Activate.ps1"
    return ok, detail, fix


def check_2_python_version():
    """[2] 파이썬 3.13.x 인가."""
    v = sys.version_info
    ok = (v.major, v.minor) == (3, 13)
    detail = f"{v.major}.{v.minor}.{v.micro}"
    fix = "Python 3.13.x 로 가상환경 재생성:  py -3.13 -m venv venv"
    return ok, detail, fix


def check_3_requirements():
    """[3] requirements.txt 가 있고 내용이 있는가."""
    path = Path("requirements.txt")
    if not path.exists():
        return False, "파일 없음", "pip freeze > requirements.txt"
    lines = [l for l in path.read_text(encoding="utf-8", errors="replace").splitlines()
             if l.strip() and not l.startswith("#")]
    pinned = sum(1 for l in lines if "==" in l)
    ok = len(lines) > 0 and pinned > 0
    detail = f"{len(lines)}줄 (버전 고정 {pinned}줄)"
    fix = "pip freeze > requirements.txt   (pip list 가 아니라 pip freeze 여야 한다)"
    return ok, detail, fix


def check_4_packages():
    """[4] 필수 패키지를 import 할 수 있는가.

    humanize 는 2교시 실습 8(ModuleNotFoundError 재현)과
    01_env_check.ipynb 셀 2의 '지문 패키지'라서 반드시 포함한다.
    """
    n = len(REQUIRED_PACKAGES)
    missing = [p for p in REQUIRED_PACKAGES if not importable(p)]
    ok = not missing
    detail = f"{n}/{n} 설치됨" if ok else f"누락: {', '.join(missing)}"
    fix = "pip install " + " ".join(REQUIRED_PACKAGES)
    return ok, detail, fix


def _kernel_json_path():
    """등록된 dl2026 커널의 kernel.json 경로를 찾는다."""
    # 1순위: jupyter_client 로 정식 조회
    try:
        from jupyter_client.kernelspec import KernelSpecManager
        specs = KernelSpecManager().get_all_specs()
        if KERNEL_NAME in specs:
            return Path(specs[KERNEL_NAME]["resource_dir"]) / "kernel.json"
    except Exception:
        pass
    # 2순위: 표준 사용자 경로 직접 확인
    appdata = os.environ.get("APPDATA")
    if appdata:
        p = Path(appdata) / "jupyter" / "kernels" / KERNEL_NAME / "kernel.json"
        if p.exists():
            return p
    return None


def check_5_kernel():
    """[5] dl2026 커널이 등록되어 있고, 현재 가상환경을 가리키는가."""
    fix = ('python -m ipykernel install --user --name dl2026 '
           '--display-name "Python (dl2026)"')
    path = _kernel_json_path()
    if path is None or not path.exists():
        return False, f"커널 '{KERNEL_NAME}' 미등록", fix

    try:
        spec = json.loads(path.read_text(encoding="utf-8"))
        argv0 = spec.get("argv", [""])[0]
    except Exception as e:
        return False, f"kernel.json 읽기 실패 ({e})", fix

    # argv[0] 이 지금 실행 중인 가상환경의 python.exe 를 가리켜야 한다.
    same = Path(argv0).resolve().parent.resolve() == Path(sys.executable).resolve().parent.resolve()
    if same:
        return True, f"등록됨 -> {argv0}", fix
    return False, f"다른 환경을 가리킴 -> {argv0}", (
        fix + "   (현재 가상환경을 활성화한 상태에서 실행할 것)")


def check_6_git_remote():
    """[6] git 저장소이고 원격(origin)이 연결되어 있는가."""
    ok_repo, _ = git("rev-parse", "--is-inside-work-tree")
    if not ok_repo:
        return False, "git 저장소가 아님", "git init"
    ok_remote, out = git("remote", "get-url", "origin")
    if not ok_remote or not out:
        return False, "원격 origin 없음", (
            "git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git")
    return True, out.splitlines()[0], ""


def check_7_venv_untracked():
    """[7] venv/ 가 추적되지 않는가 + 커밋이 2개 이상인가."""
    ok_repo, _ = git("rev-parse", "--is-inside-work-tree")
    if not ok_repo:
        return False, "git 저장소가 아님", "git init"

    _, tracked = git("ls-files")
    bad = [f for f in tracked.splitlines()
           if any(f.startswith(d + "/") for d in VENV_DIRS)]
    if bad:
        # 실제로 추적되고 있는 폴더만 골라 복구 명령에 그대로 넣어 준다.
        folders = sorted({f.split("/")[0] for f in bad})
        targets = " ".join(folders)
        fix = (
            '① .gitignore 에 "' + '/", "'.join(folders) + '/" 가 있는지 먼저 확인:  '
            'Get-Content .gitignore\n'
            '     (없으면 gitignore_template.txt 를 참고해 먼저 만든다)\n'
            '② git rm -r --cached ' + targets + '\n'
            '③ git add .          <- 이 줄을 빠뜨리면 전체 삭제 커밋이 된다\n'
            '④ git status         <- 삭제(D)로 잡힌 것이 위 폴더뿐인지 눈으로 확인\n'
            '⑤ git commit -m "stop tracking venv" ; git push'
        )
        shown = ", ".join(f + "/" for f in folders)
        return False, f"venv 파일 {len(bad)}개가 추적되고 있음 ({shown})", fix

    ok_cnt, cnt = git("rev-list", "--count", "HEAD")
    n = int(cnt) if ok_cnt and cnt.isdigit() else 0
    if n < 2:
        return False, f"venv 미추적 OK / 커밋 {n}개 (2개 이상 필요)", (
            "파일을 수정한 뒤:  git add . ; git commit -m \"update\" ; git push")
    return True, f"venv 미추적 OK / 커밋 {n}개", ""


CHECKS = [
    ("[1] 가상환경 실행",   check_1_venv),
    ("[2] Python 3.13.x",   check_2_python_version),
    ("[3] requirements",    check_3_requirements),
    ("[4] 필수 패키지",     check_4_packages),
    ("[5] 커널 dl2026",     check_5_kernel),
    ("[6] git 원격 연결",   check_6_git_remote),
    ("[7] venv 미추적",     check_7_venv_untracked),
]


# ------------------------------------------------------------------ 출력

def main():
    bar = "+" + "-" * WIDTH + "+"

    print()
    print(bar)
    box("2주차 과제 자가 점검 결과")
    print(bar)

    results = []
    for label, fn in CHECKS:
        try:
            ok, detail, fix = fn()
        except Exception as e:                  # 검사 자체가 죽어도 계속 진행
            ok, detail, fix = False, f"검사 중 오류 ({e})", ""
        results.append((label, ok, detail, fix))
        dots = "." * max(2, 40 - dwidth(label))
        box(f"{label} {dots} {'PASS' if ok else 'FAIL'}")

    passed = sum(1 for _, ok, _, _ in results if ok)
    print(bar)
    box(f"결과: {passed} / {len(results)} PASS")

    ok_head, head = git("rev-parse", "--short", "HEAD")
    box(f"커밋 해시: {head.splitlines()[0] if ok_head and head else '(없음 — git 저장소가 아니거나 커밋 0개)'}")
    print(bar)

    print("\n[상세]")
    for label, ok, detail, _ in results:
        print(f"  {pad(label, 22)} {'PASS' if ok else 'FAIL'}  {detail}")

    failed = [(label, fix) for label, ok, _, fix in results if not ok and fix]
    if failed:
        print("\n[복구 명령] — 위에서부터 순서대로 실행한 뒤 이 스크립트를 다시 돌리세요.")
        for label, fix in failed:
            print(f"  {label}")
            for line in fix.splitlines():      # 여러 줄짜리 복구 안내도 들여쓰기를 유지한다
                print(f"      {line}")
    else:
        print("\n  전부 통과했습니다. 이 출력 전체를 복사해서 LMS 에 붙여넣으세요.")
    print()


if __name__ == "__main__":
    main()
