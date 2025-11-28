FROM ghcr.io/eporsche/ctranslate2-jetson-docker-image:latest AS runtime

ARG WYOMING_FASTER_WHISPER_VERSION=3.0.2

WORKDIR /app

# Copy start script
COPY start_wyoming-faster-whisper /start_wyoming-faster-whisper
RUN chmod +x /start_wyoming-faster-whisper

# Install system dependencies
RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        libcudnn8-dev \
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
    && python3 -m pip install --no-cache-dir "wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl" \
    && python3 -m pip install --no-cache-dir zeroconf \
    && rm "wyoming_faster_whisper-${WYOMING_FASTER_WHISPER_VERSION}-py3-none-any.whl" \
    && cd /app && rm -rf /tmp/wyoming-faster-whisper


RUN python3 -m pip install --force-reinstall --no-cache-dir  /opt/ctranslate2*.whl \
    && ldconfig

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
