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
The three declared node packs are copied only when missing; existing packs and
Manager updates are preserved. New images update ComfyUI and the initial node
versions for empty storage. Update existing node packs through Manager.
On startup, additional or changed `requirements.txt` files are installed into
the fresh container using `/workspace/.cache/pip`. Requirements identical to
the built-in packs are already installed in the image and are skipped.
Hugging Face and Torch caches persist under `/workspace/.cache` too.

Set `REQUIRE_PERSISTENT_MOUNT=1` in RunPod to refuse startup if `/workspace`
has not been mounted. This checks for a mount, not whether it is a Network Volume;
verify the selected storage in the RunPod console.

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
- [Reusable RunPod template settings (Russian)](docs/RUNPOD_TEMPLATE_RU.md)
