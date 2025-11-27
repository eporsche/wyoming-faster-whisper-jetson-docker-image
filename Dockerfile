FROM nvcr.io/nvidia/l4t-cuda:12.2.2-devel-arm64-ubuntu22.04 AS base

ARG WYOMING_FASTER_WHISPER_VERSION=3.0.2

WORKDIR /app

# Copy start script
COPY start_wyoming-faster-whisper /start_wyoming-faster-whisper
RUN chmod +x /start_wyoming-faster-whisper

RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
    \
    && pip3 install --no-cache-dir -U \
        setuptools \
        wheel \
    && pip3 install --no-cache-dir \
        --extra-index-url 'https://download.pytorch.org/whl/cpu' \
        'torch==2.6.0' \
    \
    && rm -rf /var/lib/apt/lists/*


RUN apt-get update && apt-get install -y wget ca-certificates && rm -rf /var/lib/apt/lists/*

ENV WYOMING_FASTER_WHISPER_URL="https://github.com/rhasspy/wyoming-faster-whisper/releases/download/v${WYOMING_FASTER_WHISPER_VERSION}"

RUN set -e \
    && echo "Downloading wyoming-faster-whisper ${WYOMING_FASTER_WHISPER_VERSION}" \
    && mkdir -p /tmp/wyoming-faster-whisper && cd /tmp/wyoming-faster-whisper \
    && wget $WGET_FLAGS "${WYOMING_FASTER_WHISPER_URL}/wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl" \
    && pip3 install --no-cache-dir "wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl[transformers,sherpa,onnx-asr]" \
    && rm "wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl" \
    && cd /app && rm -rf /tmp/wyoming-faster-whisper

# Environment variables with defaults for whisper configuration
ENV WHISPER_PORT=10300 \
    WHISPER_MODEL=medium-int8 \
    WHISPER_BEAM_SIZE=1 \
    WHISPER_COMPUTE_TYPE=int8 \
    WHISPER_LANGUAGE=de \
    WHISPER_DEBUG=false \
    WHISPER_OFFLINE=false

CMD ["/start_wyoming-faster-whisper"]

EXPOSE 10300
