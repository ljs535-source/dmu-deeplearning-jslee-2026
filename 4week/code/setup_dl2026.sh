#!/usr/bin/env bash
# =====================================================================
#  파일: setup_dl2026.sh   (Git Bash 용 — setup_dl2026.ps1 과 같은 일을 한다)
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
#  실행 방법 (Git Bash)
#    이 파일을 작업 기준 폴더에 복사한 뒤, Git Bash 에서 그 폴더로 이동해
#        bash setup_dl2026.sh
#    또는 탐색기에서 이 파일 더블클릭 (Git 설치 때 .sh 연결을 켰다면 Git Bash 로 열린다)
#
#  참고 — 줄바꿈
#    이 파일은 LF 로 저장되어 있다. Git Bash(Git for Windows)는 CRLF 로 바뀌어도 실행되지만,
#    WSL · macOS · Linux 의 bash 는  $'\r': command not found  오류를 낸다.
#    그때 고치는 법:  sed -i 's/\r$//' setup_dl2026.sh
# =====================================================================

PKG_WEEK2=(jupyterlab ipykernel numpy pandas matplotlib humanize)
TORCH_INSTALL="pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126"

# .gitignore 내용 — 2주차 gitignore_template.txt 와 같다
GITIGNORE_LINES=(
    "# 가상환경 — 절대 커밋하지 않는다. requirements.txt 로 재현한다."
    "venv/" "tmpvenv/" "wrongvenv/" ".venv/"
    ""
    "# 파이썬 캐시"
    "__pycache__/" "*.pyc" "*.pyo"
    ""
    "# 주피터 체크포인트"
    ".ipynb_checkpoints/"
    ""
    "# 환경변수·비밀키"
    ".env"
    ""
    "# 데이터셋 (용량이 크다)"
    "data/" "datasets/"
    ""
    "# 학습된 모델 가중치 (용량이 크다)"
    "*.pth" "*.pt" "*.ckpt" "*.safetensors"
    ""
    "# OS·에디터가 만드는 파일"
    "Thumbs.db" "desktop.ini" ".DS_Store" ".vscode/"
)
# .gitignore 가 이미 있을 때(원격에서 내려받은 경우 등) 빠져 있으면 덧붙이는 최소 항목
GITIGNORE_REQUIRED=("venv/" "__pycache__/" ".ipynb_checkpoints/" ".env")

# 색상 (터미널일 때만)
if [ -t 1 ]; then
    C_CYAN=$'\e[36m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_RESET=$'\e[0m'
else
    C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

say()   { printf '%s\n' "$*"; }
color() { printf '%s%s%s\n' "$1" "$2" "$C_RESET"; }

# 더블클릭으로 열린 창은 스크립트가 끝나면 바로 닫히므로, 끝에서 한 번 멈춘다
pause_end() {
    if [ -t 0 ]; then
        echo
        read -r -p "  Enter 를 누르면 끝납니다..." _
    fi
}

write_step() {
    echo
    say "------------------------------------------------------------"
    color "$C_CYAN" "  [$1] $2"
    say "------------------------------------------------------------"
}

stop_setup() {
    echo
    color "$C_RED" "[중단] $1"
    pause_end
    exit 1
}

# 입력을 받아 앞뒤 공백을 지운 값을 REPLY 에 넣는다
ask() {
    local reply
    IFS= read -r -p "$1" reply || stop_setup "입력이 끊겼습니다"
    reply="${reply//$'\r'/}"
    reply="${reply#"${reply%%[![:space:]]*}"}"
    reply="${reply%"${reply##*[![:space:]]}"}"
    REPLY="$reply"
}

# 영문 · 숫자 · _ · - 만 허용 (LC_ALL=C 로 비교해야 한글이 영문 범위에 섞이지 않는다)
is_valid_name() {
    local LC_ALL=C
    [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]
}

# /c/Users/... -> C:\Users\...  (화면 표시 · 경로 길이 계산용)
win_path() {
    cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
}

# Windows 경로 길이 제한은 "글자 수" 기준이므로 UTF-8 로 센다
char_len() {
    local LC_ALL=C.UTF-8
    printf '%s' "${#1}"
}

# 이메일 형식 확인 (아주 느슨하게: 무엇@무엇.무엇)
is_valid_email() {
    local re='^[^@[:space:]"]+@[^@[:space:]"]+\.[^@[:space:]"]+$'
    [[ "$1" =~ $re ]]
}

# .gitignore 에 해당 항목이 있는지 (앞뒤 공백 · 앞뒤 / 는 무시하고 비교)
gitignore_has() {
    local file="$1" want="$2" line
    want="${want#/}"; want="${want%/}"
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line//$'\r'/}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        line="${line#/}"; line="${line%/}"
        [ "$line" = "$want" ] && return 0
    done < "$file"
    return 1
}


# --- 1. DL2026_HOME 확인 ----------------------------------------------
write_step 1 "작업 기준 폴더 (DL2026_HOME) 확인"

DL2026_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || stop_setup "스크립트가 있는 폴더를 찾을 수 없습니다"
say "  DL2026_HOME = $(win_path "$DL2026_HOME")"

# 쓰기 권한 확인
probe="$DL2026_HOME/_writetest"
if ! mkdir -p "$probe" 2>/dev/null || ! rmdir "$probe" 2>/dev/null; then
    stop_setup "이 폴더에 쓸 수 없습니다: $(win_path "$DL2026_HOME")"
fi


# --- 2. 폴더 이름 입력 · 생성 -----------------------------------------
write_step 2 "만들 폴더 이름 입력"
say "  규칙 : 영문 · 숫자 · _ · - 만 사용 (한글 · 공백 불가)"
say "  예시 : 20261234_hong"

while true; do
    echo
    ask "  폴더 이름: "
    FOLDER_NAME="$REPLY"

    if [ -z "$FOLDER_NAME" ]; then
        color "$C_YELLOW" "  이름을 입력하세요."
        continue
    fi
    if ! is_valid_name "$FOLDER_NAME"; then
        color "$C_YELLOW" "  한글 · 공백 · 특수문자는 쓸 수 없습니다. 다시 입력하세요."
        continue
    fi

    WORK_DIR="$DL2026_HOME/$FOLDER_NAME"
    if [ -e "$WORK_DIR" ]; then
        color "$C_YELLOW" "  이미 있는 폴더입니다: $(win_path "$WORK_DIR")"
        ask "  이 폴더를 그대로 사용할까요? (y/n) "
        [ "$REPLY" = "y" ] || continue
    fi
    break
done

WORK_DIR_WIN="$(win_path "$WORK_DIR")"

# Windows 경로 길이 제한(260자) — venv 안의 가장 깊은 파일은 작업 폴더 뒤로 120자 가량 더 붙는다
WORK_LEN="$(char_len "$WORK_DIR_WIN")"
if [ "$WORK_LEN" -gt 120 ]; then
    color "$C_YELLOW" "  [경고] 작업 폴더 경로가 깁니다 (${WORK_LEN}자). 설치 중 '파일 이름이나 확장명이 너무 깁니다' 오류가 날 수 있습니다."
    say "         C:\\dl2026 처럼 짧은 경로에 스크립트를 두고 실행하세요."
    ask "  그래도 계속할까요? (y/n) "
    [ "$REPLY" = "y" ] || stop_setup "사용자가 중단함"
fi

mkdir -p "$WORK_DIR" || stop_setup "폴더를 만들 수 없습니다: $WORK_DIR_WIN"
cd "$WORK_DIR" || stop_setup "폴더로 이동할 수 없습니다: $WORK_DIR_WIN"
color "$C_GREEN" "  작업 폴더 : $WORK_DIR_WIN"


# --- 3. 가상환경 생성 · 활성화 ----------------------------------------
write_step 3 "가상환경 생성 (python -m venv venv) 과 활성화"

# Windows python 은 출력 끝에 \r 을 붙이므로 지운다
PY_VER="$(python -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>/dev/null)"
PY_STATUS=$?
PY_VER="${PY_VER//$'\r'/}"
if [ "$PY_STATUS" -ne 0 ] || [ -z "$PY_VER" ]; then
    color "$C_RED" "  python 을 실행할 수 없습니다."
    say "  - Microsoft Store 가 열렸다면: 설정 > 앱 > 고급 앱 설정 > 앱 실행 별칭 에서 python.exe 끄기"
    say "  - 설치되어 있지 않다면: Python 3.13 설치 후 Git Bash 를 새로 열고 다시 실행"
    stop_setup "python 없음"
fi
say "  python 버전 : $PY_VER"

if [[ "$PY_VER" != 3.13.* ]]; then
    color "$C_YELLOW" "  [경고] 수업 기준 버전은 3.13.x 입니다."
    say "         py 런처가 있다면 중단 후 직접:  py -3.13 -m venv venv"
    ask "  이 버전으로 계속할까요? (y/n) "
    [ "$REPLY" = "y" ] || stop_setup "사용자가 중단함"
fi

VENV_PY="$WORK_DIR/venv/Scripts/python.exe"

if [ -e "$VENV_PY" ]; then
    color "$C_YELLOW" "  이 폴더에 venv 가 이미 있습니다."
    ask "  지우고 새로 만들까요? (y: 새로 만들기 / n: 그대로 사용) "
    if [ "$REPLY" = "y" ]; then
        if ! rm -rf "$WORK_DIR/venv" 2>/dev/null || [ -e "$WORK_DIR/venv" ]; then
            stop_setup "venv 를 지울 수 없습니다. JupyterLab · 다른 터미널 · 탐색기를 닫고 다시 실행하세요."
        fi
    fi
fi

if [ ! -e "$VENV_PY" ]; then
    say "  python -m venv venv  실행 중..."
    if ! python -m venv venv || [ ! -e "$VENV_PY" ]; then
        stop_setup "가상환경 생성 실패"
    fi
fi

# 활성화 (이 스크립트 안에서만 유지된다. 끝난 뒤에는 터미널에서 다시 활성화해야 한다)
if [ -f "$WORK_DIR/venv/Scripts/activate" ]; then
    # shellcheck disable=SC1091
    source "$WORK_DIR/venv/Scripts/activate"
    color "$C_GREEN" "  활성화 완료 : VIRTUAL_ENV = $VIRTUAL_ENV"
else
    color "$C_YELLOW" "  [경고] venv/Scripts/activate 가 없습니다."
    say "         venv 의 python.exe 를 직접 불러서 계속 설치합니다."
fi

# 설치는 항상 venv 의 python.exe 로 한다 -> 활성화 여부와 무관하게 설치 위치가 확실하다
EXE="$("$VENV_PY" -c "import sys; print(sys.executable)")"
say "  설치 대상 python : ${EXE//$'\r'/}"


# --- 4. Git 저장소 설정 -----------------------------------------------
# venv 가 있는 작업 폴더를 그대로 Git 저장소로 쓴다 (2주차 실습 10 · 12 와 같은 구성)
write_step 4 "Git 저장소 설정 (git init · 이름/이메일 · 원격 주소 · .gitignore)"

GIT_OK=0
REMOTE_URL=""
GIT_PULLED="none"     # pulled: 원격 main 내려받음 / empty: 원격이 비어 있음 / failed: 못 가져옴 / existing: 이미 커밋 있음

if ! command -v git >/dev/null 2>&1; then
    color "$C_YELLOW" "  [경고] git 을 찾을 수 없어 이 단계를 건너뜁니다."
    say "         Git for Windows 설치 후 이 스크립트를 다시 실행하면 이어서 설정됩니다."
    say "         (같은 폴더 이름 입력 -> venv 는 'n: 그대로 사용')   https://git-scm.com/download/win"
else
    GIT_OK=1

    # (4-1) 저장소 만들기
    say "  (4-1) git init"
    if [ -d "$WORK_DIR/.git" ]; then
        say "  이미 Git 저장소입니다. 초기화는 건너뜁니다."
    else
        git init || stop_setup "git init 실패"
        git symbolic-ref HEAD refs/heads/main     # 첫 브랜치 이름을 main 으로 (GitHub 기본값과 같게)
    fi

    # (4-2) 신원 — 공용 PC 이므로 반드시 --local
    echo
    say "  (4-2) 이 저장소에만 쓸 이름 · 이메일 (--local)"
    say "        공용 PC 이므로 --global 에는 넣지 않습니다."
    say "        이메일은 GitHub 에 등록한 주소여야 커밋이 내 잔디(Contributions)에 기록됩니다."

    keep="n"
    cur="$(git config --local user.name)"
    cur="${cur//$'\r'/}"
    if [ -n "$cur" ]; then
        say "  현재 이름 : $cur"
        ask "  그대로 사용할까요? (y/n) "
        keep="$REPLY"
    fi
    if [ "$keep" != "y" ]; then
        while true; do
            ask "  이름 (예: Hong Gildong): "
            if [ -z "$REPLY" ]; then color "$C_YELLOW" "  이름을 입력하세요."; continue; fi
            if [[ "$REPLY" == *\"* ]]; then color "$C_YELLOW" '  큰따옴표(")는 쓸 수 없습니다.'; continue; fi
            break
        done
        git config --local user.name "$REPLY" || stop_setup "user.name 설정 실패"
    fi

    keep="n"
    cur="$(git config --local user.email)"
    cur="${cur//$'\r'/}"
    if [ -n "$cur" ]; then
        say "  현재 이메일 : $cur"
        ask "  그대로 사용할까요? (y/n) "
        keep="$REPLY"
    fi
    if [ "$keep" != "y" ]; then
        while true; do
            ask "  GitHub 이메일: "
            if ! is_valid_email "$REPLY"; then color "$C_YELLOW" "  이메일 형식이 아닙니다. 다시 입력하세요."; continue; fi
            if [[ "$REPLY" == *@example.com ]]; then color "$C_YELLOW" "  예시 주소입니다. 본인 GitHub 이메일을 입력하세요."; continue; fi
            break
        done
        git config --local user.email "$REPLY" || stop_setup "user.email 설정 실패"
    fi

    # (4-3) 원격 저장소 주소 (origin)
    echo
    say "  (4-3) GitHub 원격 저장소 주소 (origin)"
    say "        GitHub 저장소 페이지 > 초록색 [Code] 버튼 > HTTPS 주소 복사"
    say "        예: https://github.com/<본인아이디>/deeplearning-study-2026.git"
    say "        GitHub 에 아직 저장소가 없으면 그냥 Enter (나중에 연결)"

    cur="$(git config --local --get remote.origin.url)"
    cur="${cur//$'\r'/}"
    REMOTE_URL="$cur"
    ask_url=1
    if [ -n "$cur" ]; then
        say "  현재 origin : $cur"
        ask "  그대로 사용할까요? (y/n) "
        [ "$REPLY" = "y" ] && ask_url=0
    fi
    if [ "$ask_url" = 1 ]; then
        while true; do
            ask "  원격 주소: "
            [ -z "$REPLY" ] && break
            if [[ "$REPLY" == *"<"* || "$REPLY" == *">"* || "$REPLY" == *본인아이디* ]]; then
                color "$C_YELLOW" "  예시를 그대로 넣었습니다. <본인아이디> 를 실제 GitHub 아이디로 바꾸세요."
                continue
            fi
            if ! [[ "$REPLY" =~ ^(https://|git@)[^[:space:]]+$ ]]; then
                color "$C_YELLOW" "  https:// 로 시작하는 주소를 입력하세요."
                continue
            fi
            REMOTE_URL="$REPLY"
            break
        done
        if [ -n "$REMOTE_URL" ] && [ "$REMOTE_URL" != "$cur" ]; then
            if [ -n "$cur" ]; then
                git remote set-url origin "$REMOTE_URL"
            else
                git remote add origin "$REMOTE_URL"
            fi || stop_setup "원격 주소 설정 실패"
        fi
    fi

    # (4-4) 원격에 지난주까지의 커밋이 있으면 내려받는다
    #       .gitignore 를 만들기 "전에" 해야 원격의 .gitignore 와 겹쳐 멈추지 않는다
    if git rev-parse --verify --quiet HEAD >/dev/null; then
        GIT_PULLED="existing"
    elif [ -n "$REMOTE_URL" ]; then
        echo
        say "  (4-4) 원격 저장소 내용 가져오기 (git fetch)"
        # 로그인 창 · 암호 질문 없이 시도만 한다
        if ! GIT_TERMINAL_PROMPT=0 git -c credential.helper= fetch origin; then
            GIT_PULLED="failed"
            color "$C_YELLOW" "  [경고] 가져오지 못했습니다 (주소 오타 · 비공개 저장소 · 네트워크). 아래 안내 ⑤ 에서 직접 가져옵니다."
        elif ! git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then
            GIT_PULLED="empty"
            say "  원격 저장소가 비어 있습니다 (main 브랜치 없음). 첫 커밋 후 push 하면 됩니다."
        elif git checkout -B main --track origin/main; then
            GIT_PULLED="pulled"
            color "$C_GREEN" "  원격 저장소의 main 을 내려받았습니다 (origin/main 추적)."
        else
            GIT_PULLED="failed"
            color "$C_YELLOW" "  [경고] 폴더에 원격과 같은 이름의 파일이 있어 내려받지 못했습니다. 아래 안내 ⑤ 를 따르세요."
        fi
    fi

    # (4-5) .gitignore — venv 등 올리면 안 되는 것을 제외한다
    echo
    say "  (4-5) .gitignore (venv/ 등을 Git 에서 제외)"
    GI="$WORK_DIR/.gitignore"
    if [ -f "$GI" ]; then
        missing=()
        for pat in "${GITIGNORE_REQUIRED[@]}"; do
            gitignore_has "$GI" "$pat" || missing+=("$pat")
        done
        if [ "${#missing[@]}" -eq 0 ]; then
            say "  이미 있고, 꼭 필요한 항목(venv/ 등)이 모두 들어 있습니다."
        else
            {
                [ -n "$(tail -c 1 "$GI")" ] && echo
                echo "# setup_dl2026 이 추가한 항목"
                printf '%s\n' "${missing[@]}"
            } >> "$GI"
            color "$C_GREEN" "  기존 .gitignore 에 빠진 항목을 추가했습니다: ${missing[*]}"
        fi
    else
        printf '%s\n' "${GITIGNORE_LINES[@]}" > "$GI"
        color "$C_GREEN" "  .gitignore 를 만들었습니다 (2주차 gitignore_template.txt 와 같은 내용)"
    fi

    # (4-6) 결과 확인
    echo
    say "  (4-6) 확인"
    origin="$(git config --local --get remote.origin.url)"
    say "  user.name  : $(git config --local user.name)"
    say "  user.email : $(git config --local user.email)"
    say "  origin     : ${origin:-(없음 - 나중에 연결)}"
    say "  branch     : $(git branch --show-current)"
    if git check-ignore -q venv; then
        color "$C_GREEN" "  venv/      : Git 에서 제외됨 (정상)"
    else
        color "$C_YELLOW" "  [경고] venv 가 Git 에서 제외되지 않습니다. .gitignore 를 확인하세요."
    fi
fi


# --- 5. 패키지 설치 (2주차) -------------------------------------------
write_step 5 "패키지 설치 (2주차)"

say "  (5-1) pip 업그레이드"
"$VENV_PY" -m pip install --upgrade pip || stop_setup "pip 업그레이드 실패 (네트워크 확인)"

echo
say "  (5-2) ${PKG_WEEK2[*]}"
"$VENV_PY" -m pip install "${PKG_WEEK2[@]}" || stop_setup "2주차 패키지 설치 실패"

echo
say "  (5-3) 설치 확인"
"$VENV_PY" -c "import jupyterlab, ipykernel, numpy, pandas, matplotlib, humanize; print('jupyterlab :', jupyterlab.__version__); print('numpy      :', numpy.__version__); print('pandas     :', pandas.__version__); print('matplotlib :', matplotlib.__version__)" \
    || stop_setup "import 확인 실패"


# --- 6. 나머지 설정 : 명령어 안내 -------------------------------------
LINE="============================================================"
echo
color "$C_GREEN" "$LINE"
color "$C_GREEN" "  자동 설치 완료. 아래 명령을 VSCode 터미널(Git Bash)에서 순서대로 직접 입력하세요."
color "$C_GREEN" "$LINE"

echo
color "$C_CYAN" "  ① 작업 폴더로 이동 + 가상환경 활성화  (스크립트가 끝나면 활성화는 풀립니다)"
say "      cd \"$WORK_DIR\""
cat <<'EOF'
      source venv/Scripts/activate
      # 프롬프트 위에 (venv) 가 보이면 성공. 끌 때는: deactivate
      # VSCode 터미널 오른쪽 위 + 옆 ∨ 에서 "Git Bash" 를 골라야 합니다
EOF

echo
color "$C_CYAN" "  ② PyTorch 설치 (3주차)  ★ 프롬프트에 (venv) 가 보이는 상태에서"
say "      $TORCH_INSTALL"
cat <<'EOF'
      # 약 2.5GB, 5~20분. 터미널을 닫지 마세요.
      python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
      # -> 2.x.x+cu126 True 가 나오면 성공 (+cpu 또는 False 면 손을 들어 알리기)
EOF

echo
color "$C_CYAN" "  ③ 주피터 커널 등록"
cat <<'EOF'
      python -m ipykernel install --user --name dl2026 --display-name "Python (dl2026)"
      jupyter kernelspec list
EOF

echo
color "$C_CYAN" "  ④ Git 공용 PC 설정 (이름/이메일은 여기서 넣지 않습니다)"
cat <<'EOF'
      git config --global init.defaultBranch main
      git config --global core.autocrlf true
      git config --global core.quotepath false
      git config --global user.useConfigOnly true
      git config --global credential.helper manager
EOF

echo
if [ "$GIT_OK" != 1 ]; then
color "$C_CYAN" "  ⑤ Git 저장소 설정 (git 이 없어 4단계를 건너뛰었습니다 — Git 설치 후 이 스크립트를 다시 실행해도 됩니다)"
cat <<'EOF'
      git init
      git config --local user.name  "Hong Gildong"
      git config --local user.email "본인GitHub이메일@example.com"
      git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git
      git pull origin main
      git branch -u origin/main
EOF
elif [ -z "$REMOTE_URL" ]; then
color "$C_CYAN" "  ⑤ GitHub 저장소 연결 (4단계에서 원격 주소를 건너뛰었습니다)"
cat <<'EOF'
      git remote add origin https://github.com/<본인아이디>/deeplearning-study-2026.git
      git pull origin main          # 저장소에 지난주까지의 커밋이 있는 경우
      git branch -u origin/main
      # GitHub 에 저장소가 없는 사람: 2주차 02_venv_commands.ps1 블록 11 을 따라 만들고 첫 push
EOF
elif [ "$GIT_PULLED" = "pulled" ]; then
color "$C_CYAN" "  ⑤ GitHub 저장소 확인 (4단계에서 원격 main 을 내려받았습니다)"
cat <<'EOF'
      git status                    # .gitignore 에 항목을 덧붙였다면 modified 로 보입니다 (다음 커밋에 함께)
      git log --oneline -3          # 지난주까지의 커밋이 보이면 성공
EOF
elif [ "$GIT_PULLED" = "empty" ]; then
color "$C_CYAN" "  ⑤ 첫 커밋과 push (원격 저장소가 비어 있습니다)"
cat <<'EOF'
      git add .
      git status                    # venv 가 목록에 없어야 정상
      git commit -m "week4: environment setup"
      git push -u origin main       # GitHub 로그인 창이 뜨면 로그인
EOF
elif [ "$GIT_PULLED" = "existing" ]; then
color "$C_CYAN" "  ⑤ GitHub 저장소 확인 (이미 커밋이 있는 저장소입니다)"
cat <<'EOF'
      git status
      git pull origin main
EOF
else
color "$C_CYAN" "  ⑤ 원격 저장소 내려받기 (4단계에서 가져오지 못했습니다)"
cat <<'EOF'
      git remote -v                 # 주소 오타 확인 (고치기: git remote set-url origin <주소>)
      git pull origin main          # GitHub 로그인 창이 뜨면 로그인
      git branch -u origin/main
      # "untracked working tree files would be overwritten" 로 멈추면: 목록에 나온 파일을 다른 이름으로 옮기고 다시 pull
      #   예) .gitignore 가 겹친 경우 — 원격의 .gitignore 를 쓰게 된다
      mv .gitignore .gitignore.bak
      git pull origin main
      rm .gitignore.bak             # 원격에서 받은 .gitignore 를 씁니다
EOF
fi

echo
color "$C_CYAN" "  ⑥ 설치 목록 저장 후 JupyterLab 실행"
cat <<'EOF'
      pip freeze > requirements.txt
      jupyter lab
      # 노트북 우측 상단 커널이 "Python (dl2026)" 인지 확인. 끌 때는 터미널에서 Ctrl+C
EOF

echo
color "$C_CYAN" "  ⑦ 수업이 끝나고 PC 를 떠나기 전 (공용 PC)"
cat <<'EOF'
      git push
      cmdkey /delete:git:https://github.com
EOF

echo
say "  ※ 앞으로 자료에 나오는 %DL2026_HOME%\\venv 는  $WORK_DIR_WIN\\venv  로 바꿔 읽으세요."
say "     (Git Bash 에서 쓸 때는  $WORK_DIR/venv )"
color "$C_GREEN" "$LINE"
pause_end
