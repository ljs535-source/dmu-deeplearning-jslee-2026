# 파일: preprocess_text.py
# 10주차 — 한국어 텍스트 전처리 (★ 제공 코드. 학생이 짜지 않는다)
#
# 사용법 (노트북에서)
#   from preprocess_text import load_nsmc, build_vocab, encode, save_vocab, load_vocab
#
#   train_texts, train_labels, val_texts, val_labels = load_nsmc("data/nsmc_subset")
#   vocab = build_vocab(train_texts, max_size=20000)      # ★ 훈련 데이터로만
#   idx   = encode(train_texts[0], vocab, max_len=40)
#
# 서브셋 파일 만들기 (교수용, 한 번만)
#   python preprocess_text.py --make data/nsmc_subset --n-train 20000 --n-val 4000
#
# ── 이 파일의 목적 ─────────────────────────────────────────────
#   토큰화·어휘사전 구축은 10주차의 학습 목표가 아니다.
#   여기에 시간을 쓰면 3교시 어텐션에 도달하지 못한다.
#   학생은 이 코드를 **읽고 흐름만 파악**한다 (1교시 실습 2).
#
#   ⚠️ KoNLPy·Mecab 같은 형태소 분석기는 쓰지 않는다.
#      Windows 설치가 까다로워 수업이 무너진다.
#      제대로 된 한국어 토크나이저는 12주차에 HuggingFace 것을 쓴다.
#
# ── 전처리 네 단계 ─────────────────────────────────────────────
#   ① 원문        "이 영화 정말 재미없다"
#        ↓ 토큰화
#   ② 토큰        ["이", "영화", "정말", "재미없다"]
#        ↓ 어휘사전 (빈도순, 상위 20,000개)
#   ③ 인덱스      [3, 27, 15, 842]
#        ↓ 패딩/자르기 (최대 길이 40)
#   ④ 고정 길이   [3, 27, 15, 842, 0, 0, ..., 0]      ← 0 = <pad>

import argparse
import json
import re
from collections import Counter
from pathlib import Path

# ------------------------------------------------------------- 특수 토큰

PAD, UNK = "<pad>", "<unk>"
PAD_IDX, UNK_IDX = 0, 1          # ★ <pad> 를 0번에 두면 padding_idx=0 으로 학습에서 뺄 수 있다

# 고정 설정 — ★ 학생마다 다르면 3교시 실습 6의 성능 비교가 성립하지 않는다
MAX_SIZE = 20000                 # 어휘사전 크기
MAX_LEN = 40                     # 문장 최대 길이


# --------------------------------------------------------------- ① 토큰화

# 한글 덩어리 / 영문 / 숫자 / 문장부호를 각각 하나의 토큰으로 끊는다.
_TOKEN = re.compile(r"[가-힣]+|[a-zA-Z]+|[0-9]+|[^\s가-힣a-zA-Z0-9]")


def tokenize(text):
    """공백·문자종류 기반 토크나이저.

    형태소 분석기가 아니므로 '재미있었다' 가 통째로 한 토큰이 된다.
    한국어는 조사·어미가 붙어 어휘가 커지지만, 2만 개 사전으로 충분히 동작한다.
    (이 한계를 12주차 서브워드 토크나이저와 비교하게 된다.)
    """
    return _TOKEN.findall(str(text).lower())


# ----------------------------------------------------------- ② 어휘사전

def build_vocab(texts, max_size=MAX_SIZE, min_freq=2):
    """훈련 텍스트에서 {단어: 인덱스} 사전을 만든다.

    ★ 반드시 **훈련 데이터로만** 만든다.
      검증·테스트 문장의 단어까지 넣으면 정보가 새어 나간다
      (6주차 "테스트로 설정을 고르면 안 된다"와 같은 이유).
      검증에서 처음 보는 단어는 <unk> 로 처리된다.
    """
    counter = Counter()
    for t in texts:
        counter.update(tokenize(t))

    vocab = {PAD: PAD_IDX, UNK: UNK_IDX}
    for word, freq in counter.most_common():
        if len(vocab) >= max_size:
            break
        if freq < min_freq:
            break                                  # most_common 은 내림차순이라 여기서 끝
        vocab[word] = len(vocab)
    return vocab


def invert_vocab(vocab):
    """{단어: 인덱스} → {인덱스: 단어}. 어텐션 시각화에서 쓴다."""
    return {i: w for w, i in vocab.items()}


def save_vocab(vocab, path):
    """★ 어휘사전은 모델과 **반드시 함께** 저장한다.

    없으면 다음에 모델을 불러와도 인덱스가 달라져 쓸 수 없다.
    12주차 "토크나이저도 함께 저장해야 하는 이유"와 같은 이야기다.
    """
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(vocab, ensure_ascii=False), encoding="utf-8")
    return path


def load_vocab(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


# --------------------------------------------------- ③④ 인덱스 + 패딩

def encode(text, vocab, max_len=MAX_LEN):
    """문장 하나를 고정 길이 정수 리스트로.

    길면 자르고(truncate), 짧으면 뒤를 <pad>(0)로 채운다.

    ⚠️ max_len 이 너무 짧으면 뒷부분이 잘린다.
       한국어 리뷰는 **감성이 대개 문장 끝에** 있어서 치명적이다
       ("배우도 좋고 영상도 훌륭한데 결말이 최악이다").
    """
    ids = [vocab.get(tok, UNK_IDX) for tok in tokenize(text)][:max_len]
    return ids + [PAD_IDX] * (max_len - len(ids))


def encode_all(texts, vocab, max_len=MAX_LEN):
    """여러 문장을 한 번에. (N, max_len) 모양의 리스트를 돌려준다."""
    return [encode(t, vocab, max_len) for t in texts]


def decode(ids, vocab_or_itos, keep_pad=False):
    """인덱스를 다시 단어로. 확인·시각화용."""
    itos = vocab_or_itos if 0 in vocab_or_itos else invert_vocab(vocab_or_itos)
    words = [itos.get(int(i), UNK) for i in ids]
    return words if keep_pad else [w for w in words if w != PAD]


def real_length(ids):
    """패딩을 뺀 실제 토큰 수."""
    return sum(1 for i in ids if int(i) != PAD_IDX)


# --------------------------------------------------------- 데이터 로딩

def _read_tsv(path):
    """id\tdocument\tlabel 형식(NSMC 원본과 동일)을 읽는다."""
    texts, labels = [], []
    with open(path, encoding="utf-8") as f:
        header = f.readline()
        if "document" not in header:          # 헤더가 없으면 첫 줄도 데이터
            f.seek(0)
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            doc, label = parts[1], parts[2]
            if not doc.strip() or label not in ("0", "1"):
                continue                       # 빈 문장은 버린다 (어텐션에서 nan 의 원인)
            texts.append(doc)
            labels.append(int(label))
    return texts, labels


def load_nsmc(root="data/nsmc_subset"):
    """NSMC 서브셋을 읽어 (train_texts, train_labels, val_texts, val_labels) 반환.

    기대 파일
        <root>/train.tsv
        <root>/val.tsv
    원본 파일명(ratings_train.txt / ratings_test.txt)도 그대로 받는다.
    """
    root = Path(root)
    cand = {
        "train": ["train.tsv", "ratings_train.txt", "nsmc_train.tsv"],
        "val":   ["val.tsv", "ratings_test.txt", "nsmc_val.tsv", "test.tsv"],
    }

    picked = {}
    for split, names in cand.items():
        for n in names:
            if (root / n).exists():
                picked[split] = root / n
                break
        if split not in picked:
            raise FileNotFoundError(
                f"'{root}' 에서 {split} 파일을 찾지 못했습니다. 찾은 이름: {names}\n"
                f"  -> 배포본 data/nsmc_subset/ 을 그 경로에 두거나,\n"
                f"     python preprocess_text.py --make {root} 로 만드세요."
            )

    tr_x, tr_y = _read_tsv(picked["train"])
    va_x, va_y = _read_tsv(picked["val"])
    return tr_x, tr_y, va_x, va_y


# ------------------------------------------------- 서브셋 만들기 (교수용)

NSMC_URL = "https://raw.githubusercontent.com/e9t/nsmc/master/{}"


def make_subset(out_dir, n_train=20000, n_val=4000, seed=42):
    """NSMC 원본(20만 건)에서 서브셋을 잘라 저장한다.

    원본이 <out_dir>/ratings_train.txt 에 이미 있으면 그것을 쓰고,
    없으면 내려받는다(인터넷 필요).
    ★ 라벨 균형을 맞춰 자른다 — 6주차의 클래스 불균형을 피하기 위해.
    """
    import random
    import urllib.request

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    for name in ["ratings_train.txt", "ratings_test.txt"]:
        p = out / name
        if not p.exists():
            print(f"  내려받는 중 : {name}")
            urllib.request.urlretrieve(NSMC_URL.format(name), p)

    rng = random.Random(seed)

    for src, dst, n in [("ratings_train.txt", "train.tsv", n_train),
                        ("ratings_test.txt", "val.tsv", n_val)]:
        texts, labels = _read_tsv(out / src)
        pairs = list(zip(texts, labels))
        rng.shuffle(pairs)

        half = n // 2
        pos = [p for p in pairs if p[1] == 1][:half]
        neg = [p for p in pairs if p[1] == 0][:half]
        picked = pos + neg
        rng.shuffle(picked)

        with open(out / dst, "w", encoding="utf-8") as f:
            f.write("id\tdocument\tlabel\n")
            for i, (t, l) in enumerate(picked):
                f.write(f"{i}\t{t}\t{l}\n")
        print(f"  {dst:10s} {len(picked):6,d}건  (긍정 {len(pos)} / 부정 {len(neg)})")


# ------------------------------------------------------------------ 확인

def _demo(root):
    print("=" * 62)
    print("  preprocess_text.py 동작 확인")
    print("=" * 62)

    tr_x, tr_y, va_x, va_y = load_nsmc(root)
    print(f"\n[데이터]  훈련 {len(tr_x):,}건 / 검증 {len(va_x):,}건")
    print(f"  라벨 비율(훈련) : 긍정 {sum(tr_y)/len(tr_y)*100:.1f}%")

    print("\n[① 토큰화]")
    sample = tr_x[0]
    print(f"  원문   : {sample}")
    print(f"  토큰   : {tokenize(sample)}")

    print("\n[② 어휘사전]")
    vocab = build_vocab(tr_x, max_size=MAX_SIZE)
    print(f"  크기   : {len(vocab):,}  (상한 {MAX_SIZE:,})")
    print(f"  앞 10개: {list(vocab.items())[:10]}")

    print("\n[③④ 인덱스 + 패딩]")
    ids = encode(sample, vocab, MAX_LEN)
    print(f"  인덱스 : {ids}")
    print(f"  실제 길이 : {real_length(ids)} / {MAX_LEN}")
    print(f"  되돌리면 : {decode(ids, vocab)}")

    lens = [real_length(encode(t, vocab, 200)) for t in tr_x[:2000]]
    over = sum(1 for l in lens if l > MAX_LEN)
    print(f"\n[길이 점검]  앞 2,000건 기준")
    print(f"  평균 {sum(lens)/len(lens):.1f} 토큰 / 최대 {max(lens)}")
    print(f"  max_len={MAX_LEN} 에서 잘리는 문장 : {over/len(lens)*100:.1f}%")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="10주차 텍스트 전처리")
    ap.add_argument("--make", metavar="DIR", help="NSMC 서브셋을 만들어 저장할 폴더")
    ap.add_argument("--n-train", type=int, default=20000)
    ap.add_argument("--n-val", type=int, default=4000)
    ap.add_argument("--root", default="data/nsmc_subset", help="확인할 데이터 폴더")
    args = ap.parse_args()

    if args.make:
        print(f"NSMC 서브셋 생성 → {args.make}")
        make_subset(args.make, args.n_train, args.n_val)
    else:
        _demo(args.root)
