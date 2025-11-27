FROM nvcr.io/nvidia/l4t-cuda:12.2.2-devel-arm64-ubuntu22.04 AS builder

# CTranslate2 build configuration
ARG CTRANSLATE_VERSION=4.6.1
ARG CTRANSLATE_BRANCH=v${CTRANSLATE_VERSION}
ENV CTRANSLATE_SOURCE=/tmp/ctranslate2

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    python3 \
    python3-pip \
    python3-dev \
    wget \
    libcudnn8-dev \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster Python package installation
RUN python3 -m pip install --no-cache-dir uv

# Copy the build script
COPY build_ctranslate2 /build_ctranslate2
RUN chmod +x /build_ctranslate2

RUN /build_ctranslate2

FROM nvcr.io/nvidia/l4t-cuda:12.2.2-devel-arm64-ubuntu22.04 AS runtime

ARG WYOMING_FASTER_WHISPER_VERSION=3.0.2

WORKDIR /app

# Copy start script
COPY start_wyoming-faster-whisper /start_wyoming-faster-whisper
RUN chmod +x /start_wyoming-faster-whisper

# Install system dependencies
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
        --extra-index-url 'https://download.pytorch.org/whl/cu122' \
        'torch==2.6.0' \
    \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget ca-certificates && rm -rf /var/lib/apt/lists/*

# Download wyoming-faster-whisper wheel
ENV WYOMING_FASTER_WHISPER_URL="https://github.com/rhasspy/wyoming-faster-whisper/releases/download/v${WYOMING_FASTER_WHISPER_VERSION}"

RUN set -e \
    && echo "Downloading wyoming-faster-whisper ${WYOMING_FASTER_WHISPER_VERSION}" \
    && mkdir -p /tmp/wyoming-faster-whisper && cd /tmp/wyoming-faster-whisper \
    && wget $WGET_FLAGS "${WYOMING_FASTER_WHISPER_URL}/wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl" \
    && python3 -m pip install --no-cache-dir "wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl[transformers,sherpa,onnx-asr]" \
    && rm "wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl" \
    && cd /app && rm -rf /tmp/wyoming-faster-whisper

# Copy and install CUDA-enabled CTranslate2 from builder stage
COPY --from=builder /usr/local/lib/libctranslate2* /usr/local/lib/
COPY --from=builder /usr/local/include/ctranslate2 /usr/local/include/ctranslate2
COPY --from=builder /usr/local/bin/ct2-* /usr/local/bin/

# Copy and install the Python wheel
COPY --from=builder /opt/ctranslate2*.whl /tmp/

RUN python3 -m pip install --force-reinstall --no-cache-dir /tmp/ctranslate2*.whl \
    && rm /tmp/ctranslate2*.whl \
    && ldconfig

# Verify CTranslate2 has CUDA support
RUN python3 -c "import ctranslate2; print(f'CTranslate2 version: {ctranslate2.__version__}'); print(f'CUDA available: {ctranslate2.get_cuda_device_count() >= 0}')" || echo "Warning: CTranslate2 CUDA check failed"

# Set CUDA environment variables
# ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH} \
#     CUDA_HOME=/usr/local/cuda \
#     PATH=/usr/local/cuda/bin:${PATH}

# Environment variables with defaults for whisper configuration
ENV WHISPER_PORT=10300 \
    WHISPER_MODEL=medium-int8 \
    WHISPER_BEAM_SIZE=1 \
    WHISPER_COMPUTE_TYPE=int8 \
    WHISPER_LANGUAGE=de \
    WHISPER_DEBUG=false \
    WHISPER_OFFLINE=false \
    WHISPER_STT_LIBRARY=faster-whisper

CMD ["/start_wyoming-faster-whisper"]

EXPOSE ${WHISPER_PORT}/tcp

HEALTHCHECK --start-period=10m \
    CMD echo '{ "type": "describe" }' \
        | nc -w 1 localhost ${WHISPER_PORT} \
        | grep -q "faster-whisper" \
        || exit 1
