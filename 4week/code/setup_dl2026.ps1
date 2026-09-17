# =====================================================================
#  파일: setup_dl2026.ps1
#  PC 초기화 후 실습 환경 재구성 (4주차 수업 시작 전)
# =====================================================================
#
#  DL2026_HOME = 이 스크립트가 놓인 폴더 (스크립트 안에서만 쓰는 임시 변수.
#                시스템 환경변수로 등록하지 않는다)
#
#  자동으로 하는 일
#    1) DL2026_HOME 확인
#    2) 새로 만들 폴더 이름을 입력받아 DL2026_HOME 아래에 생성
#    3) python -m venv venv  ->  활성화
#    4) Git 저장소 설정 (venv 가 있는 작업 폴더 = 저장소)
#         git init  ->  이름 · 이메일 입력 (--local)  ->  원격 주소(origin) 입력
#         ->  원격에 main 이 있으면 내려받기  ->  .gitignore 생성 (venv/ 등 제외)
#    5) 2주차에 설치한 패키지 설치
#         jupyterlab ipykernel numpy pandas matplotlib humanize
#
#  입력은 1~4 단계에서 모두 받는다. 5단계(수 분)부터는 기다리기만 하면 된다.
#
#  명령어만 안내하는 일 (직접 입력)
#    활성화 · PyTorch 설치(3주차) · 주피터 커널 등록 · Git 공용 PC 설정(--global)
#    · 저장소 확인/첫 push · JupyterLab 실행 · 뒷정리
#
#  실행 방법
#    (권장) 이 파일과 setup_dl2026.bat 를 작업 기준 폴더에 복사한 뒤
#           setup_dl2026.bat 더블클릭          <- 실행 정책 오류를 피한다
#    또는   powershell -ExecutionPolicy Bypass -File .\setup_dl2026.ps1
# =====================================================================

$PKG_WEEK2     = @("jupyterlab", "ipykernel", "numpy", "pandas", "matplotlib", "humanize")
$TORCH_INSTALL = "pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126"

# .gitignore 내용 — 2주차 gitignore_template.txt 와 같다
$GITIGNORE_LINES = @(
    "# 가상환경 — 절대 커밋하지 않는다. requirements.txt 로 재현한다.",
    "venv/", "tmpvenv/", "wrongvenv/", ".venv/",
    "",
    "# 파이썬 캐시",
    "__pycache__/", "*.pyc", "*.pyo",
    "",
    "# 주피터 체크포인트",
    ".ipynb_checkpoints/",
    "",
    "# 환경변수·비밀키",
    ".env",
    "",
    "# 데이터셋 (용량이 크다)",
    "data/", "datasets/",
    "",
    "# 학습된 모델 가중치 (용량이 크다)",
    "*.pth", "*.pt", "*.ckpt", "*.safetensors",
    "",
    "# OS·에디터가 만드는 파일",
    "Thumbs.db", "desktop.ini", ".DS_Store", ".vscode/"
)
# .gitignore 가 이미 있을 때(원격에서 내려받은 경우 등) 빠져 있으면 덧붙이는 최소 항목
$GITIGNORE_REQUIRED = @("venv/", "__pycache__/", ".ipynb_checkpoints/", ".env")

function Write-Step($n, $msg) {
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host ("  [{0}] {1}" -f $n, $msg) -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
}

function Stop-Setup($msg) {
    Write-Host ""
    Write-Host ("[중단] " + $msg) -ForegroundColor Red
    exit 1
}


# --- 1. DL2026_HOME 확인 ----------------------------------------------
Write-Step 1 "작업 기준 폴더 (DL2026_HOME) 확인"

$DL2026_HOME = $PSScriptRoot
Write-Host ("  DL2026_HOME = " + $DL2026_HOME)

# 쓰기 권한 확인
$probe = Join-Path $DL2026_HOME "_writetest"
try {
    New-Item -ItemType Directory -Path $probe -Force -ErrorAction Stop | Out-Null
    Remove-Item $probe -Force -ErrorAction Stop
} catch {
    Stop-Setup ("이 폴더에 쓸 수 없습니다: " + $DL2026_HOME)
}


# --- 2. 폴더 이름 입력 · 생성 -----------------------------------------
Write-Step 2 "만들 폴더 이름 입력"
Write-Host "  규칙 : 영문 · 숫자 · _ · - 만 사용 (한글 · 공백 불가)"
Write-Host "  예시 : 20261234_hong"

while ($true) {
    Write-Host ""
    $FolderName = (Read-Host "  폴더 이름").Trim()

    if (-not $FolderName) {
        Write-Host "  이름을 입력하세요." -ForegroundColor Yellow
        continue
    }
    if ($FolderName -notmatch '^[A-Za-z0-9_-]+$') {
        Write-Host "  한글 · 공백 · 특수문자는 쓸 수 없습니다. 다시 입력하세요." -ForegroundColor Yellow
        continue
    }

    $WorkDir = Join-Path $DL2026_HOME $FolderName
    if (Test-Path $WorkDir) {
        Write-Host ("  이미 있는 폴더입니다: " + $WorkDir) -ForegroundColor Yellow
        $ans = Read-Host "  이 폴더를 그대로 사용할까요? (y/n)"
        if ($ans -ne "y") { continue }
    }
    break
}

# Windows 경로 길이 제한(260자) — venv 안의 가장 깊은 파일은 작업 폴더 뒤로 120자 가량 더 붙는다
if ($WorkDir.Length -gt 120) {
    Write-Host ("  [경고] 작업 폴더 경로가 깁니다 ({0}자). 설치 중 '파일 이름이나 확장명이 너무 깁니다' 오류가 날 수 있습니다." -f $WorkDir.Length) -ForegroundColor Yellow
    Write-Host "         C:\dl2026 처럼 짧은 경로에 스크립트를 두고 실행하세요."
    $ans = Read-Host "  그래도 계속할까요? (y/n)"
    if ($ans -ne "y") { Stop-Setup "사용자가 중단함" }
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Set-Location $WorkDir
Write-Host ("  작업 폴더 : " + $WorkDir) -ForegroundColor Green


# --- 3. 가상환경 생성 · 활성화 ----------------------------------------
Write-Step 3 "가상환경 생성 (python -m venv venv) 과 활성화"

$pyVer = & python -c "import sys; print('%d.%d.%d' % sys.version_info[:3])"
if ($LASTEXITCODE -ne 0 -or -not $pyVer) {
    Write-Host "  python 을 실행할 수 없습니다." -ForegroundColor Red
    Write-Host "  - Microsoft Store 가 열렸다면: 설정 > 앱 > 고급 앱 설정 > 앱 실행 별칭 에서 python.exe 끄기"
    Write-Host "  - 설치되어 있지 않다면: Python 3.13 설치 후 다시 실행"
    Stop-Setup "python 없음"
}
Write-Host ("  python 버전 : " + $pyVer)

if (-not $pyVer.StartsWith("3.13.")) {
    Write-Host "  [경고] 수업 기준 버전은 3.13.x 입니다." -ForegroundColor Yellow
    Write-Host "         py 런처가 있다면 중단 후 직접:  py -3.13 -m venv venv"
    $ans = Read-Host "  이 버전으로 계속할까요? (y/n)"
    if ($ans -ne "y") { Stop-Setup "사용자가 중단함" }
}

$VenvPy = Join-Path $WorkDir "venv\Scripts\python.exe"

if (Test-Path $VenvPy) {
    Write-Host "  이 폴더에 venv 가 이미 있습니다." -ForegroundColor Yellow
    $ans = Read-Host "  지우고 새로 만들까요? (y: 새로 만들기 / n: 그대로 사용)"
    if ($ans -eq "y") {
        try {
            Remove-Item -Recurse -Force (Join-Path $WorkDir "venv") -ErrorAction Stop
        } catch {
            Stop-Setup "venv 를 지울 수 없습니다. JupyterLab · 다른 터미널 · 탐색기를 닫고 다시 실행하세요."
        }
    }
}

if (-not (Test-Path $VenvPy)) {
    Write-Host "  python -m venv venv  실행 중..."
    & python -m venv venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $VenvPy)) {
        Stop-Setup "가상환경 생성 실패"
    }
}

# 활성화 (이 스크립트 안에서만 유지된다. 끝난 뒤에는 터미널에서 다시 활성화해야 한다)
try {
    . (Join-Path $WorkDir "venv\Scripts\Activate.ps1")
    Write-Host ("  활성화 완료 : VIRTUAL_ENV = " + $env:VIRTUAL_ENV) -ForegroundColor Green
} catch {
    Write-Host "  [경고] Activate.ps1 실행이 막혔습니다 (실행 정책)." -ForegroundColor Yellow
    Write-Host "         venv 의 python.exe 를 직접 불러서 계속 설치합니다."
}

# 설치는 항상 venv 의 python.exe 로 한다 -> 활성화 여부와 무관하게 설치 위치가 확실하다
$exe = & $VenvPy -c "import sys; print(sys.executable)"
Write-Host ("  설치 대상 python : " + $exe)


# --- 4. Git 저장소 설정 -----------------------------------------------
# venv 가 있는 작업 폴더를 그대로 Git 저장소로 쓴다 (2주차 실습 10 · 12 와 같은 구성)
Write-Step 4 "Git 저장소 설정 (git init · 이름/이메일 · 원격 주소 · .gitignore)"

$GitOk     = $false
$RemoteUrl = ""
$GitPulled = "none"     # pulled: 원격 main 내려받음 / empty: 원격이 비어 있음 / failed: 못 가져옴 / existing: 이미 커밋 있음

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  [경고] git 을 찾을 수 없어 이 단계를 건너뜁니다." -ForegroundColor Yellow
    Write-Host "         Git for Windows 설치 후 이 스크립트를 다시 실행하면 이어서 설정됩니다."
    Write-Host "         (같은 폴더 이름 입력 -> venv 는 'n: 그대로 사용')   https://git-scm.com/download/win"
} else {
    $GitOk = $true
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    # git 이 돌려주는 한글(이름 등)이 깨지지 않게 이 단계 동안만 UTF-8 로 읽는다
    $prevOutEnc = $null
    try { $prevOutEnc = [Console]::OutputEncoding; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

    # (4-1) 저장소 만들기
    Write-Host "  (4-1) git init"
    if (Test-Path (Join-Path $WorkDir ".git")) {
        Write-Host "  이미 Git 저장소입니다. 초기화는 건너뜁니다."
    } else {
        & git init
        if ($LASTEXITCODE -ne 0) { Stop-Setup "git init 실패" }
        & git symbolic-ref HEAD refs/heads/main    # 첫 브랜치 이름을 main 으로 (GitHub 기본값과 같게)
    }

    # (4-2) 신원 — 공용 PC 이므로 반드시 --local
    Write-Host ""
    Write-Host "  (4-2) 이 저장소에만 쓸 이름 · 이메일 (--local)"
    Write-Host "        공용 PC 이므로 --global 에는 넣지 않습니다."
    Write-Host "        이메일은 GitHub 에 등록한 주소여야 커밋이 내 잔디(Contributions)에 기록됩니다."

    $cur = & git config --local user.name
    $keep = $false
    if ($cur) {
        Write-Host ("  현재 이름 : " + $cur)
        $keep = ((Read-Host "  그대로 사용할까요? (y/n)").Trim() -eq "y")
    }
    if (-not $keep) {
        while ($true) {
            $GitName = (Read-Host "  이름 (예: Hong Gildong)").Trim()
            if (-not $GitName) { Write-Host "  이름을 입력하세요." -ForegroundColor Yellow; continue }
            if ($GitName.Contains('"')) { Write-Host '  큰따옴표(")는 쓸 수 없습니다.' -ForegroundColor Yellow; continue }
            break
        }
        & git config --local user.name $GitName
        if ($LASTEXITCODE -ne 0) { Stop-Setup "user.name 설정 실패" }
    }

    $cur = & git config --local user.email
    $keep = $false
    if ($cur) {
        Write-Host ("  현재 이메일 : " + $cur)
        $keep = ((Read-Host "  그대로 사용할까요? (y/n)").Trim() -eq "y")
    }
    if (-not $keep) {
        while ($true) {
            $GitEmail = (Read-Host "  GitHub 이메일").Trim()
            if ($GitEmail -notmatch '^[^@\s"]+@[^@\s"]+\.[^@\s"]+$') { Write-Host "  이메일 형식이 아닙니다. 다시 입력하세요." -ForegroundColor Yellow; continue }
            if ($GitEmail -match '@example\.com$') { Write-Host "  예시 주소입니다. 본인 GitHub 이메일을 입력하세요." -ForegroundColor Yellow; continue }
            break
        }
        & git config --local user.email $GitEmail
        if ($LASTEXITCODE -ne 0) { Stop-Setup "user.email 설정 실패" }
    }

    # (4-3) 원격 저장소 주소 (origin)
    Write-Host ""
    Write-Host "  (4-3) GitHub 원격 저장소 주소 (origin)"
    Write-Host "        GitHub 저장소 페이지 > 초록색 [Code] 버튼 > HTTPS 주소 복사"
    Write-Host "        예: https://github.com/<본인아이디>/deeplearning-study-2026.git"
    Write-Host "        GitHub 에 아직 저장소가 없으면 그냥 Enter (나중에 연결)"

    $cur = & git config --local --get remote.origin.url
    $RemoteUrl = "$cur"
    $askUrl = $true
    if ($cur) {
        Write-Host ("  현재 origin : " + $cur)
        if ((Read-Host "  그대로 사용할까요? (y/n)").Trim() -eq "y") { $askUrl = $false }
    }
    if ($askUrl) {
        while ($true) {
            $u = (Read-Host "  원격 주소").Trim()
            if (-not $u) { break }
            if ($u -match '[<>]' -or $u.Contains("본인아이디")) {
                Write-Host "  예시를 그대로 넣었습니다. <본인아이디> 를 실제 GitHub 아이디로 바꾸세요." -ForegroundColor Yellow
                continue
            }
            if ($u -notmatch '^(https://|git@)\S+$') {
                Write-Host "  https:// 로 시작하는 주소를 입력하세요." -ForegroundColor Yellow
                continue
            }
            $RemoteUrl = $u
            break
        }
        if ($RemoteUrl -and $RemoteUrl -ne "$cur") {
            if ($cur) { & git remote set-url origin $RemoteUrl } else { & git remote add origin $RemoteUrl }
            if ($LASTEXITCODE -ne 0) { Stop-Setup "원격 주소 설정 실패" }
        }
    }

    # (4-4) 원격에 지난주까지의 커밋이 있으면 내려받는다
    #       .gitignore 를 만들기 "전에" 해야 원격의 .gitignore 와 겹쳐 멈추지 않는다
    & git rev-parse --verify --quiet HEAD | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $GitPulled = "existing"
    } elseif ($RemoteUrl) {
        Write-Host ""
        Write-Host "  (4-4) 원격 저장소 내용 가져오기 (git fetch)"
        $env:GIT_TERMINAL_PROMPT = "0"                 # 로그인 창 · 암호 질문 없이 시도만 한다
        & git -c credential.helper= fetch origin
        $fetchCode = $LASTEXITCODE
        Remove-Item Env:\GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
        if ($fetchCode -ne 0) {
            $GitPulled = "failed"
            Write-Host "  [경고] 가져오지 못했습니다 (주소 오타 · 비공개 저장소 · 네트워크). 아래 안내 ⑤ 에서 직접 가져옵니다." -ForegroundColor Yellow
        } else {
            & git rev-parse --verify --quiet refs/remotes/origin/main | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $GitPulled = "empty"
                Write-Host "  원격 저장소가 비어 있습니다 (main 브랜치 없음). 첫 커밋 후 push 하면 됩니다."
            } else {
                & git checkout -B main --track origin/main
                if ($LASTEXITCODE -eq 0) {
                    $GitPulled = "pulled"
                    Write-Host "  원격 저장소의 main 을 내려받았습니다 (origin/main 추적)." -ForegroundColor Green
                } else {
                    $GitPulled = "failed"
                    Write-Host "  [경고] 폴더에 원격과 같은 이름의 파일이 있어 내려받지 못했습니다. 아래 안내 ⑤ 를 따르세요." -ForegroundColor Yellow
                }
            }
        }
    }

    # (4-5) .gitignore — venv 등 올리면 안 되는 것을 제외한다
    Write-Host ""
    Write-Host "  (4-5) .gitignore (venv/ 등을 Git 에서 제외)"
    $gi = Join-Path $WorkDir ".gitignore"
    if (Test-Path $gi) {
        $have = @(Get-Content $gi -Encoding UTF8 | ForEach-Object { $_.Trim().Trim('/') })
        $missing = @($GITIGNORE_REQUIRED | Where-Object { $have -notcontains $_.Trim('/') })
        if ($missing.Count -eq 0) {
            Write-Host "  이미 있고, 꼭 필요한 항목(venv/ 등)이 모두 들어 있습니다."
        } else {
            $raw = [System.IO.File]::ReadAllText($gi)
            $add = "# setup_dl2026 이 추가한 항목`r`n" + ($missing -join "`r`n") + "`r`n"
            if ($raw.Length -gt 0 -and -not $raw.EndsWith("`n")) { $add = "`r`n" + $add }
            [System.IO.File]::AppendAllText($gi, $add, $utf8NoBom)
            Write-Host ("  기존 .gitignore 에 빠진 항목을 추가했습니다: " + ($missing -join " ")) -ForegroundColor Green
        }
    } else {
        [System.IO.File]::WriteAllText($gi, (($GITIGNORE_LINES -join "`r`n") + "`r`n"), $utf8NoBom)
        Write-Host "  .gitignore 를 만들었습니다 (2주차 gitignore_template.txt 와 같은 내용)" -ForegroundColor Green
    }

    # (4-6) 결과 확인
    Write-Host ""
    Write-Host "  (4-6) 확인"
    $o = & git config --local --get remote.origin.url
    if (-not $o) { $o = "(없음 - 나중에 연결)" }
    Write-Host ("  user.name  : " + (& git config --local user.name))
    Write-Host ("  user.email : " + (& git config --local user.email))
    Write-Host ("  origin     : " + $o)
    Write-Host ("  branch     : " + (& git branch --show-current))
    & git check-ignore -q venv
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  venv/      : Git 에서 제외됨 (정상)" -ForegroundColor Green
    } else {
        Write-Host "  [경고] venv 가 Git 에서 제외되지 않습니다. .gitignore 를 확인하세요." -ForegroundColor Yellow
    }

    if ($prevOutEnc) { try { [Console]::OutputEncoding = $prevOutEnc } catch {} }
}


# --- 5. 패키지 설치 (2주차) -------------------------------------------
Write-Step 5 "패키지 설치 (2주차)"

Write-Host "  (5-1) pip 업그레이드"
& $VenvPy -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { Stop-Setup "pip 업그레이드 실패 (네트워크 확인)" }

Write-Host ""
Write-Host ("  (5-2) " + ($PKG_WEEK2 -join " "))
& $VenvPy -m pip install @PKG_WEEK2
if ($LASTEXITCODE -ne 0) { Stop-Setup "2주차 패키지 설치 실패" }

Write-Host ""
Write-Host "  (5-3) 설치 확인"
& $VenvPy -c "import jupyterlab, ipykernel, numpy, pandas, matplotlib, humanize; print('jupyterlab :', jupyterlab.__version__); print('numpy      :', numpy.__version__); print('pandas     :', pandas.__version__); print('matplotlib :', matplotlib.__version__)"
if ($LASTEXITCODE -ne 0) { Stop-Setup "import 확인 실패" }


# --- 6. 나머지 설정 : 명령어 안내 -------------------------------------
$line = "============================================================"
Write-Host ""
Write-Host $line -ForegroundColor Green
Write-Host "  자동 설치 완료. 아래 명령을 VSCode 터미널에서 순서대로 직접 입력하세요." -ForegroundColor Green
Write-Host $line -ForegroundColor Green

Write-Host ""
Write-Host "  ① 작업 폴더로 이동 + 가상환경 활성화  (스크립트가 끝나면 활성화는 풀립니다)" -ForegroundColor Cyan
Write-Host ('      Set-Location "' + $WorkDir + '"')
Write-Host '      .\venv\Scripts\Activate.ps1'
Write-Host '      # 실행 정책 오류가 나면:'
Write-Host '      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser'

Write-Host ""
Write-Host "  ② PyTorch 설치 (3주차)  ★ 프롬프트 앞에 (venv) 가 보이는 상태에서" -ForegroundColor Cyan
Write-Host ('      ' + $TORCH_INSTALL)
Write-Host '      # 약 2.5GB, 5~20분. 터미널을 닫지 마세요.'
Write-Host '      python -c "import torch; print(torch.__version__, torch.cuda.is_available())"'
Write-Host '      # -> 2.x.x+cu126 True 가 나오면 성공 (+cpu 또는 False 면 손을 들어 알리기)'

Write-Host ""
Write-Host "  ③ 주피터 커널 등록" -ForegroundColor Cyan
Write-Host '      python -m ipykernel install --user --name dl2026 --display-name "Python (dl2026)"'
Write-Host '      jupyter kernelspec list'

Write-Host ""
Write-Host "  ④ Git 공용 PC 설정 (이름/이메일은 여기서 넣지 않습니다)" -ForegroundColor Cyan
Write-Host '      git config --global init.defaultBranch main'
Write-Host '      git config --global core.autocrlf true'
Write-Host '      git config --global core.quotepath false'
Write-Host '      git config --global user.useConfigOnly true'
Write-Host '      git config --global credential.helper manager'

Write-Host ""
if (-not $GitOk) {
    Write-Host "  ⑤ Git 저장소 설정 (git 이 없어 4단계를 건너뛰었습니다 — Git 설치 후 이 스크립트를 다시 실행해도 됩니다)" -ForegroundColor Cyan
    Write-Host '      git init'
    Write-Host '      git config --local user.name  "Hong Gildong"'
    Write-Host '      git config --local user.email "본인GitHub이메일@example.com"'
    Write-Host '      git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git'
    Write-Host '      git pull origin main'
    Write-Host '      git branch -u origin/main'
} elseif (-not $RemoteUrl) {
    Write-Host "  ⑤ GitHub 저장소 연결 (4단계에서 원격 주소를 건너뛰었습니다)" -ForegroundColor Cyan
    Write-Host '      git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git'
    Write-Host '      git pull origin main          # 저장소에 지난주까지의 커밋이 있는 경우'
    Write-Host '      git branch -u origin/main'
    Write-Host '      # GitHub 에 저장소가 없는 사람: 2주차 02_venv_commands.ps1 블록 11 을 따라 만들고 첫 push'
} elseif ($GitPulled -eq "pulled") {
    Write-Host "  ⑤ GitHub 저장소 확인 (4단계에서 원격 main 을 내려받았습니다)" -ForegroundColor Cyan
    Write-Host '      git status                    # .gitignore 에 항목을 덧붙였다면 modified 로 보입니다 (다음 커밋에 함께)'
    Write-Host '      git log --oneline -3          # 지난주까지의 커밋이 보이면 성공'
} elseif ($GitPulled -eq "empty") {
    Write-Host "  ⑤ 첫 커밋과 push (원격 저장소가 비어 있습니다)" -ForegroundColor Cyan
    Write-Host '      git add .'
    Write-Host '      git status                    # venv 가 목록에 없어야 정상'
    Write-Host '      git commit -m "week4: environment setup"'
    Write-Host '      git push -u origin main       # GitHub 로그인 창이 뜨면 로그인'
} elseif ($GitPulled -eq "existing") {
    Write-Host "  ⑤ GitHub 저장소 확인 (이미 커밋이 있는 저장소입니다)" -ForegroundColor Cyan
    Write-Host '      git status'
    Write-Host '      git pull origin main'
} else {
    Write-Host "  ⑤ 원격 저장소 내려받기 (4단계에서 가져오지 못했습니다)" -ForegroundColor Cyan
    Write-Host '      git remote -v                 # 주소 오타 확인 (고치기: git remote set-url origin <주소>)'
    Write-Host '      git pull origin main          # GitHub 로그인 창이 뜨면 로그인'
    Write-Host '      git branch -u origin/main'
    Write-Host '      # "untracked working tree files would be overwritten" 로 멈추면: 목록에 나온 파일을 다른 이름으로 옮기고 다시 pull'
    Write-Host '      #   예) .gitignore 가 겹친 경우 — 원격의 .gitignore 를 쓰게 된다'
    Write-Host '      Rename-Item .gitignore .gitignore.bak'
    Write-Host '      git pull origin main'
    Write-Host '      Remove-Item .gitignore.bak    # 원격에서 받은 .gitignore 를 씁니다'
}

Write-Host ""
Write-Host "  ⑥ 설치 목록 저장 후 JupyterLab 실행" -ForegroundColor Cyan
Write-Host '      pip freeze > requirements.txt'
Write-Host '      jupyter lab'
Write-Host '      # 노트북 우측 상단 커널이 "Python (dl2026)" 인지 확인'

Write-Host ""
Write-Host "  ⑦ 수업이 끝나고 PC 를 떠나기 전 (공용 PC)" -ForegroundColor Cyan
Write-Host '      git push'
Write-Host '      cmdkey /delete:git:https://github.com'

Write-Host ""
Write-Host ("  ※ 앞으로 자료에 나오는 %DL2026_HOME%\venv 는  " + $WorkDir + "\venv  로 바꿔 읽으세요.")
Write-Host $line -ForegroundColor Green
Write-Host ""
