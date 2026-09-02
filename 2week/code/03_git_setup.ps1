# =====================================================================
#  파일: 03_git_setup.ps1
#  2주차 3교시 — Git PC 공통 설정 (공용 계정 PC용)
# =====================================================================
#
#  사용법
#    고칠 줄이 없다. 그냥 실행한다:   .\03_git_setup.ps1
#    (실행 정책 오류가 나면 02_venv_commands.ps1 블록 3 참고)
#
#  ★ 이름/이메일은 여기서 설정하지 않는다.
#
#    우리 컴퓨터실은 모든 학생이 같은 Windows 계정을 쓴다.
#    git config --global 은 %USERPROFILE%\.gitconfig 파일 하나에 저장되므로
#    그 계정을 쓰는 모든 학생이 공유한다. 여기에 이메일을 남기고 나가면
#    다음 사람의 커밋이 내 이름으로, 내 잔디에 조용히 기록된다.
#
#    그래서 이름/이메일은 실습 10에서 저장소마다 --local 로 넣는다:
#        git init
#        git config --local user.name  "Hong Gildong"
#        git config --local user.email "본인GitHub이메일@example.com"
#    이 값은 그 저장소의 .git/config, 즉 내 전용 폴더 안에만 남는다.
# =====================================================================


# --- 0. git 설치 확인 -------------------------------------------------
Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "  Git PC 공통 설정 (공용 계정 PC)"
Write-Host "------------------------------------------------------------"

git --version
if (-not $?) {
    Write-Host "[중단] git 이 설치되어 있지 않습니다. Git for Windows 를 먼저 설치하세요."
    Write-Host "       https://git-scm.com/download/win"
    exit 1
}


# --- 1. 앞 사람이 남긴 신원 청소 ★ ------------------------------------
# 이 PC를 앞서 쓴 학생이 --global 로 이름/이메일을 넣어 두었을 수 있다.
# 그대로 두면 내 커밋이 그 사람 이름으로 기록된다.
$prevName  = git config --global user.name
$prevEmail = git config --global user.email

if ($prevName -or $prevEmail) {
    Write-Host ""
    Write-Host "[정리] --global 에 남아 있던 신원을 지웁니다."
    if ($prevName)  { Write-Host ("       user.name  : " + $prevName) }
    if ($prevEmail) { Write-Host ("       user.email : " + $prevEmail) }
    # 값이 없을 때 --unset-all 은 종료 코드 5를 내므로 조용히 넘긴다.
    git config --global --unset-all user.name  2>$null
    git config --global --unset-all user.email 2>$null
}


# --- 2. 기본 브랜치 이름 ----------------------------------------------
# git init 했을 때 만들어지는 브랜치 이름. GitHub 기본값과 맞춘다.
git config --global init.defaultBranch main


# --- 3. Windows 줄바꿈 자동 변환 --------------------------------------
# Windows 는 CRLF, Git 저장소 안은 LF 로 두는 것이 표준이다.
# "warning: LF will be replaced by CRLF" 는 정상 동작이니 무시해도 된다.
git config --global core.autocrlf true


# --- 4. 한글 파일명 깨짐 방지 ★ ---------------------------------------
# 이 설정이 없으면 git status 에서 한글 파일명이 \355\225\234... 로 보인다.
git config --global core.quotepath false


# --- 5. 신원 자동 추측 금지 ★ 안전핀 ----------------------------------
# 이 설정이 없으면, 이름/이메일이 비어 있을 때 Git 이
# student@PC이름.local 같은 값을 혼자 지어내서 조용히 커밋한다.
# true 로 두면 대신 아래 오류를 내고 멈춘다:
#   fatal: no email was given and auto-detection is disabled
# 공용 PC에서 "설정 안 한 채 커밋"을 막아 주는 유일한 장치다.
# 수업이 끝나도 이 설정은 지우지 않는다 (다음 사람 보호).
git config --global user.useConfigOnly true


# --- 6. 자격 증명 관리자 확인 -----------------------------------------
# push 할 때 브라우저 로그인 창을 띄워 주는 도구.
$helper = git config --global credential.helper
if (-not $helper) {
    Write-Host ""
    Write-Host "[경고] credential.helper 가 비어 있습니다."
    Write-Host "       아래 명령으로 설정하거나, Git for Windows 를 재설치하며"
    Write-Host "       'Git Credential Manager' 를 선택하세요."
    Write-Host "       git config --global credential.helper manager"
}


# --- 7. 결과 확인 -----------------------------------------------------
Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host "  설정 결과 (--global)"
Write-Host "------------------------------------------------------------"
Write-Host ("  init.defaultBranch : " + (git config --global init.defaultBranch))
Write-Host ("  core.autocrlf      : " + (git config --global core.autocrlf))
Write-Host ("  core.quotepath     : " + (git config --global core.quotepath))
Write-Host ("  user.useConfigOnly : " + (git config --global user.useConfigOnly))
Write-Host ("  credential.helper  : " + (git config --global credential.helper))
Write-Host ("  user.name          : " + (git config --global user.name)  + "   <- 비어 있어야 정상")
Write-Host ("  user.email         : " + (git config --global user.email) + "   <- 비어 있어야 정상")
Write-Host "------------------------------------------------------------"
Write-Host ""
Write-Host "  다음 단계 (실습 10) — 작업 폴더에서 저장소를 만든 뒤 신원을 넣는다:"
Write-Host ""
Write-Host '      git init'
Write-Host '      git config --local user.name  "Hong Gildong"'
Write-Host '      git config --local user.email "본인GitHub이메일@example.com"'
Write-Host ""
Write-Host "  전체 설정과 저장 위치를 보려면:  git config --list --show-origin"
Write-Host ""
