#!/usr/bin/env bash
set -Eeuo pipefail

data_dir="${COMFY_DATA_DIR:-/workspace}"
comfy_dir="${COMFYUI_DIR:-/opt/ComfyUI}"
port="${COMFY_PORT:-8188}"

mkdir -p \
  "${data_dir}/models" \
  "${data_dir}/input" \
  "${data_dir}/output" \
  "${data_dir}/user" \
  "${data_dir}/custom_nodes" \
  "${data_dir}/.cache/pip"

export PIP_CACHE_DIR="${data_dir}/.cache/pip"

# Declared node packs follow the tested versions baked into the image. Nodes
# installed later through Manager remain alongside them on persistent storage.
for seed in /opt/custom-nodes-seed/*; do
  [ -d "${seed}" ] || continue
  node_name="$(basename "${seed}")"
  mkdir -p "${data_dir}/custom_nodes/${node_name}"
  rsync -a --delete "${seed}/" "${data_dir}/custom_nodes/${node_name}/"
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
    python -m pip install -r "${requirements}"
  done < <(find "${data_dir}/custom_nodes" -mindepth 2 -maxdepth 2 \
    -type f -name requirements.txt -print0)
fi

read -r -a extra_args <<< "${COMFY_ARGS:-}"

exec python main.py \
  --listen 0.0.0.0 \
  --port "${port}" \
  --enable-manager \
  "${extra_args[@]}" \
  "$@"
