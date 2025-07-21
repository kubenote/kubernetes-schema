#!/bin/bash
set -euo pipefail

REPO_DIR="$(pwd)"
WORKDIR="$(pwd)/schemas"
OPENAPI2JSONSCHEMA="docker run -i -v ${WORKDIR}:/out/schemas ghcr.io/yannh/openapi2jsonschema:latest"

mkdir -p "$WORKDIR"
cd "$REPO_DIR"


# Fetch all upstream K8s versions >= v1.19.0
ALL_K8S_VERSIONS=$(git ls-remote --refs --tags https://github.com/kubernetes/kubernetes.git \
  | cut -d/ -f3 \
  | sed 's/,$/\n/' \
  | grep -E '^v1\.[0-9]+\.[0-9]+$' \
  | grep -vE '^v1\.(0|1[0-8])' \
  | sort -Vu)

# Get existing local and remote branches, normalized
EXISTING_BRANCHES=$(git branch -a \
  | sed 's|remotes/origin/||' \
  | sed 's|\* ||' \
  | sed 's|^+ ||' \
  | sed 's/,$/\n/' \
  | grep -E '^v1\.[0-9]+\.[0-9]+$' \
  | sort -Vu)

# Filter versions not already in the repo
K8S_VERSIONS=$(comm -23 \
  <(echo "$ALL_K8S_VERSIONS" | tr ',' '\n' | sort -u) \
  <(echo "$EXISTING_BRANCHES" | tr ',' '\n' | sort -u))


cd "$WORKDIR"

for K8S_VERSION in $K8S_VERSIONS; do
  echo "Generating schemas for $K8S_VERSION..."

  VERSION_DIR="$WORKDIR/$K8S_VERSION-tmp"
  mkdir -p "$VERSION_DIR"

  SCHEMA_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/api/openapi-spec/swagger.json"
  PREFIX_URL="https://raw.githubusercontent.com/kube-forge/k8s-schema/${K8S_VERSION}/raw/_definitions.json"

  $OPENAPI2JSONSCHEMA -o "$VERSION_DIR/standalone-strict" --expanded --kubernetes --stand-alone --strict "$SCHEMA_URL"
  $OPENAPI2JSONSCHEMA -o "$VERSION_DIR/standalone"         --expanded --kubernetes --stand-alone "$SCHEMA_URL"
  $OPENAPI2JSONSCHEMA -o "$VERSION_DIR/local"             --expanded --kubernetes "$SCHEMA_URL"
  $OPENAPI2JSONSCHEMA -o "$VERSION_DIR/raw"               --expanded --kubernetes --prefix "$PREFIX_URL" "$SCHEMA_URL"

  cd "$REPO_DIR"
  git worktree add --orphan "$K8S_VERSION" "$WORKDIR/$K8S_VERSION-branch"
  cd "$WORKDIR/$K8S_VERSION-branch"

  rm -rf *
  cp -r "$VERSION_DIR/raw" ./raw
  cp -r "$VERSION_DIR/local" ./local
  cp -r "$VERSION_DIR/standalone" ./standalone
  cp -r "$VERSION_DIR/standalone-strict" ./standalone-strict

  git add .
  git commit -m "Add schemas for $K8S_VERSION"
  git push origin "$K8S_VERSION"

  rm -rf "$VERSION_DIR"
  git worktree remove "$WORKDIR/$K8S_VERSION-branch" --force

done

echo "Done: new versions processed and pushed."
