#!/bin/sh
# Container entrypoint for isannai/sd.
#
# 호스트의 .env 를 컨테이너의 /conf/sd.env 로 bind-mount 한 다음 매 시작
# 시 이 스크립트가 source 해서 sd-server 인자를 만든다. 운영자는:
#
#   docker stop sd
#   vim .env                          # MODEL, STEPS, ... 수정
#   docker start sd                   # 새 값으로 sd-server 재시작
#
# 의 흐름으로 rm 없이 설정 변경. 컨테이너 id / network IP / logs 보존.

set -eu

CONF=/conf/sd.env
if [ ! -r "$CONF" ]; then
  echo "[run.sh] $CONF not found — bind-mount your .env into the container" >&2
  exit 1
fi

# .env 는 KEY=VALUE 라인 형태. set -a 후 source 하면 모든 변수가
# 자동 export — 자식 프로세스 (sd-server) 에도 환경변수로 전파됨.
set -a
# shellcheck disable=SC1090
. "$CONF"
set +a

if [ -z "${MODEL:-}" ]; then
  echo "[run.sh] MODEL is required (set it in .env)" >&2
  exit 1
fi

ARGS="--model /models/$MODEL"
ARGS="$ARGS --listen-ip 0.0.0.0 --listen-port 8080"
ARGS="$ARGS --steps ${STEPS:-20}"
ARGS="$ARGS --cfg-scale ${CFG_SCALE:-7}"

[ -n "${SAMPLE_METHOD:-}" ] && ARGS="$ARGS --sampling-method $SAMPLE_METHOD"
[ -n "${THREADS:-}"       ] && ARGS="$ARGS -t $THREADS"
[ -n "${VAE_FILE:-}"      ] && ARGS="$ARGS --vae /vae/$VAE_FILE"
[ -n "${LORA_DIR:-}"      ] && ARGS="$ARGS --lora-model-dir /loras"
[ -n "${VAE_ON_CPU:-}"    ] && ARGS="$ARGS --vae-on-cpu"
[ -n "${CLIP_ON_CPU:-}"   ] && ARGS="$ARGS --clip-on-cpu"

# EXTRA_SD_ARGS 는 verbatim 추가. quoted 인자 깨지지 않게 eval 로 평가.
EXTRA="${EXTRA_SD_ARGS:-}"

echo "[run.sh] profile=${PROFILE_NAME:-?} applied_at=${PROFILE_APPLIED_AT:-?}"
echo "[run.sh] launching sd-server $ARGS $EXTRA"
# shellcheck disable=SC2086
exec /usr/local/bin/sd-server $ARGS $EXTRA
