#!/bin/sh
# Container entrypoint for vllm/vllm-openai.
#
# 호스트의 .env 를 컨테이너의 /conf/vllm.env 로 bind-mount 한 다음 매 시작
# 시 이 스크립트가 source 해서 vllm 인자를 만든다. 운영자는:
#
#   docker stop vllm
#   vim .env                          # MODEL, QUANTIZATION, ... 수정
#   docker start vllm                 # 새 값으로 vllm-openai 재시작
#
# 의 흐름으로 rm 없이 설정 변경. 컨테이너 id / network IP / logs 보존.

set -eu

CONF=/conf/vllm.env
if [ ! -r "$CONF" ]; then
  echo "[run.sh] $CONF not found — bind-mount your .env into the container" >&2
  exit 1
fi

# .env 는 KEY=VALUE 라인 형태. set -a 후 source 하면 모든 변수가
# 자동 export — 자식 프로세스 (vllm) 에도 환경변수로 전파됨.
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
ARGS="$ARGS --served-model-name ${SERVED_MODEL_NAME:-$MODEL}"
ARGS="$ARGS --max-model-len ${MAX_MODEL_LEN:-16384}"
ARGS="$ARGS --gpu-memory-utilization ${GPU_MEMORY_UTILIZATION:-0.75}"
ARGS="$ARGS --max-num-seqs ${MAX_NUM_SEQS:-1}"

[ -n "${QUANTIZATION:-}"         ] && ARGS="$ARGS --quantization $QUANTIZATION"
[ -n "${ENFORCE_EAGER:-}"        ] && ARGS="$ARGS --enforce-eager"
[ -n "${DTYPE:-}"                ] && ARGS="$ARGS --dtype $DTYPE"
[ -n "${KV_CACHE_DTYPE:-}"       ] && ARGS="$ARGS --kv-cache-dtype $KV_CACHE_DTYPE"
[ -n "${TENSOR_PARALLEL_SIZE:-}" ] && ARGS="$ARGS --tensor-parallel-size $TENSOR_PARALLEL_SIZE"

# LoRA — LORA_MODULES 가 비어있지 않으면 --enable-lora 와 함께 등록.
# 컨테이너의 /loras 디렉토리는 docker-compose 의 LORA_DIR bind-mount 로 제공.
if [ -n "${LORA_MODULES:-}" ]; then
  ARGS="$ARGS --enable-lora --lora-modules $LORA_MODULES"
  ARGS="$ARGS --max-loras ${MAX_LORAS:-1} --max-lora-rank ${MAX_LORA_RANK:-16}"
fi

# EXTRA_VLLM_ARGS 는 verbatim 추가. quoted 인자 깨지지 않게 그대로 expansion.
EXTRA="${EXTRA_VLLM_ARGS:-}"

echo "[run.sh] profile=${PROFILE_NAME:-?} applied_at=${PROFILE_APPLIED_AT:-?}"
echo "[run.sh] launching vllm-openai $ARGS $EXTRA"
# shellcheck disable=SC2086
exec python3 -m vllm.entrypoints.openai.api_server $ARGS $EXTRA
