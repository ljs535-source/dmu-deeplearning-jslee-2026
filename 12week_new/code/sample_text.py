# 파일: sample_text.py
# 12주차 — 텍스트 프로젝트 연습용 CSV(sample_text.csv) 만들기
#
# 본인 텍스트 데이터(my_text.csv)를 아직 준비하지 못했을 때 템플릿 18 을 미리 실행해 보는 용도입니다.
# 네이버 영화 리뷰(NSMC)에서 긍정·부정 리뷰를 500개씩 골라 내 데이터와 똑같은 형식으로 저장합니다.
#
# 사용법 (Git Bash)
#   cd "$DL2026_HOME"
#   source venv/Scripts/activate
#   python sample_text.py
#
# 사용법 (PowerShell)
#   Set-Location $env:DL2026_HOME
#   .\venv\Scripts\Activate.ps1
#   python sample_text.py
#
# 템플릿 18_project_text_template 의 셀 1 은 my_text.csv 가 없으면 이 파일을 자동으로 불러 씁니다.
#
# 만들어지는 형식 (내 데이터도 이 형식으로 만듭니다)
#   text,label
#   "이 영화 정말 재미있다",긍정
#   "시간이 아깝다",부정
#
# ※ 원본(약 15MB)을 data/nsmc/ 에 내려받습니다. 10주차에 받은 ratings_train.txt 가
#   data/nsmc/ 에 있으면 다운로드 없이 바로 만들어집니다.

import csv
import os
import random
import urllib.request

URL = "https://raw.githubusercontent.com/e9t/nsmc/master/ratings_train.txt"
N_PER_CLASS = 500
# 수업 화면에 나와도 괜찮도록 비속어가 든 리뷰는 뺀다
BAD_WORDS = ["존나", "졸라", "씨발", "시발", "ㅅㅂ", "병신", "ㅂㅅ", "개새", "새끼", "좆", "미친", "지랄", "꺼져", "닥쳐"]


def make_sample_text(out="sample_text.csv", raw_dir="data/nsmc"):
    """NSMC 에서 긍정·부정 N_PER_CLASS 개씩 골라 text,label CSV 로 저장한다."""
    if os.path.exists(out):
        print(f"이미 있습니다 : {out}  (다시 만들려면 파일을 지우세요)")
        return out

    raw = os.path.join(raw_dir, "ratings_train.txt")
    if not os.path.exists(raw):
        os.makedirs(raw_dir, exist_ok=True)
        print("NSMC 원본 내려받는 중 ...")
        urllib.request.urlretrieve(URL, raw)

    rows = {"0": [], "1": []}
    with open(raw, encoding="utf-8") as f:
        next(f)                                      # 머리줄 (id, document, label)
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3 or len(parts[1].strip()) < 5:
                continue                             # 너무 짧은 리뷰는 뺀다
            if any(w in parts[1] for w in BAD_WORDS):
                continue                             # 비속어가 든 리뷰는 뺀다
            rows[parts[2]].append(parts[1].strip())

    rng = random.Random(42)                          # 어느 PC 에서나 같은 문장
    picked = [(t, "부정") for t in rng.sample(rows["0"], N_PER_CLASS)] + \
             [(t, "긍정") for t in rng.sample(rows["1"], N_PER_CLASS)]
    rng.shuffle(picked)

    with open(out, "w", encoding="utf-8-sig", newline="") as f:   # utf-8-sig : 엑셀에서도 한글이 깨지지 않게
        w = csv.writer(f)
        w.writerow(["text", "label"])
        w.writerows(picked)
    print(f"완료 : {out}  (긍정·부정 {N_PER_CLASS}개씩, 총 {len(picked)}개)")
    return out


if __name__ == "__main__":
    make_sample_text()
