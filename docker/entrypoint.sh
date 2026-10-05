#!/usr/bin/env bash
set -Eeuo pipefail

data_dir="${COMFY_DATA_DIR:-/workspace}"
comfy_dir="${COMFYUI_DIR:-/opt/ComfyUI}"
port="${COMFY_PORT:-8188}"

if [ "${REQUIRE_PERSISTENT_MOUNT:-0}" = "1" ] && ! mountpoint -q "${data_dir}"; then
  echo "ERROR: ${data_dir} is not a mounted volume. Attach storage before starting." >&2
  exit 1
fi

mkdir -p \
  "${data_dir}/models" \
  "${data_dir}/input" \
  "${data_dir}/output" \
  "${data_dir}/user" \
  "${data_dir}/custom_nodes" \
  "${data_dir}/.cache/pip" \
  "${data_dir}/.cache/huggingface" \
  "${data_dir}/.cache/torch"

export PIP_CACHE_DIR="${data_dir}/.cache/pip"
export HF_HOME="${HF_HOME:-${data_dir}/.cache/huggingface}"
export TORCH_HOME="${TORCH_HOME:-${data_dir}/.cache/torch}"
echo "ComfyUI data: ${data_dir}; Hugging Face cache: ${HF_HOME}"

# Seed only missing packs. Preserve Manager updates and local changes on storage.
for seed in /opt/custom-nodes-seed/*; do
  [ -d "${seed}" ] || continue
  node_name="$(basename "${seed}")"
  if [ ! -e "${data_dir}/custom_nodes/${node_name}" ]; then
    mkdir -p "${data_dir}/custom_nodes/${node_name}"
    rsync -a "${seed}/" "${data_dir}/custom_nodes/${node_name}/"
  fi
done

link_persistent_dir() {
  local name="$1"
  rm -rf "${comfy_dir:?}/${name}"
  ln -s "${data_dir}/${name}" "${comfy_dir}/${name}"
}

link_persistent_dir models
link_persistent_dir input
link_persistent_dir output
link_persistent_dir user
link_persistent_dir custom_nodes

# Manager installs packages into the disposable container environment. Restore
# requirements for persistent Manager-installed nodes on every fresh container;
# pip skips satisfied packages and reuses the persistent wheel cache.
if [ "${INSTALL_CUSTOM_NODE_REQUIREMENTS:-1}" = "1" ]; then
  while IFS= read -r -d '' requirements; do
    node_name="$(basename "$(dirname "${requirements}")")"
    # The image already installed these exact requirement files during build.
    if cmp -s "${requirements}" "/opt/custom-nodes-seed/${node_name}/requirements.txt"; then
      continue
    fi
    echo "Restoring dependencies: ${node_name}"
    python -m pip install -r "${requirements}"
  done < <(find "${data_dir}/custom_nodes" -mindepth 2 -maxdepth 2 \
    -type f -name requirements.txt -print0)
fi

read -r -a extra_args <<< "${COMFY_ARGS:-}"

echo "Starting ComfyUI on port ${port} with integrated Manager"
exec python main.py \
  --listen 0.0.0.0 \
  --port "${port}" \
  --enable-manager \
  "${extra_args[@]}" \
  "$@"
