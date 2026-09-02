# 파일: 00_check_env.py
# 2주차 1교시 — 지금 내가 어느 파이썬 환경에서 실행 중인지 진단하는 스크립트
#
# 사용법 (PowerShell):
#   1) 가상환경을 만들기 "전"에 한 번 실행     :  python 00_check_env.py
#   2) 가상환경을 활성화한 "후"에 다시 실행    :  python 00_check_env.py
#   → 두 출력의 [실행 파일] 과 [가상환경 안?] 줄이 어떻게 달라지는지 비교할 것
#
# 이 스크립트는 외부 패키지를 쓰지 않는다. 어떤 환경에서든 그냥 돌아간다.

import os
import platform
import subprocess
import sys
import unicodedata

LINE = "-" * 62


def dwidth(s):
    """터미널에서 실제로 차지하는 폭. 한글·한자는 두 칸으로 센다."""
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def pad(s, width):
    """dwidth 기준으로 오른쪽을 공백으로 채운다."""
    return s + " " * max(0, width - dwidth(s))


def row(label, value):
    """라벨과 값을 일정한 폭으로 맞춰 한 줄 출력한다."""
    print(f"  {pad(label, 18)} : {value}")


def pip_version():
    """pip 버전과 설치 위치를 가져온다. 없으면 안내 문구를 돌려준다."""
    try:
        out = subprocess.run(
            [sys.executable, "-m", "pip", "-V"],
            capture_output=True, text=True, timeout=20,
        )
        return out.stdout.strip() or "(출력 없음)"
    except Exception as e:                      # pip 자체가 없는 극단적 경우
        return f"(확인 실패: {e})"


def has_hangul(text):
    """문자열에 한글이 들어 있는지 검사한다. 경로 문제 진단용."""
    return any("\uac00" <= ch <= "\ud7a3" or "\u3131" <= ch <= "\u3163" for ch in text)


def main():
    # sys.prefix 와 sys.base_prefix 가 다르면 가상환경 안에 있는 것이다.
    in_venv = sys.prefix != sys.base_prefix
    cwd = os.getcwd()
    home = os.path.expanduser("~")

    print()
    print(LINE)
    print("  파이썬 실행 환경 진단  (00_check_env.py)")
    print(LINE)

    print("\n[1] 지금 실행 중인 파이썬")
    row("실행 파일", sys.executable)
    row("버전", platform.python_version())
    row("prefix", sys.prefix)
    row("base_prefix", sys.base_prefix)
    # → prefix 와 base_prefix 가 같으면 시스템 파이썬, 다르면 가상환경
    row("가상환경 안?", "YES  <-- 가상환경" if in_venv else "NO   <-- 시스템 파이썬")
    row("VIRTUAL_ENV", os.environ.get("VIRTUAL_ENV", "(설정 안 됨)"))

    print("\n[2] pip")
    row("pip", pip_version())

    print("\n[3] 운영체제와 인코딩")
    row("OS", f"{platform.system()} {platform.release()}")
    row("기본 인코딩", sys.getdefaultencoding())
    row("파일시스템", sys.getfilesystemencoding())
    row("stdout", sys.stdout.encoding)

    print("\n[4] 경로 점검")
    row("작업 폴더", cwd)
    row("사용자 폴더", home)
    warn = []
    if has_hangul(cwd):
        warn.append("작업 폴더 경로에 한글이 있음")
    if " " in cwd:
        warn.append("작업 폴더 경로에 공백이 있음")
    if "OneDrive" in cwd:
        warn.append("작업 폴더가 OneDrive 안에 있음 (동기화 충돌 위험)")
    if warn:
        for w in warn:
            row("주의 ★", w)
        row("권장", r"%DL2026_HOME% 처럼 한글/공백 없는 짧은 경로를 쓸 것")
    else:
        row("판정", "문제 없음")

    print("\n" + LINE)
    if in_venv:
        print("  결론: 가상환경 안에서 실행 중이다. 이 상태에서 pip install 하면 된다.")
    else:
        print("  결론: 시스템 파이썬으로 실행 중이다.")
        print("        가상환경을 활성화한 뒤 다시 실행해서 위 값들을 비교해 보자.")
        print(r"        활성화:  .\venv\Scripts\Activate.ps1")
    print(LINE)
    print()


if __name__ == "__main__":
    main()
