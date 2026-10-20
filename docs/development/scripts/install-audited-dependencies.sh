#!/usr/bin/env bash
# NEXT STAGE ONLY. Not executed during the initial static security audit.
# Downloads npm packages with lifecycle scripts disabled. Does not prepare Electron/native runtimes.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/../../.." && pwd)"
cd -- "$repo_dir"

# A Corepack shim must not bootstrap a package manager as a side effect of --version.
export COREPACK_ENABLE_NETWORK=0
command -v node >/dev/null || { echo 'Preinstalled Node 22 is required.' >&2; exit 1; }
command -v pnpm >/dev/null || { echo 'Preinstalled pnpm 7.33.7 is required.' >&2; exit 1; }
[[ "$(node --version)" == v22.* ]] || { echo 'Use Node 22.' >&2; exit 1; }
[[ "$(pnpm --version)" == 7.33.7 ]] || { echo 'Use pnpm 7.33.7.' >&2; exit 1; }
git diff --quiet HEAD -- package.json pnpm-lock.yaml .npmrc || {
  echo 'Review and commit dependency/config changes before installation.' >&2; exit 1;
}
if [[ -e node_modules || -L node_modules ]]; then
  echo 'Refusing to reuse existing node_modules. Use a clean, separately authorized environment.' >&2
  exit 1
fi

# Cache outside the checkout. No broad HOME/PATH overrides, no elevated privileges.
task_cache="${TRACEMEMO_SETUP_CACHE:-${TMPDIR:-/tmp}/tracememo-reviewed-setup-${UID}}"
mkdir -p -- "$task_cache/npm" "$task_cache/pnpm-store"
export npm_config_cache="$task_cache/npm"
export npm_config_ignore_scripts=true
export npm_config_strict_ssl=true
CI=1 pnpm install --frozen-lockfile --ignore-scripts --ignore-pnpmfile \
  --strict-ssl=true --verify-store-integrity=true \
  --registry=https://registry.npmjs.org --store-dir "$task_cache/pnpm-store"

git diff --quiet HEAD -- package.json pnpm-lock.yaml .npmrc || {
  echo 'Unexpected dependency/config modification; inspect the diff. No automatic reset performed.' >&2; exit 1;
}
echo 'Dependency download completed with lifecycle scripts disabled. Native activation/build/tests remain unauthorized.'
