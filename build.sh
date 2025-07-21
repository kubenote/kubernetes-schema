#!/bin/bash -xe

# Get all v1.X.Y versions from upstream Kubernetes repo (skip v1.10–v1.18)
ALL_K8S_VERSIONS=$(git ls-remote --refs --tags https://github.com/kubernetes/kubernetes.git | cut -d/ -f3 | grep -e '^v1\.[0-9]\{2\}\.[0-9]\{1,2\}$' | grep -v -e  '^v1\.1[0-8]\{1\}' )

# Filter by prefix if provided
if [ -n "${K8S_VERSION_PREFIX}" ]; then
  ALL_K8S_VERSIONS=$(echo "$ALL_K8S_VERSIONS" | grep "^${K8S_VERSION_PREFIX}")
fi

# Get existing remote branches in current repo (assuming you're in your schemas repo)
EXISTING_BRANCHES=$(git ls-remote --heads origin \
  | awk -F'/' '{print $NF}' \
  | grep -E '^v1\.[0-9]+\.[0-9]+$')

# Determine versions that are missing
VERSIONS_TO_BUILD=$(comm -23 <(echo "$ALL_K8S_VERSIONS" | sort) <(echo "$EXISTING_BRANCHES" | sort))

echo "$VERSIONS_TO_BUILD"

# Schema generation tool
OPENAPI2JSONSCHEMABIN="docker run -i -v ${PWD}:/out ghcr.io/yannh/openapi2jsonschema:latest"

# Loop and generate schemas for missing versions
for K8S_VERSION in $VERSIONS_TO_BUILD; do
  SCHEMA="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/api/openapi-spec/swagger.json"
  PREFIX="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/${K8S_VERSION}/_definitions.json"

  if [ ! -d "schemas/${K8S_VERSION}-standalone-strict" ]; then
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}-standalone-strict" --expanded --kubernetes --stand-alone --strict "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}-standalone-strict" --kubernetes --stand-alone --strict "${SCHEMA}"
  fi

  if [ ! -d "schemas/${K8S_VERSION}-standalone" ]; then
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}-standalone" --expanded --kubernetes --stand-alone "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}-standalone" --kubernetes --stand-alone "${SCHEMA}"
  fi

  if [ ! -d "schemas/${K8S_VERSION}-local" ]; then
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}-local" --expanded --kubernetes "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}-local" --kubernetes "${SCHEMA}"
  fi

  if [ ! -d "schemas/${K8S_VERSION}" ]; then
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}" --expanded --kubernetes --prefix "${PREFIX}" "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}" --kubernetes --prefix "${PREFIX}" "${SCHEMA}"
  fi
done
