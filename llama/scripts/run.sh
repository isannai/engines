#!/bin/sh
# Container entrypoint for isannai/llama.
#
# 호스트의 .env 를 컨테이너의 /conf/llama.env 로 bind-mount 한 다음 매 시작
# 시 이 스크립트가 source 해서 llama-server 인자를 만든다. 운영자는:
#
#   docker stop llama
#   vim .env                          # MODEL, CTX_SIZE, GPU_LAYERS, ... 수정
#   docker start llama                # 새 값으로 llama-server 재시작
#
# 의 흐름으로 rm 없이 설정 변경. 컨테이너 id / network IP / logs 보존.

set -eu

CONF=/conf/llama.env
if [ ! -r "$CONF" ]; then
  echo "[run.sh] $CONF not found — bind-mount your .env into the container" >&2
  exit 1
fi

# .env 는 KEY=VALUE 라인 형태. set -a 후 source 하면 모든 변수가
# 자동 export — 자식 프로세스 (llama-server) 에도 환경변수로 전파됨.
set -a
# shellcheck disable=SC1090
. "$CONF"
set +a

if [ -z "${MODEL:-}" ]; then
  echo "[run.sh] MODEL is required (set it in .env)" >&2
  exit 1
fi

ARGS="--model /models/$MODEL"
ARGS="$ARGS --host 0.0.0.0 --port 8080"
ARGS="$ARGS --ctx-size ${CTX_SIZE:-4096}"
ARGS="$ARGS --n-gpu-layers ${GPU_LAYERS:-99}"
ARGS="$ARGS --parallel ${PARALLEL:-1}"

# 멀티 GPU split 모드 (-sm). 빈 값이면 llama-server 기본(layer) 사용.
[ -n "${SPLIT_MODE:-}"     ] && ARGS="$ARGS --split-mode $SPLIT_MODE"

# /slots 모니터링 엔드포인트. on/off 만 명시 반영, 빈 값이면 llama 기본(enabled).
[ "${SLOTS:-}" = "on"      ] && ARGS="$ARGS --slots"
[ "${SLOTS:-}" = "off"     ] && ARGS="$ARGS --no-slots"

[ -n "${THREADS:-}"        ] && ARGS="$ARGS --threads $THREADS"

# KV 캐시 양자화. V 캐시를 양자화하면 llama.cpp 가 flash attention 을
# 요구한다 — 없으면 V 캐시가 깨져 난수 같은 출력이 나옴. 따라서 양자화
# 타입을 쓸 땐 --flash-attn on 을 강제한다 (f16 은 FA 불필요).
if [ -n "${KV_TYPE:-}" ]; then
  ARGS="$ARGS --cache-type-k $KV_TYPE --cache-type-v $KV_TYPE"
  [ "$KV_TYPE" != "f16" ] && ARGS="$ARGS --flash-attn on"
fi

[ -n "${CHAT_TEMPLATE:-}"  ] && ARGS="$ARGS --chat-template $CHAT_TEMPLATE"
[ -n "${MLOCK:-}"          ] && ARGS="$ARGS --mlock"
[ -n "${NO_MMAP:-}"        ] && ARGS="$ARGS --no-mmap"
[ -n "${SERVED_MODEL_NAME:-}" ] && ARGS="$ARGS --alias $SERVED_MODEL_NAME"

# LoRA — LORA_ADAPTERS 는 공백 구분 목록.
# 단순 형식:   "adapter1.gguf adapter2.gguf"        → --lora 로 각각 로드 (scale=1.0)
# scale 포함:  "adapter1.gguf=0.8 adapter2.gguf=1.2" → --lora-scaled 로 로드
# 컨테이너의 /loras 디렉토리는 docker-compose 의 LORA_DIR bind-mount 로 제공.
if [ -n "${LORA_ADAPTERS:-}" ]; then
  for entry in $LORA_ADAPTERS; do
    case "$entry" in
      *=*) name="${entry%=*}"; scale="${entry#*=}"
           ARGS="$ARGS --lora-scaled /loras/$name $scale" ;;
      *)   ARGS="$ARGS --lora /loras/$entry" ;;
    esac
  done
fi

# EXTRA_LLAMA_ARGS 는 verbatim 추가.
EXTRA="${EXTRA_LLAMA_ARGS:-}"

echo "[run.sh] profile=${PROFILE_NAME:-?} applied_at=${PROFILE_APPLIED_AT:-?}"
echo "[run.sh] launching llama-server $ARGS $EXTRA"
# shellcheck disable=SC2086
exec /usr/local/bin/llama-server $ARGS $EXTRA
