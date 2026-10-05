#!/usr/bin/env bash
# Run only in a disposable Linux container, with /workspace mounted for the test.
set -Eeuo pipefail
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
export COMFYUI_DIR="${test_root}/ComfyUI"
export COMFY_DATA_DIR=/workspace
export REQUIRE_PERSISTENT_MOUNT=1
export TEST_CALLS="${test_root}/python-calls"
mkdir -p "${COMFYUI_DIR}" "${test_root}/bin" /opt/custom-nodes-seed/test-pack
printf 'initial node\n' > /opt/custom-nodes-seed/test-pack/node.txt
printf 'example-package==1.0\n' > /opt/custom-nodes-seed/test-pack/requirements.txt
printf '%s\n' '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >> "$TEST_CALLS"' \
  'if [ "$1" = main.py ]; then' \
  '  test "$HF_HOME" = /workspace/.cache/huggingface' \
  '  test "$TORCH_HOME" = /workspace/.cache/torch' \
  '  test "$PIP_CACHE_DIR" = /workspace/.cache/pip' \
  'fi' > "${test_root}/bin/python"
chmod +x "${test_root}/bin/python"
export PATH="${test_root}/bin:${PATH}"

bash /test-entrypoint.sh
cmp /opt/custom-nodes-seed/test-pack/node.txt /workspace/custom_nodes/test-pack/node.txt
test -L "${COMFYUI_DIR}/models"
test "$(readlink "${COMFYUI_DIR}/models")" = /workspace/models
grep -q -- '--enable-manager' "${TEST_CALLS}"
if grep -q -- '-m pip' "${TEST_CALLS}"; then
  echo 'FAIL: unchanged baked requirements were reinstalled' >&2
  exit 1
fi

# Simulate Manager changes, additional nodes, and a saved model/workflow.
printf 'updated node\n' > /workspace/custom_nodes/test-pack/node.txt
printf 'example-package==2.0\n' > /workspace/custom_nodes/test-pack/requirements.txt
mkdir -p /workspace/custom_nodes/extra-pack
printf 'extra-package==1.0\n' > /workspace/custom_nodes/extra-pack/requirements.txt
printf 'saved model\n' > /workspace/models/test-model.txt
printf '{}\n' > /workspace/user/test-workflow.json
bash /test-entrypoint.sh
grep -q 'updated node' /workspace/custom_nodes/test-pack/node.txt
grep -q -- '-m pip install -r /workspace/custom_nodes/test-pack/requirements.txt' "${TEST_CALLS}"
grep -q -- '-m pip install -r /workspace/custom_nodes/extra-pack/requirements.txt' "${TEST_CALLS}"
test -f /workspace/models/test-model.txt
test -f /workspace/user/test-workflow.json

# Missing mounts must fail before creating data or invoking ComfyUI.
if COMFY_DATA_DIR="${test_root}/unmounted" bash /test-entrypoint.sh; then
  echo 'FAIL: unmounted storage was accepted' >&2
  exit 1
fi
test ! -e "${test_root}/unmounted"
echo 'PASS: seed, preserved updates, dependency restore, caches, links, mount guard'
