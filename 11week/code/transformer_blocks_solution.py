# 파일: transformer_blocks_solution.py
# 11주차 — 트랜스포머 인코더 부품 모음  〔교수용 정답본〕
#
# ⚠️ 학생에게 이 파일을 그대로 배포하지 마세요.
#    학생은 3교시 §6-2 에서 자기 노트북의 클래스를 직접 `transformer_blocks.py` 로
#    옮겨 적습니다. "내가 트랜스포머를 짰다"는 산출물이 과제 제출물이기 때문입니다.
#    이 파일은 채점 기준과 막힌 학생 지원용입니다.
#
# 사용법
#   from transformer_blocks import (scaled_dot_product_attention, MultiHeadAttention,
#                                   EncoderBlock, Encoder, positional_encoding,
#                                   causal_mask, padding_mask)
#
# 확인
#   python transformer_blocks_solution.py        # 자체 검증 6종을 돌린다
#
# ── shape 규약 (이 파일 전체에서 동일) ────────────────────────────
#   B : 배치        T : 토큰 수(시퀀스 길이)
#   C : 채널(모델 차원, d_model)                H : 헤드 수
#   d : 헤드당 차원 = C // H
#
#   x        (B, T, C)
#   q,k,v    (B, H, T, d)
#   alpha    (B, H, T, T)      ← 행 = Query, 열 = Key, 각 행의 합 = 1
#
# ⚠️ 이 주차에서 막히는 지점의 8할은 개념이 아니라 shape 이다.
#    모든 함수에 shape 주석이 달려 있으니 한 줄씩 따라가며 읽을 것.

import math

import torch
import torch.nn as nn


# ------------------------------------------------- 스케일드 닷-프로덕트

def scaled_dot_product_attention(Q, K, V, mask=None):
    """어텐션의 심장. 본질은 세 줄이다.

        Attention(Q,K,V) = softmax( Q Kᵀ / √d_k ) V

    Q, K, V : (..., T, d_k)     앞쪽 축(..., 예: B 또는 B,H)은 배치처럼 취급된다
    mask    : 0 인 자리를 가린다. (T,T) 인과형 / (B,1,1,T) 패딩형 모두 브로드캐스팅됨
    반환    : out (..., T, d_k),  alpha (..., T, T)

    ★ √d_k 로 나누는 이유
      ① 차원 d_k 가 커지면 내적의 분산이 d_k 에 비례해 커진다
      ② 큰 값이 softmax 에 들어가면 한쪽으로 포화된다 (거의 원-핫)
      ③ 포화된 softmax 는 기울기가 거의 0 이라 학습이 멈춘다
      → 표준편차가 √d_k 이므로 √d_k 로 나눠 분산을 1 수준으로 되돌린다
    """
    d_k = Q.size(-1)
    scores = Q @ K.transpose(-2, -1) / math.sqrt(d_k)       # (..., T, T)

    if mask is not None:
        # -inf 를 넣으면 softmax 후 e^(-inf) = 0 → 그 자리의 비중이 정확히 0
        # (10주차 패딩 마스킹과 완전히 같은 기법)
        scores = scores.masked_fill(mask == 0, float("-inf"))

    alpha = torch.softmax(scores, dim=-1)                    # (..., T, T) 각 행의 합 = 1
    return alpha @ V, alpha                                  # (..., T, d_k), (..., T, T)


# ------------------------------------------------------- 멀티헤드 어텐션

class MultiHeadAttention(nn.Module):
    """C 차원을 H 개로 쪼개 각자 어텐션한 뒤 다시 합친다.

    쪼개는 이유 : softmax 는 비중을 나눠 쓴다. 한 장의 어텐션으로는
                 문법 관계·의미 관계를 동시에 보기 어렵다.
    C → C/H 인 이유 : 쪼개서 나눠 하므로 계산량 총합이 단일 헤드와 같다.
    """

    def __init__(self, C, H, bias_o=True):
        super().__init__()
        assert C % H == 0, f"C({C}) 는 H({H}) 로 나눠떨어져야 한다"
        self.C, self.H, self.d = C, H, C // H

        # Q 와 K 를 같은 가중치로 만들면 어텐션이 자기 자신에만 쏠린다 → 셋을 따로 둔다
        self.W_q = nn.Linear(C, C, bias=False)
        self.W_k = nn.Linear(C, C, bias=False)
        self.W_v = nn.Linear(C, C, bias=False)
        # 헤드들의 결과를 "이어 붙이기만" 하면 각 헤드가 따로 논 채 끝난다.
        # W_o 가 헤드들의 결과를 섞어 하나의 표현으로 만든다.
        self.W_o = nn.Linear(C, C, bias=bias_o)

    def _split(self, t, B, T):
        """(B, T, C) → (B, T, H, d) → (B, H, T, d)

        ⚠️ view(B, H, T, d) 를 **직접** 하면 shape 은 맞지만 토큰과 헤드가 뒤섞인다.
           에러도 안 나고 학습도 돌아가서 가장 찾기 어려운 버그다.
           반드시 view(B,T,H,d) → transpose(1,2) 순서를 지킬 것.
        """
        return t.view(B, T, self.H, self.d).transpose(1, 2)

    def forward(self, x, mask=None):
        # x : (B, T, C)
        B, T, C = x.shape

        q = self._split(self.W_q(x), B, T)                   # (B, H, T, d)
        k = self._split(self.W_k(x), B, T)                   # (B, H, T, d)
        v = self._split(self.W_v(x), B, T)                   # (B, H, T, d)

        out, alpha = scaled_dot_product_attention(q, k, v, mask)   # (B,H,T,d), (B,H,T,T)

        # (B, H, T, d) → (B, T, H, d) → (B, T, C)
        # ⚠️ transpose 는 메모리를 옮기지 않고 읽는 순서만 바꾼다.
        #    그 상태로 view 하면 "view size is not compatible ..." 오류가 난다.
        out = out.transpose(1, 2).contiguous().view(B, T, C)       # (B, T, C)
        return self.W_o(out), alpha                                # (B,T,C), (B,H,T,T)


# --------------------------------------------------------- 인코더 블록

class EncoderBlock(nn.Module):
    """Pre-LN 방식 인코더 블록 (요즘 표준, 학습이 안정적).

        x = x + Attn(LN(x))          ← 잔차 ① 7주차 ResNet 과 같은 아이디어
        x = x + FFN(LN(x))           ← 잔차 ②

    ★ 입력과 출력의 shape 이 같다. 그래서 그냥 쌓을 수 있다.
      BERT-base 는 이 블록이 12개다.

    역할 분담
        어텐션 : "누구를 볼까"  (토큰 간 정보 혼합)
        FFN    : "본 것을 어떻게 가공할까"  (토큰 내 처리, 위치 독립)
    """

    def __init__(self, C, H, ff_mult=4, p_drop=0.1):
        super().__init__()
        self.ln1 = nn.LayerNorm(C)          # ★ 한 토큰의 C 차원 안에서 정규화
        self.attn = MultiHeadAttention(C, H)
        self.ln2 = nn.LayerNorm(C)
        self.ffn = nn.Sequential(
            nn.Linear(C, ff_mult * C),      # (B,T,C) → (B,T,4C)   중간을 4배로 (관례)
            nn.GELU(),
            nn.Linear(ff_mult * C, C),      # (B,T,4C) → (B,T,C)
        )
        self.drop = nn.Dropout(p_drop)      # 6주차 과적합 대응

    def forward(self, x, mask=None):
        # x : (B, T, C)
        a, alpha = self.attn(self.ln1(x), mask)      # (B,T,C), (B,H,T,T)
        x = x + self.drop(a)                         # 잔차 ①
        x = x + self.drop(self.ffn(self.ln2(x)))     # 잔차 ②
        return x, alpha                              # (B,T,C), (B,H,T,T)


class Encoder(nn.Module):
    """인코더 블록을 n_layers 개 쌓은 것. n_layers=12, C=768, H=12 이면 BERT-base 구조."""

    def __init__(self, C, H, n_layers, ff_mult=4, p_drop=0.1):
        super().__init__()
        self.blocks = nn.ModuleList(
            [EncoderBlock(C, H, ff_mult, p_drop) for _ in range(n_layers)]
        )

    def forward(self, x, mask=None):
        maps = []
        for b in self.blocks:
            x, a = b(x, mask)
            maps.append(a)                  # 층마다 어텐션 맵 보관 (시각화용)
        return x, maps                      # (B,T,C), [ (B,H,T,T) ] × n_layers


# --------------------------------------------------------- 위치 인코딩

def positional_encoding(max_len, C):
    """사인·코사인 위치 인코딩 → (max_len, C)

        PE[t, 2i  ] = sin( t / 10000^(2i/C) )
        PE[t, 2i+1] = cos( t / 10000^(2i/C) )

    ★ 왜 필요한가 : 셀프 어텐션은 입력을 집합처럼 취급한다.
      "나는 밥을 먹었다" 와 "밥을 나는 먹었다" 를 구분하지 못한다.
      순환을 버리며 잃은 순서 정보를 여기서 되돌려 준다.

    ★ 왜 concat 이 아니라 더하는가 : concat 하면 차원이 2배가 되어
      이후 모든 층이 커진다. 더하기는 공짜다.

    ★ 왜 하필 사인·코사인인가 : 학습 없이 만들 수 있고,
      훈련 때보다 긴 문장에도 값을 만들 수 있다.
      (요즘 모델은 학습형 위치 임베딩이나 RoPE 를 쓰지만 원리는 같다.)
    """
    pos = torch.arange(max_len).unsqueeze(1)                    # (max_len, 1)
    i = torch.arange(0, C, 2)                                   # (C/2,)
    div = torch.exp(-math.log(10000.0) * i / C)                 # (C/2,)

    pe = torch.zeros(max_len, C)                                # (max_len, C)
    pe[:, 0::2] = torch.sin(pos * div)                          # 짝수 축 = sin
    pe[:, 1::2] = torch.cos(pos * div)                          # 홀수 축 = cos
    return pe


class PositionalEncoding(nn.Module):
    """토큰 임베딩에 위치 인코딩을 더해 주는 층. 학습 파라미터가 없다."""

    def __init__(self, C, max_len=512, p_drop=0.1):
        super().__init__()
        # buffer 로 등록하면 state_dict 에 저장되고 .to(device) 를 따라간다
        self.register_buffer("pe", positional_encoding(max_len, C))
        self.drop = nn.Dropout(p_drop)

    def forward(self, x):
        # x : (B, T, C)
        T = x.size(1)
        return self.drop(x + self.pe[:T].unsqueeze(0))          # (B, T, C)


# ------------------------------------------------------------- 마스크

def causal_mask(T, device=None):
    """디코더용 인과 마스크 → (T, T) 하삼각.

        나는  [ 1 0 0 0 ]      자기만 본다
        어제  [ 1 1 0 0 ]
      영화를  [ 1 1 1 0 ]
        봤다  [ 1 1 1 1 ]      전부

    ★ 왜 가리나 : 학습할 때 정답 문장이 통째로 들어간다.
      가리지 않으면 "다음 단어"를 커닝하게 된다.
    """
    return torch.tril(torch.ones(T, T, device=device))


def padding_mask(x, pad_idx=0):
    """패딩 마스크 → (B, 1, 1, T).  (B,H,T,T) 어텐션에 브로드캐스팅된다."""
    return (x != pad_idx).float().unsqueeze(1).unsqueeze(1)


# ------------------------------------------------------------ 자체 검증

def _check():
    torch.manual_seed(42)
    ok = 0

    print("=" * 64)
    print("  transformer_blocks 자체 검증")
    print("=" * 64)

    # ① 어텐션 각 행의 합이 1
    B, T, C, H = 2, 8, 64, 4
    q = torch.randn(B, H, T, C // H)
    out, alpha = scaled_dot_product_attention(q, q, q)
    s = alpha.sum(-1)
    print(f"\n① 어텐션 행 합 = 1        : {torch.allclose(s, torch.ones_like(s)):}")
    print(f"   alpha shape            : {tuple(alpha.shape)}  (B,H,T,T)")
    ok += torch.allclose(s, torch.ones_like(s))

    # ② 멀티헤드 입출력 shape 이 같다
    mha = MultiHeadAttention(C, H)
    x = torch.randn(B, T, C)
    y, a = mha(x)
    print(f"\n② 멀티헤드 입출력 shape   : {tuple(x.shape)} → {tuple(y.shape)}  "
          f"{x.shape == y.shape}")
    ok += (x.shape == y.shape)

    # ③ 헤드 분할이 뒤섞이지 않았다
    a2 = torch.arange(24.).view(1, 4, 6)
    right = a2.view(1, 4, 2, 3).transpose(1, 2)
    wrong = a2.view(1, 2, 4, 3)
    same = torch.equal(right[0, 0, 1], torch.tensor([6., 7., 8.]))
    print(f"\n③ view→transpose 순서     : 올바른 분할 헤드0·토큰1 = "
          f"{right[0,0,1].tolist()}  {same}")
    print(f"   (직접 view 하면 틀림)   : {wrong[0,0,1].tolist()}  ← 다른 헤드 조각")
    ok += same

    # ④ nn.MultiheadAttention 과 출력이 같다
    # ⚠️ bias=False 로 만들면 ref.out_proj.bias 가 None 이다 → 내 쪽도 bias_o=False
    ref = nn.MultiheadAttention(embed_dim=C, num_heads=H, bias=False, batch_first=True)
    mine = MultiHeadAttention(C, H, bias_o=False)
    with torch.no_grad():
        wq, wk, wv = ref.in_proj_weight.chunk(3, dim=0)
        mine.W_q.weight.copy_(wq); mine.W_k.weight.copy_(wk); mine.W_v.weight.copy_(wv)
        mine.W_o.weight.copy_(ref.out_proj.weight)
    with torch.no_grad():
        a_mine, _ = mine(x)
        a_ref, _ = ref(x, x, x)
    close = torch.allclose(a_mine, a_ref, atol=1e-5)
    print(f"\n④ nn.MultiheadAttention 과: 최대 오차 {(a_mine-a_ref).abs().max():.2e}  {close}")
    ok += close

    # ⑤ 인코더 블록 입출력 shape 이 같다 · 12층이 돈다
    enc = Encoder(C, H, n_layers=12)
    z, maps = enc(x)
    print(f"\n⑤ 12층 인코더             : {tuple(x.shape)} → {tuple(z.shape)}  "
          f"| 어텐션 맵 {len(maps)}장")
    print(f"   파라미터 (C={C})        : {sum(p.numel() for p in enc.parameters()):,} 개")
    print(f"   BERT-base (C=768)      : 약 110,000,000 개  ← 구조는 같고 크기만 다르다")
    ok += (x.shape == z.shape and len(maps) == 12)

    # ⑥ 마스킹하면 하삼각이 되고 행 합은 여전히 1
    m = causal_mask(T)
    _, am = mha(x, mask=m)
    upper = am[0, 0].triu(diagonal=1)
    rows = am[0, 0].sum(-1)
    good = torch.allclose(upper, torch.zeros_like(upper)) and \
        torch.allclose(rows, torch.ones_like(rows))
    print(f"\n⑥ 인과 마스킹             : 우상단 전부 0 & 행 합 1  →  {good}")
    ok += good

    # ⑦ 위치 인코딩이 순서를 구분시킨다
    pe = positional_encoding(T, C).unsqueeze(0)
    xs = x[:, [1, 0] + list(range(2, T)), :]
    y_plain_a, _ = mha(x)
    y_plain_b, _ = mha(xs)
    y_pe_a, _ = mha(x + pe)
    y_pe_b, _ = mha(xs + pe)
    blind = torch.allclose(y_plain_a[0, 0], y_plain_b[0, 1], atol=1e-5)
    aware = not torch.allclose(y_pe_a[0, 0], y_pe_b[0, 1], atol=1e-5)
    print(f"\n⑦ 위치 인코딩 없으면 순서를 모른다 : {blind}")
    print(f"   더하면 순서를 구분한다          : {aware}")
    ok += (blind and aware)

    print("\n" + "-" * 64)
    print(f"  통과 {ok}/7")
    print("-" * 64)


if __name__ == "__main__":
    _check()
