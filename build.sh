#!/bin/bash
set -euo pipefail

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || error_exit "git not found"
command -v docker >/dev/null 2>&1 || error_exit "docker not found"

REPO_DIR="$(pwd)"
WORKDIR="$REPO_DIR/schemas"
OPENAPI2JSONSCHEMA="docker run -i -v ${WORKDIR}:/out/schemas ghcr.io/yannh/openapi2jsonschema:latest"

log "Creating work directory at $WORKDIR"
mkdir -p "$WORKDIR"
cd "$REPO_DIR"

log "Fetching Kubernetes versions."
ALL_K8S_VERSIONS=$(git ls-remote --refs --tags https://github.com/kubernetes/kubernetes.git \
  | cut -d/ -f3 \
  | sed 's/,$/\n/' \
  | grep -E '^v1\.[0-9]+\.[0-9]+$' \
  | grep -vE '^v1\.(0|1[0-8])' \
  | sort -Vu)

log "Detected ${ALL_K8S_VERSIONS// /, }"

log "Checking local/remote existing branches..."
git fetch --all --prune
EXISTING_BRANCHES=$(git branch -r   
  | sed 's|origin/||'    
  | sort -Vu)

log "Existing branches: ${EXISTING_BRANCHES// /, }"

K8S_VERSIONS=""
for version in $ALL_K8S_VERSIONS; do
  if ! grep -qxF "$version" <<< "$EXISTING_BRANCHES"; then
    K8S_VERSIONS+="$version"$'\n'
  fi
done
K8S_VERSIONS=$(echo "$K8S_VERSIONS" | sort -u)


if [[ -z "$K8S_VERSIONS" ]]; then
  log "No new versions to process."
  exit 0
fi

log "Versions to generate: ${K8S_VERSIONS// /, }"
cd "$WORKDIR"

for K8S_VERSION in $K8S_VERSIONS; do
  log "Starting generation for $K8S_VERSION"

  VERSION_DIR="$WORKDIR/$K8S_VERSION-tmp"
  mkdir -p "$VERSION_DIR"

  SCHEMA_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/api/openapi-spec/swagger.json"
  PREFIX_URL="https://raw.githubusercontent.com/kube-forge/k8s-schema/${K8S_VERSION}/raw/_definitions.json"

  log "Validating schema URL: $SCHEMA_URL"
  if ! curl -fsI "$SCHEMA_URL" >/dev/null; then
    log "Skipping $K8S_VERSION - schema URL not reachable"
    continue
  fi

  for mode in \
    "standalone-strict --expanded --kubernetes --stand-alone --strict" \
    "standalone --expanded --kubernetes --stand-alone" \
    "local --expanded --kubernetes" \
    "raw --expanded --kubernetes --prefix $PREFIX_URL"; do

    OUT_DIR="$VERSION_DIR/$(cut -d' ' -f1 <<< "$mode")"
    ARGS="${mode#* }"

    log "Generating $OUT_DIR for $K8S_VERSION..."
    if ! $OPENAPI2JSONSCHEMA -o "$OUT_DIR" $ARGS "$SCHEMA_URL"; then
      error_exit "Failed to generate $OUT_DIR for $K8S_VERSION"
    fi
  done

  cd "$REPO_DIR"
  log "Creating worktree for $K8S_VERSION"
  git worktree add --orphan "$K8S_VERSION" "$WORKDIR/$K8S_VERSION-branch"
  cd "$WORKDIR/$K8S_VERSION-branch"

  rm -rf *
  cp -r "$VERSION_DIR/"* .

  git add .
  git commit -m "Add schemas for $K8S_VERSION"
  git push origin "$K8S_VERSION"

  log "Cleaning up worktree and temp files for $K8S_VERSION"
  rm -rf "$VERSION_DIR"
  git worktree remove "$WORKDIR/$K8S_VERSION-branch" --force
done

log "All done. Schemas processed and pushed."
