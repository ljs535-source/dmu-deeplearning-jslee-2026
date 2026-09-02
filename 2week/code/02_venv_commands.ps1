# =====================================================================
#  파일: 02_venv_commands.ps1
#  2주차 실습 PowerShell 명령 모음 (블록 1 ~ 13)
# =====================================================================
#
#  ★ 이 파일은 "통째로 실행하는 스크립트"가 아니다. 복습·복사용 참조 파일이다.
#     수업 중에는 02_실습.md 를 보면서 한 줄씩 직접 입력한다.
#     블록별로 필요한 부분만 골라 복사해서 쓸 것.
#
#  실행 위치 : VSCode 통합 터미널(PowerShell) 또는 Windows PowerShell
#  작업 폴더 : 이 파일에 나오는 %DL2026_HOME% 은 "실제 경로가 들어갈 자리"를 뜻하는
#              자리표시자다. 입력하는 명령이 아니다.
#              실습실 PC — 전산 담당자가 미리 만들어 둔 폴더. 실제 경로는 칠판에 공지한다.
#              개인 노트북 — 본인이 정한 경로 (권장: C:\dl2026)
#
# =====================================================================


#region 블록 1 — 실습 0: 사전 점검 (가상환경 만들기 전)
# ---------------------------------------------------------------------
python --version          # 3.13.x 가 나와야 정상
py --list                 # 설치된 파이썬 버전 목록
Get-Command python        # 실행되는 python.exe 의 실제 위치
where.exe python          # 위와 같은 확인. 여러 줄이면 맨 위가 우선한다

# ★ 함정: PowerShell에서 where 는 Where-Object 의 별칭이다.
#          반드시 where.exe 라고 쓰거나 Get-Command 를 쓸 것.
#
# ★ 함정: python 입력 시 Microsoft Store 가 열리면
#          설정 > 앱 > 고급 앱 설정 > 앱 실행 별칭 에서
#          python.exe, python3.exe 를 끌 것.
#endregion

#region 블록 2 — 실습 1: 작업 폴더와 가상환경 생성 · 활성화
# ---------------------------------------------------------------------
# 1) 작업 폴더로 이동
#
#    [실습실 PC] 전산 담당자가 이 과목 전용 폴더를 미리 만들어 두었다.
#                재부팅해도 지워지지 않으며, 실제 경로는 수업 중 칠판에 공지한다.
Set-Location "<공지된 경로>"       # ← 칠판의 경로를 그대로 입력 (예: C:\dl2026)
Get-Location                       # ← 지금 그 폴더에 있는지 확인
Get-ChildItem                      # ← 폴더가 열리면 성공 (비어 있어도 정상)

#    [개인 노트북] 폴더를 직접 만든다. 한 번만 만들면 학기 내내 쓴다.
#                 경로 규칙 — 한글 없음 / 공백 없음 / OneDrive 바깥
#    New-Item -ItemType Directory -Force "C:\dl2026"
#    Set-Location "C:\dl2026"
#
#    ★ 여기서 정한 경로가 여러분의 작업 폴더다.
#      자료에 나오는 %DL2026_HOME% 은 전부 이 경로로 바꿔 읽으면 된다.

# 2) 가상환경 생성 — 버전을 명시하는 습관을 들이자
py -3.13 -m venv venv
# 버전을 콕 집어서 만든다 — python 은 어느 버전이 잡힐지 모른다
# py 런처가 없을 때만:  python -m venv venv

# 3) 만들어진 구조 확인
Get-ChildItem .\venv
Get-Content .\venv\pyvenv.cfg      # 어떤 파이썬으로 만들어졌는지 기록되어 있다

# 4) 활성화
.\venv\Scripts\Activate.ps1
# → 프롬프트가  (venv) PS %DL2026_HOME%>  로 바뀌면 성공
#endregion

#region 블록 3 — 실행 정책(ExecutionPolicy) 오류 3단계 대응
# ---------------------------------------------------------------------
# 증상: Activate.ps1 : 이 시스템에서 스크립트를 실행할 수 없으므로 ... UnauthorizedAccess

# [1단계] 현재 정책 확인
Get-ExecutionPolicy -List

# [2단계] 현재 사용자에게만 허용   ★ 관리자 권한 필요 없음
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Get-ExecutionPolicy -Scope CurrentUser     # RemoteSigned 로 바뀌었는지 확인
.\venv\Scripts\Activate.ps1                # 다시 활성화 시도

# [3단계] 학교 그룹 정책(GPO)으로 MachinePolicy 가 Restricted 라서 2단계가 안 먹힐 때
#
#   방법 A — CMD 로 활성화
#   cmd /c "venv\Scripts\activate.bat && python -c ""import sys; print(sys.executable)"""
#
#   방법 B — 활성화 없이 venv 의 python.exe 를 직접 부른다  ★★ 모든 실습 가능
.\venv\Scripts\python.exe -c "import sys; print(sys.executable)"
.\venv\Scripts\python.exe -m pip install numpy
#
#   ★ 방법 B 는 단순한 우회책이 아니다.
#     "활성화란 결국 PATH 앞쪽에 venv\Scripts 를 끼워 넣어서,
#      python 이라고 쳤을 때 그 파이썬이 실행되게 하는 것"임을 보여 준다.
#endregion


#region 블록 4 — 실습 2: 활성화 검증 3종 + deactivate
# ---------------------------------------------------------------------
where.exe python
# → %DL2026_HOME%\venv\Scripts\python.exe    (첫 줄이 이거면 정상)

python -c "import sys; print(sys.executable)"
# → %DL2026_HOME%\venv\Scripts\python.exe

python -c "import sys; print('prefix     :', sys.prefix); print('base_prefix:', sys.base_prefix); print('venv?      :', sys.prefix != sys.base_prefix)"
# → venv?      : True

pip -V
# → pip 2x.x from %DL2026_HOME%\venv\Lib\site-packages\pip (python 3.13)

$env:VIRTUAL_ENV
# → %DL2026_HOME%\venv

# 진단 스크립트로도 확인 (00_check_env.py 를 %DL2026_HOME% 에 복사해 두었을 때)
python 00_check_env.py

# 비활성화하고 경로가 되돌아가는 것을 눈으로 확인
deactivate
where.exe python
# → 다시 시스템 파이썬 경로

# 다시 활성화
.\venv\Scripts\Activate.ps1
#endregion


#region 블록 5 — 실습 3: 삭제 · 재생성 드릴 (임시 환경 tmpvenv 로)
# ---------------------------------------------------------------------
# ★ 메인 venv 가 아니라 가벼운 tmpvenv 로 연습한다. 시간이 오래 걸리지 않는다.
Set-Location "<작업 폴더>"                   # ← 실습 1에서 확인한 그 경로
deactivate                                  # 메인 venv 가 켜져 있으면 먼저 끈다

py -3.13 -m venv tmpvenv
.\tmpvenv\Scripts\Activate.ps1
pip install requests                        # 의존성 포함 몇 초
pip freeze > requirements_tmp.txt
Get-Content requirements_tmp.txt            # requests 외 4줄 정도
deactivate

Remove-Item -Recurse -Force .\tmpvenv       # 통째로 삭제 — 겁먹지 말 것

py -3.13 -m venv tmpvenv                    # 재생성
.\tmpvenv\Scripts\Activate.ps1
pip list                                    # 텅 비어 있음
pip install -r requirements_tmp.txt         # 복원
pip list                                    # 원래대로 돌아옴  ★
deactivate

Remove-Item -Recurse -Force .\tmpvenv       # 정리
Remove-Item .\requirements_tmp.txt

# ★ 결론: requirements.txt 한 파일만 있으면 환경은 언제든 다시 만들 수 있는 소모품이다.
#
# ★ 함정: Remove-Item 이 "다른 프로세스에서 사용 중"이라며 실패하면
#          deactivate 를 안 했거나, 탐색기·다른 터미널 창이 그 폴더를 잡고 있는 것이다.
#          새 터미널을 열고 다시 시도할 것.
#          (2교시 이후로는 JupyterLab 이 켜져 있는 것이 가장 흔한 원인이다.)
#endregion


#region 블록 6 — 실습 4·5: 패키지 설치와 목록 관리
# ---------------------------------------------------------------------
Set-Location "<작업 폴더>"                   # ← 실습 1에서 확인한 그 경로
.\venv\Scripts\Activate.ps1

python -m pip install --upgrade pip         # pip 자신을 올릴 땐 python -m pip

pip install jupyterlab ipykernel numpy pandas matplotlib humanize
# ★ 오늘은 torch 를 설치하지 않는다. PyTorch·CUDA 는 3주차에 한다.

pip list                                    # 사람이 읽는 목록
pip show pandas                             # 위치·의존성 상세
pip freeze > requirements.txt               # 재현용 고정 목록 (== 로 버전 고정)
Get-Content requirements.txt

# ★ pip list 는 보기용, pip freeze 는 재현용.
# ★ 환경이 헷갈릴 땐 pip 대신 python -m pip 을 쓰면 확실하다.
#endregion


#region 블록 7 — 실습 6: 주피터에 내 가상환경을 커널로 등록
# ---------------------------------------------------------------------
python -m ipykernel install --user --name dl2026 --display-name "Python (dl2026)"

jupyter kernelspec list
# Available kernels:
#   dl2026     C:\Users\<사용자>\AppData\Roaming\jupyter\kernels\dl2026
#   python3    C:\...\share\jupyter\kernels\python3

# ★ 등록의 정체를 눈으로 확인한다 — kernel.json 을 직접 열어 본다
Get-Content "$env:APPDATA\jupyter\kernels\dl2026\kernel.json"
# {
#   "argv": ["C:\\dl2026\\venv\\Scripts\\python.exe", "-m", "ipykernel_launcher", ...],
#   "display_name": "Python (dl2026)",
#   ...
# }
#
# ★ 커널 등록 = "이 이름을 고르면 이 python.exe 로 실행해라"는 메모 한 장을 남기는 것.
#   argv 의 첫 항목이 우리 venv 의 python.exe 인지 반드시 확인할 것.

# 참고: 커널을 지우려면
# jupyter kernelspec uninstall dl2026


# --- 4-4. 실습 8에서 쓸 "틀린 커널" 을 미리 하나 만들기 ★ -------------------
#
# 실습 8에서는 커널을 일부러 잘못 골라 ModuleNotFoundError 를 재현한다.
# 그러려면 humanize 가 "없는" 다른 환경의 커널이 목록에 있어야 한다.
# 지금 1분만 들여 만들어 둔다. (jupyter lab 을 띄우기 전, 이 터미널에서 이어서)

# 일부러 틀린 커널 만들기 — humanize 가 없는 별도 환경
Set-Location "<작업 폴더>"                   # ← 실습 1에서 확인한 그 경로
py -3.13 -m venv wrongvenv
.\wrongvenv\Scripts\python.exe -m pip install ipykernel
.\wrongvenv\Scripts\python.exe -m ipykernel install --user --name wrong2026 --display-name "Python (다른환경)"

jupyter kernelspec list
# → dl2026      ... \kernels\dl2026
# → wrong2026   ... \kernels\wrong2026     ← 새로 생겼다

# ★ 원리는 블록 7 앞부분과 똑같다.
#   활성화 대신 python.exe 경로를 직접 불렀으므로,
#   이 커널의 argv[0] 은 wrongvenv 의 python.exe 가 된다.
#
# ★ ipykernel 은 방금 메인 venv 에 받으면서 pip 캐시에 남아 있어 재다운로드가 없다.
#
# ★ 뒷정리는 3교시 마지막(블록 13)에서 한다. 지금 지우지 말 것.
#   3교시 .gitignore 실습에서 wrongvenv/ 가 git status 에 나오는 것을 봐야 하므로
#   그때까지 남겨 둔다.
#endregion


#region 블록 8 — 실습 7: JupyterLab 실행
# ---------------------------------------------------------------------
Set-Location "<작업 폴더>"                   # ← 실습 1에서 확인한 그 경로
.\venv\Scripts\Activate.ps1                 # ★ 반드시 활성화된 상태에서 실행
jupyter lab
# → 브라우저가 자동으로 열린다.
#   안 열리면 터미널에 찍힌 http://localhost:8888/lab?token=... 을 복사해서 붙여넣는다.
#   종료: 이 터미널에서 Ctrl+C 를 두 번

# 포트가 이미 쓰이고 있다면
# jupyter lab --port 8889
#endregion


#region 블록 9 — 실습 10-(1): 저장소 초기화와 "before" 상태 확인
# ---------------------------------------------------------------------
# ★ 순서가 중요하다. .gitignore 를 만들기 "전에" 먼저 상태를 본다.
#   (1) 이 블록      : git init 후 git status  → venv/ 가 목록에 보인다 (수천 개 파일)
#   (2) 블록 10      : .gitignore 생성
#   (3) 블록 10 끝   : 다시 git status         → venv/ 가 사라진다

Set-Location "<작업 폴더>"                   # ← 실습 1에서 확인한 그 경로

git init

# ★ 신원은 이 저장소에만 넣는다 (--local). 아래 두 줄을 본인 것으로 고칠 것.
#
#   우리 컴퓨터실은 모든 학생이 같은 Windows 계정을 쓴다.
#   --global 로 넣으면 %USERPROFILE%\.gitconfig 에 저장되어 다음 사람에게 새고,
#   그 사람 커밋이 내 이름 / 내 잔디로 조용히 기록된다.
#   --local 은 이 저장소의 .git/config, 즉 내 전용 폴더 안에만 남는다.
#
#   저장소를 새로 만들 때마다 매번 필요하다. 빠뜨리면 git commit 이
#   "fatal: no email was given and auto-detection is disabled" 로 멈춘다. (정상)
git config --local user.name  "Hong Gildong"
git config --local user.email "본인GitHub이메일@example.com"

git config --local user.email               # ← 본인 이메일이 나오면 통과

git status
# ★ 이 시점에는 venv/ 가 목록에 "있어야" 정상이다. 이걸 보는 것이 실습의 목적.
#endregion


#region 블록 10 — 실습 10-(2): .gitignore 만들고 "after" 확인
# ---------------------------------------------------------------------
Set-Location "<작업 폴더>"                   # ← 실습 1에서 확인한 그 경로

@'
venv/
tmpvenv/
wrongvenv/
__pycache__/
*.pyc
.ipynb_checkpoints/
.env
data/
*.pth
*.pt
'@ | Out-File -FilePath .gitignore -Encoding ascii

Get-Content .gitignore

git status
# ★ 이제 venv/ 가 목록에서 사라진 것을 확인할 것

# ★ -Encoding ascii 를 쓴다. Windows PowerShell 5.1 의 -Encoding utf8 은 BOM 을 붙이는데,
#   내용이 전부 영문이므로 ascii 가 가장 안전하다.
#endregion


#region 블록 11 — 실습 12: 첫 커밋과 push
# ---------------------------------------------------------------------
# 먼저 GitHub 웹에서 저장소를 만든다.
#   github.com > 우상단 + > New repository
#   Repository name : deeplearning-study-2026
#   Public 선택
#   ★★ "Add a README file" 체크 해제, .gitignore·license 는 None
#   Create repository

git add .
git status                                  # 초록색 목록 확인
git commit -m "week2: venv + jupyterlab kernel setup"
git log --oneline
git branch -M main

git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git
git remote -v

git push -u origin main
# → Git Credential Manager 창이 뜬다
#   "Sign in with your browser" 클릭 > GitHub 로그인 > Authorize
#   창이 닫히면 터미널에서 push 가 완료된다
#endregion


#region 블록 11-b — GCM 창이 안 뜰 때 (막힌 사람만)
# ---------------------------------------------------------------------
# ★ 위에서부터 하나씩. 대부분 [2] 에서 끝난다.
#
# [1] 진단 — 화면에 무엇이 나왔는지 먼저 본다
#     "Username for 'https://github.com':"  → helper 가 없다.        [2] 로
#     아무 반응 없이 멈춰 있다              → 창이 뒤에 숨었다. Alt+Tab ★
#     "fatal: Authentication failed" 즉시   → 잘못된 자격 증명 저장됨. [4] 로

# [2] credential.helper 설정 — 가장 흔한 해결
git config --global credential.helper        # 아무것도 안 나오면 이게 문제
git config --global credential.helper manager
#   Git for Windows 2.39 미만이면 manager 대신 manager-core 를 쓴다:
#   git config --global credential.helper manager-core

# [3] GCM 이 실제로 설치돼 있는지 확인
git credential-manager --version             # → 2.6.x 처럼 버전이 나오면 정상
#   ★ where.exe 로는 찾지 못하는 것이 정상이다. GCM 실행 파일은
#     C:\Program Files\Git\mingw64\bin 에 있는데 이 폴더는 PATH 에 없고,
#     git 이 자체 exec-path 에서 찾아 실행하기 때문이다.
#   'is not a git command' 가 나오면 Git for Windows 재설치가 필요하다.
#   수업 중에는 시간이 없으므로 [5] PAT 폴백으로 넘어간다.

# [4] 저장된 잘못된 자격 증명 지우고 재시도
#     ★ 아래 git:https://github.com 은 "내 저장소 주소"가 아니라
#       Windows 자격 증명 관리자의 항목 이름이다. 그대로 쓰면 된다.
cmdkey /list | Select-String "github"        # 먼저 실제 이름을 확인
cmdkey /delete:git:https://github.com
git push -u origin main

# [4-b] 창이 끝내 안 뜨면 — GUI 대신 터미널에서 묻게 한다
git config --global credential.guiPrompt false
git push -u origin main

# [5] 최후 폴백 — PAT (개인 접근 토큰)
#     GitHub > Settings > Developer settings
#       > Personal access tokens > Tokens (classic) > Generate new token
#       scope 는 repo 하나만, 만료 90일
#     push 시  Username: GitHub 아이디 / Password: 토큰 붙여넣기
#     ★ 붙여넣어도 화면에 아무것도 안 보이는 것이 정상이다. 그대로 Enter.
#     ★ 토큰은 발급 화면을 벗어나면 다시 볼 수 없다.
#     ★ 공용 PC 이므로 수업 끝에 블록 13 의 cmdkey /delete 를 반드시 실행할 것.
#endregion


#region 블록 12 — 실습 13: 수정 → 커밋 → push (반복 사이클)
# ---------------------------------------------------------------------
git status                                  # → modified: 01_env_check.ipynb
git add 01_env_check.ipynb
git commit -m "add environment verification output"
git push                                    # -u 를 준 뒤에는 이것만으로 충분
#endregion


#region 블록 13 — 마무리: 공용 PC 를 떠나기 전에 반드시
# ---------------------------------------------------------------------
cmdkey /list | Select-String "github"
cmdkey /delete:git:https://github.com

# 혹시 --global 에 신원이 들어갔다면 청소한다 (없으면 그냥 넘어간다).
# 신원은 실습 10에서 --local 로 넣었으므로 보통은 여기에 아무것도 없다.
git config --global --unset-all user.name  2>$null
git config --global --unset-all user.email 2>$null

# ★ user.useConfigOnly 는 지우지 않는다.
#   신원이 비었을 때 Git 이 값을 지어내지 못하게 막는 안전핀이라,
#   남겨 두는 것이 다음에 이 PC 를 쓰는 사람을 보호한다.

# 2교시 실습 6에서 만든 "틀린 커널" 뒷정리 — 3교시까지 쓰고 이제 지운다.
# (3교시 .gitignore 예시에 wrongvenv/ 가 나오므로 그때까지는 남겨 둔다)
jupyter kernelspec uninstall wrong2026
Remove-Item -Recurse -Force .\wrongvenv

# ★ 공용 PC 에 GitHub 자격 증명을 남기고 나가면
#   다음 사람이 여러분 계정으로 커밋할 수 있다. 매주 습관으로 만들 것.
#
# GUI 경로: 제어판 > 사용자 계정 > 자격 증명 관리자 > Windows 자격 증명
#           > git:https://github.com 제거
#endregion
