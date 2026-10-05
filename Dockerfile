# syntax=docker/dockerfile:1.7
ARG CUDA_IMAGE=nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
FROM ${CUDA_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG COMFYUI_REF=master

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:${PATH} \
    COMFYUI_DIR=/opt/ComfyUI \
    COMFY_DATA_DIR=/workspace \
    COMFY_PORT=8188

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      ffmpeg \
      git \
      libgl1 \
      libglib2.0-0 \
      libsndfile1 \
      python3 \
      python3-pip \
      python3-venv \
      rsync \
      tini \
      util-linux \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv "${VIRTUAL_ENV}" \
    && python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# CUDA 12.8 is the compatibility baseline for Blackwell/RTX 50-series hosts.
RUN python -m pip install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cu128 \
      torch torchvision torchaudio

RUN git clone --depth 1 --branch "${COMFYUI_REF}" \
      https://github.com/Comfy-Org/ComfyUI.git "${COMFYUI_DIR}" \
    && python -m pip install --no-cache-dir -r "${COMFYUI_DIR}/requirements.txt" \
    && python -m pip install --no-cache-dir -r "${COMFYUI_DIR}/manager_requirements.txt"

COPY custom-nodes.txt /tmp/custom-nodes.txt

RUN mkdir -p /opt/custom-nodes-seed \
    && while IFS= read -r repo; do \
         [ -z "${repo}" ] && continue; \
         name="$(basename "${repo}" .git)"; \
         git clone --depth 1 "${repo}" "/opt/custom-nodes-seed/${name}"; \
         if [ -f "/opt/custom-nodes-seed/${name}/requirements.txt" ]; then \
           python -m pip install --no-cache-dir -r "/opt/custom-nodes-seed/${name}/requirements.txt"; \
         fi; \
       done < /tmp/custom-nodes.txt \
    && python -m pip install --no-cache-dir onnxruntime-gpu \
    && rm /tmp/custom-nodes.txt

COPY docker/entrypoint.sh /usr/local/bin/comfy-entrypoint
RUN chmod +x /usr/local/bin/comfy-entrypoint

WORKDIR ${COMFYUI_DIR}
EXPOSE 8188

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=5 \
  CMD curl --fail --silent "http://127.0.0.1:${COMFY_PORT}/system_stats" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/comfy-entrypoint"]
