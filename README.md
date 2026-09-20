# Portable ComfyUI container

Fresh ComfyUI on CUDA 12.8 with the integrated Registry-backed Manager and the
following node packs:

- `AlexYez/comfyui-timesaver`
- `AlexYez/comfyui-artius-browser`
- `AlexYez/comfyui-ts-cosyvoice`

The image is rebuilt weekly and on relevant source changes. The integrated
Manager is installed from ComfyUI's `manager_requirements.txt` and enabled at
runtime with `--enable-manager`; the legacy Manager custom node is not used.

## Persistent data

Mount persistent or temporary storage at `/workspace`. The container stores
models, input, output, user settings, and Manager-installed custom nodes there.
The three declared node packs are refreshed from the versions baked into each
image while any additional Manager-installed nodes are preserved. On startup,
their `requirements.txt` files are installed into the fresh container using a
persistent pip download cache at `/workspace/.cache/pip`.

Set `INSTALL_CUSTOM_NODE_REQUIREMENTS=0` only when dependency restoration is
handled by another bootstrap process.

## Run

```bash
docker run --rm --gpus all \
  -p 8188:8188 \
  -v /workspace:/workspace \
  ghcr.io/alexyez/timesaver-comfyui-docker:cu128
```

Open port `8188` through the provider's HTTP proxy. Extra ComfyUI flags can be
passed through `COMFY_ARGS`, for example:

```bash
docker run --rm --gpus all \
  -p 8188:8188 \
  -e COMFY_ARGS="--preview-method auto" \
  -v /workspace:/workspace \
  ghcr.io/alexyez/timesaver-comfyui-docker:cu128
```

Do not store provider credentials or Hugging Face tokens in the image. Supply
them as environment variables or provider secrets at runtime.

## Project documentation

- [Current project state and decisions (Russian)](docs/PROJECT_MEMORY_RU.md)
- [RunPod operations and recovery guide (Russian)](docs/RUNPOD_RUNBOOK_RU.md)
