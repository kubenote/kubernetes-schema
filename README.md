# kubernetes-schema

> A structured and versioned archive of Kubernetes JSON schemas, organized for easier consumption and tooling integration.

## Background

This project is a continuation and restructuring of previous efforts to generate and maintain Kubernetes JSON schemas for validating YAML manifests.

It is **forked and inspired by:**

- [instrumenta/kubernetes-json-schema](https://github.com/instrumenta/kubernetes-json-schema)  
  The original project that queried Kubernetes OpenAPI specs and converted them into JSON schemas for use in tools like `kubeval` and `kubeconform`.

- [yannh/kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema)  
  A maintained fork that improved schema structure, added strict variants, and ensured compatibility with Kubernetes' OpenAPI spec.

## Purpose of This Fork

This iteration focuses on simplifying access and versioning of schemas:

- **Each Kubernetes version is published on its own Git branch**, allowing you to fetch only what you need.
- The structure helps tooling and CI/CD pipelines efficiently download and reference only relevant schema versions.

## Structure

Each branch (`v1.XX.X`) contains the following folders:

- `local/` – Fully dereferenced schemas without external `$ref` URLs.
- `raw/` – Schemas referencing external definitions via `$ref`.
- `standalone/` – Partially dereferenced schemas with internal structure.
- `standalone-strict/` – Same as `standalone`, but with `additionalProperties: false` for stricter validation.

## Usage

To download schemas for a specific Kubernetes version:

```bash
git clone --branch v1.33.3 https://github.com/kubenote/kubernetes-schema.git
