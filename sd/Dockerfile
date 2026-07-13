# syntax=docker/dockerfile:1.7
#
# isannai/sd — sd.cpp engine exposed as an external HTTP service for
# iSANN's vllm.external-style "external launcher" pattern. iSANN does
# NOT spawn this container; the operator runs it directly and registers
# the endpoint in provider.json.
#
# Build (from anywhere):
#   docker build --build-arg SDCPP_REF=master \
#     -t isannai/sd:latest \
#     -f deploy/engines/sd/Dockerfile deploy/engines/sd/
#
# Or via the helper:
#   ./deploy/engines/sd/build.sh
#
# Run (operator side, like `docker run vllm/vllm-openai`):
#   docker run -d --name sd --gpus all \
#     -p 7860:7860 \
#     -v "$(pwd)/models:/models" \
#     -v "$(pwd)/outputs:/outputs" \
#     isannai/sd:latest \
#       --model /models/v1-5-pruned-emaonly.safetensors \
#       --host 0.0.0.0 --port 7860
#
# The operator then adds a service entry in provider.json pointing to
# host:7860 and selects the sd.cpp.external engine manifest. Provider
# probes ready_check + (optionally) scrapes metrics + proxies API
# requests — never spawns this binary itself.
#
# No GLink Go wrapper. The image is just sd.cpp's upstream sd-server
# (+ sd-cli) binary plus a minimal CUDA runtime.

###############################################################################
# Stage 1 — sd.cpp build (CUDA dev base, produces `sd-cli` + `sd-server`)
###############################################################################
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS sdcpp-build

ARG SDCPP_REF=master
# CUDA arch to build for. Default covers Pascal..Blackwell.
# Set to a single value to cut build time dramatically:
#   60=P100, 61=GTX 10xx, 70=V100, 75=RTX 20xx/GTX 16xx,
#   80=A100, 86=RTX 30xx, 89=RTX 40xx, 90=H100,
#   100=B100/B200 (Blackwell DC), 120=RTX 50xx (Blackwell consumer)
# e.g. for RTX 3060 only:  --build-arg CUDA_ARCHS=86
# default floor = Pascal (60), covers Pascal..Blackwell.
ARG CUDA_ARCHS="60;61;70;75;80;86;89;90;100;120"

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      cmake \
      build-essential \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone the repo then checkout the requested ref. Using a two-step clone+
# checkout works for branches, tags, AND raw commit hashes (`git clone
# --branch` only accepts the first two).
# 큰 레포 + 불안정한 회사망(특히 무선) 대비: postBuffer 늘리고,
# lowSpeed 타임아웃 끄고, 5회까지 재시도. GnuTLS recv error 같은
# transient TLS 끊김에 대한 방어.
RUN git config --global http.postBuffer 524288000 && \
    git config --global http.lowSpeedLimit 0 && \
    git config --global http.lowSpeedTime 999999 && \
    for i in 1 2 3 4 5; do \
      rm -rf /src && \
      git clone https://github.com/leejet/stable-diffusion.cpp.git /src && break || \
      (echo "clone attempt $i failed, retrying..." && sleep 5); \
    done && \
    test -d /src/.git
WORKDIR /src
RUN for i in 1 2 3 4 5; do \
      git checkout ${SDCPP_REF} && \
      git submodule update --init --recursive && break || \
      (echo "checkout/submodule attempt $i failed, retrying..." && sleep 5); \
    done

# SD_CUDA=ON enables the CUDA backend (current flag; older sd.cpp used
# SD_CUBLAS, now removed). The default cmake configuration builds both
# the `sd` CLI and the `server` example (HTTP server) under build/bin/.
# If upstream relocates or renames the server target, fix the COPY paths
# in the runtime stage.
RUN cmake -B build \
      -DSD_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" && \
    cmake --build build -j"$(nproc)"

###############################################################################
# Stage 2 — runtime (slim CUDA runtime, no compiler, no Go)
###############################################################################
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# libgomp1 is required by sd.cpp's OpenMP backend. ca-certificates lets the
# server fetch over HTTPS when configured (model download / remote refs).
RUN apt-get update && apt-get install -y --no-install-recommends \
      libgomp1 \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy both binaries:
#   /usr/local/bin/sd-cli     — CLI, one-shot/offline use + debugging
#   /usr/local/bin/sd-server  — HTTP server, default entrypoint
# Names match what pkg/setup/project_sd.go expects from upstream
# leejet/stable-diffusion.cpp. Adjust if upstream renames.
COPY --from=sdcpp-build /src/build/bin/sd-cli    /usr/local/bin/sd-cli
COPY --from=sdcpp-build /src/build/bin/sd-server /usr/local/bin/sd-server

# Persistent volumes — host bind-mounts go here. /models is the model
# weights store; /outputs receives generated images.
VOLUME ["/models", "/outputs"]

EXPOSE 8080

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Default entrypoint runs the HTTP server. Operator MUST pass --model on
# `docker run` because we deliberately don't bake a default model into
# the image. sd.cpp's server binds to 0.0.0.0 by default; port is
# overridable via --listen-port.
ENTRYPOINT ["/usr/local/bin/sd-server"]
CMD ["--listen-ip", "0.0.0.0", "--listen-port", "8080"]
