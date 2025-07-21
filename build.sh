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


if [[ -z "$VERSIONS_TO_BUILD" ]]; then
  echo "No new versions to build. Exiting successfully."
  exit 0
fi

echo "Versions to build:"
echo "$VERSIONS_TO_BUILD"

# Schema generation tool
OPENAPI2JSONSCHEMABIN="docker run --rm -i -u $(id -u):$(id -g) -v ${PWD}:/out/schemas ghcr.io/yannh/openapi2jsonschema:latest"


# Loop and generate schemas for missing versions
for K8S_VERSION in $VERSIONS_TO_BUILD; do
  SCHEMA="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/api/openapi-spec/swagger.json"
  PREFIX="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/${K8S_VERSION}/_definitions.json"
  mkdir "schemas/${K8S_VERSION}"
  
  if [ ! -d "schemas/${K8S_VERSION}/standalone-strict" ]; then
    mkdir "schemas/${K8S_VERSION}/standalone-strict"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/standalone-strict" --expanded --kubernetes --stand-alone --strict "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/standalone-strict" --kubernetes --stand-alone --strict "${SCHEMA}"
  fi

  if [ ! -d "schemas/${K8S_VERSION}/standalone" ]; then
    mkdir "schemas/${K8S_VERSION}/standalone"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/standalone" --expanded --kubernetes --stand-alone "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/standalone" --kubernetes --stand-alone "${SCHEMA}"
  fi

  if [ ! -d "schemas/${K8S_VERSION}/local" ]; then
    mkdir "schemas/${K8S_VERSION}/local"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/local" --expanded --kubernetes "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/local" --kubernetes "${SCHEMA}"
  fi

  if [ ! -d "schemas/${K8S_VERSION}/raw" ]; then
    mkdir "schemas/${K8S_VERSION}/raw"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/raw" --expanded --kubernetes --prefix "${PREFIX}" "${SCHEMA}"
    $OPENAPI2JSONSCHEMABIN -o "schemas/${K8S_VERSION}/raw" --kubernetes --prefix "${PREFIX}" "${SCHEMA}"
  fi
done

git config --global user.email "r.rakeda@gmail.com"
git config --global user.name "Brandon Massie"

find schemas -type d
# Move generated content to root and push as a branch
git checkout --orphan "$K8S_VERSION"
find . -mindepth 1 -maxdepth 1 ! -name 'schemas' ! -name '.git' -exec rm -rf {} +

find schemas -type d

cp -r schemas/${K8S_VERSION}/* .

find schemas -type d

rm -r schemas

find . -type d


git add local raw standalone-strict standalone
git add .
git commit -m "Add schemas for $K8S_VERSION"
git push origin "$K8S_VERSION"

# Clean up the working directory after push
git checkout main
git clean -fdx

