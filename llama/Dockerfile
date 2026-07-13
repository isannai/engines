# syntax=docker/dockerfile:1.7
#
# isannai/llama — llama.cpp server image. Same pattern as isannai/sd:
# two-stage build (CUDA dev → CUDA runtime), entrypoint is the upstream
# llama-server binary. iSANN's provider/isannd manages lifecycle through
# docker; this image is just llama.cpp + minimal CUDA runtime.
#
# Build (from anywhere):
#   docker build --build-arg LLAMA_REF=master \
#     -t isannai/llama:latest \
#     -f package-stage/isann/engines/llama/Dockerfile package-stage/isann/engines/llama/
#
# 운영은 docker-compose.yml + .env 로 — broker UI 의 Start/Stop 누르면
# isannd 가 docker start/stop 으로 lifecycle 제어.

###############################################################################
# Stage 1 — llama.cpp build (CUDA dev base, produces `llama-server`)
###############################################################################
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS llama-build

ARG LLAMA_REF=master
# CUDA arch — sd 와 동일 컨벤션. 기본 floor = Pascal(60), Pascal..Blackwell 커버.
# 단일 값으로 좁히면 빌드 시간 크게 단축 (--build-arg CUDA_ARCHS=86 등).
#   60=P100, 61=GTX 10xx, 70=V100, 75=RTX 20xx/GTX 16xx,
#   80=A100, 86=RTX 30xx, 89=RTX 40xx, 90=H100,
#   100=B100/B200 (Blackwell DC), 120=RTX 50xx (Blackwell consumer)
ARG CUDA_ARCHS="60;61;70;75;80;86;89;90;100;120"

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      cmake \
      build-essential \
      ca-certificates \
      libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone + checkout. Two-step 이라 branch / tag / commit 모두 지원.
# 큰 레포 + 불안정한 회사망 대비: postBuffer 늘리고, lowSpeed 타임아웃 끄고,
# 5회까지 재시도. GnuTLS recv error 같은 transient TLS 끊김에 대한 방어.
RUN git config --global http.postBuffer 524288000 && \
    git config --global http.lowSpeedLimit 0 && \
    git config --global http.lowSpeedTime 999999 && \
    for i in 1 2 3 4 5; do \
      rm -rf /src && \
      git clone https://github.com/ggerganov/llama.cpp.git /src && break || \
      (echo "clone attempt $i failed, retrying..." && sleep 5); \
    done && \
    test -d /src/.git
WORKDIR /src
RUN for i in 1 2 3 4 5; do \
      git checkout ${LLAMA_REF} && \
      git submodule update --init --recursive && break || \
      (echo "checkout/submodule attempt $i failed, retrying..." && sleep 5); \
    done

# GGML_CUDA=ON 이 CUDA 백엔드 활성화 (구버전의 LLAMA_CUBLAS 후신). server
# 타겟은 examples/server 에서 빌드됨. LLAMA_CURL=ON 은 server 가 모델
# URL 로 다운받을 수 있게 — 운영자가 mount 만 사용한다면 켜둬도 무해.
RUN cmake -B build \
      -DGGML_CUDA=ON \
      -DLLAMA_CURL=ON \
      -DLLAMA_BUILD_UI=OFF \
      -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
      -DBUILD_SHARED_LIBS=OFF && \
    cmake --build build --target llama-server -j"$(nproc)"

###############################################################################
# Stage 2 — runtime
###############################################################################
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
      libgomp1 \
      libcurl4 \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy server binary. 이름은 llama.cpp 의 최신 컨벤션 (`llama-server`).
COPY --from=llama-build /src/build/bin/llama-server /usr/local/bin/llama-server

VOLUME ["/models", "/loras"]

EXPOSE 8080

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# 기본 ENTRYPOINT 는 docker-compose 가 run.sh 로 override 함 — 직접
# `docker run isannai/llama` 호출 시엔 server 가 인자 없이 떠서 모델
# 안 잡힌 채로 부팅 실패. 운영은 compose 통해서만 권장.
ENTRYPOINT ["/usr/local/bin/llama-server"]
CMD ["--host", "0.0.0.0", "--port", "8080"]
