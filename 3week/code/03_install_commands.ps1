# =====================================================================
#  파일: 03_install_commands.ps1
#  3주차 실습 PowerShell 명령 모음 (블록 1 ~ 5)
# =====================================================================
#
#  ★ 이 파일은 "통째로 실행하는 스크립트"가 아니다. 복습·복사용 참조 파일이다.
#     수업 중에는 교시 자료를 보면서 한 줄씩 직접 입력한다.
#     블록별로 필요한 부분만 골라 복사해서 쓸 것.
#
#  실행 위치 : VSCode 통합 터미널(PowerShell) 또는 Windows PowerShell
#  작업 폴더 : %DL2026_HOME%   (2주차에 만든 폴더)
#  전제 조건 : venv 활성화 상태  ->  프롬프트 앞에 (venv) 가 보여야 한다
#
# ---------------------------------------------------------------------
#  ★★ 오프라인 wheel 로 설치하는 경우
#
#     교수가 공유 폴더/USB 로 wheel 을 배포했다면, 아래 블록들의
#     --index-url ... 부분을 전부 --no-index --find-links=$W 로 바꾼다.
#     (블록 1 아래의 "오프라인 변형" 주석 참조)
#
#     25대가 동시에 2.5GB 를 받으면 학교망이 포화된다. 특히 블록 4(복구)를
#     온라인 명령 그대로 두면 2교시에 그 부하가 한 번 더 발생한다.
# =====================================================================


# 공유 폴더 경로 (교수 안내에 따라 바꿀 것). 온라인으로 설치한다면 무시한다.
$W = "$env:DL2026_SETUP\wheels"
# $W = "\\서버\dl2026\wheels"        # 파일서버를 쓰는 경우


#region 블록 0 — 지난 주 환경이 살아 있는지 확인 (1교시 시작 시)
# ---------------------------------------------------------------------
Set-Location $env:DL2026_HOME
.\venv\Scripts\Activate.ps1
python -c "import sys; print(sys.executable)"
# -> %DL2026_HOME%\venv\Scripts\python.exe 가 나와야 정상

# 안 되면 (증상별 조치)
#   폴더가 없다            : 2주차 실습 1 을 다시 (5분). requirements.txt 로 복원
#   실행 정책 오류         : Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   커널 목록에 dl2026 없음: python -m ipykernel install --user --name dl2026 --display-name "Python (dl2026)"
#endregion


#region 블록 1 — 실습 2: PyTorch 설치  ★ 1교시
# ---------------------------------------------------------------------
# ★ 아래 명령은 "예시"다. 반드시 공식 선택기에서 나온 명령을 쓸 것.
#    https://pytorch.org/get-started/locally/
#    Stable / Windows / Pip / Python / CUDA 12.x  를 고르면 명령이 나온다.
#
#    CUDA 버전은 nvidia-smi 오른쪽 위의 "CUDA Version" 이하로 고른다.

Set-Location $env:DL2026_HOME
.\venv\Scripts\Activate.ps1        # ★ 반드시 (venv) 상태에서

pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124
#                              ^^^^^^^^^^^ 이 부분이 핵심. 없으면 CPU 빌드가 올 수 있다

# --- 오프라인 변형 (교수가 wheel 을 배포한 경우) -----------------------
# pip install --no-index --find-links=$W torch torchvision

# --- 다운로드가 자꾸 끊기는 경우 --------------------------------------
# pip install --timeout 300 --retries 5 torch torchvision --index-url https://download.pytorch.org/whl/cu124

# 약 2.5GB. 학교망 상황에 따라 5~20분. 터미널을 닫지 말 것.
#endregion


#region 블록 2 — 실습 3: 설치 검증 3종  ★ 1교시
# ---------------------------------------------------------------------
python -c "import torch; print('version :', torch.__version__)"
python -c "import torch; print('cuda    :', torch.cuda.is_available())"
python -c "import torch; print('device  :', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '(GPU 없음)')"

# 기대 출력
#   version : 2.x.x+cu124        <- +cu124 접미사 확인 (+cpu 면 실패)
#   cuda    : True               <- 오늘의 목표
#   device  : NVIDIA GeForce RTX xxxx

# ★ 세 번째 줄에 if/else 를 넣은 이유
#    get_device_name(0) 은 CUDA 가 없으면 RuntimeError 트레이스백을 뿜는다.
#    False 가 나온 사람 화면에 빨간 오류가 쏟아지면 "완전히 실패했다"고 오해한다.
#    지금은 "진단 중"이지 실패가 아니다.

# 한 번에 보는 진단 스크립트
python 01_gpu_check.py
#endregion


#region 블록 3 — 실습 4-(1): CPU 빌드 오설치 "재현"  ★ 2교시
# ---------------------------------------------------------------------
# ★ 일부러 망가뜨린다. 3주차에 가장 많이 겪는 사고를 미리 겪어 두는 것이 목적.
#    이미 is_available() 이 False 인 사람은 이 블록을 건너뛰고 블록 4로 간다.

Set-Location $env:DL2026_HOME
.\venv\Scripts\Activate.ps1

pip install --force-reinstall torch --index-url https://download.pytorch.org/whl/cpu

# --- 오프라인 변형 ----------------------------------------------------
# ★ wheels 폴더에 torch+cpu 휠(약 200MB)이 함께 있어야 한다.
# pip install --no-index --find-links=$W --force-reinstall torch

python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
# -> 2.x.x+cpu   False        <- GPU 는 멀쩡한데 False 가 된다

# 진단: version 한 줄이면 끝난다
python -c "import torch; print('version :', torch.__version__)"
pip list | Select-String "^torch"
# -> torch        2.x.x+cpu
# -> torchvision  0.xx.x+cu124   <- 섞여 있을 수도 있다
#endregion


#region 블록 4 — 실습 4-(2): CUDA 빌드로 "복구"  ★ 2교시
# ---------------------------------------------------------------------
pip uninstall -y torch torchvision
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124

# --- 오프라인 변형 ★★ 반드시 확인할 것 --------------------------------
# 온라인 명령으로 복구하면 25대가 2.5GB 를 "다시" 받는다.
# 1교시에 오프라인으로 피했던 부하가 3교시 직전에 그대로 재발생한다.
#
# pip uninstall -y torch torchvision
# pip install --no-index --find-links=$W torch torchvision

python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
# -> 2.x.x+cu124   True        <- 복구 완료

# ★ 온라인으로 설치했다면 재설치가 빠르다. 1교시에 받은 파일이 pip 캐시에 있기 때문.
#    (오프라인 설치였다면 캐시가 아니라 공유 폴더에서 다시 읽는다. 역시 빠르다.)

# --- 캐시가 꼬여 계속 CPU 빌드가 올 때 --------------------------------
# pip install --force-reinstall --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124
#   -> 2.5GB 를 다시 받는다. 최후의 수단.
# 그래도 안 되면 venv 를 지우고 requirements.txt 로 재생성 (2주차에 연습한 그대로)
#endregion


#region 블록 5 — 과제 마무리: requirements 갱신과 커밋  ★ 3교시
# ---------------------------------------------------------------------
Set-Location $env:DL2026_HOME
.\venv\Scripts\Activate.ps1

pip freeze > requirements.txt          # ★ torch 가 포함되었는지 확인
Select-String "^torch" requirements.txt

# 자가 점검
python verify_week3.py

git add .
git commit -m "week3: pytorch cuda setup + tensor basics"
git push

# ★ requirements.txt 의 torch 줄은 "torch==2.x.x+cu124" 처럼 적힌다.
#    이걸 다른 PC 에서 pip install -r 하면 --index-url 이 없어 실패할 수 있다.
#    해결 방법은 4주차에 다룬다. 오늘은 pip freeze 결과를 그대로 제출한다.
#endregion


#region 블록 6 — 마무리: 공용 PC 를 떠나기 전에 (매주 습관)
# ---------------------------------------------------------------------
cmdkey /list | Select-String "github"
cmdkey /delete:git:https://github.com

git config --global --unset user.name
git config --global --unset user.email
#endregion
