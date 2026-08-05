# The Platform Engineer's Handbook - Platform Services

This repo is the GitOps source that Flux reconciles onto the cluster: platform-wide services (e. g cert-manager, Istio, OPA/Gatekeeper, team namespaces) defined as [Flux Operator](https://fluxcd-operator.dev/) `ResourceSet`s, laid out as a Kustomize base plus one overlay per environment. 


## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [flux2 cli](https://fluxcd.io/flux/installation/)
- [conftest](https://www.conftest.dev/)
- [flate](https://github.com/home-operations/flate)
- [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age)
- [mise](https://mise.jdx.dev/)

## Layout

```text
environments/
├── base/
│   ├── cert-manager/
│   │   ├── app/
│   │   └── ca/
│   ├── istio/
│   │   ├── app/
│   │   └── ...
│   └── ...
├── platform-sandbox/
│   ├── cert-manager/
│   ├── istio/
│   ├── ...
│   └── kustomization.yaml
└── app-dev/
    ├── istio/
    ├── ...
    └── kustomization.yaml
```

Each environment is a standard Kustomize overlay on top of the relevant `base/` components, with a `labels:` block (`env: <name>`) applied to everything it builds.

## Conventions

- **One `ResourceSet` per concern, one folder per `ResourceSet`.** A base component with multiple independently-reconciled pieces (e.g istio , gateway , mtls ) gets one subfolder per piece.

- **Ordering is expressed via `spec.dependsOn`, not folder nesting.** E.g. `istio-gateway` and `istio-mtls` both `dependsOn: istio`.

- **Per-environment overrides use two different mechanisms depending on the base resource:** components exposing a `ResourceSetInputProvider` (label `app: <component>`) get a per-env `<component>/inputprovider.yaml`, `team-namespaces` instead gets a Kustomize patch (`<component>/patch.yaml`) against the base `ResourceSet`.

## Environments

- **`platform-sandbox`** — the continuous environment; reconciled on every push to `main`.
- **`app-dev`** — the production-equivalent environment, carrying the same components as `platform-sandbox`. Intended to reconcile on merge to a `production` branch rather than on every push to `main`

## Validating changes locally

```bash
# Lint every manifest under environments/ against the Rego policies in policy/
conftest test environments/ -p policy/

# Confirm every Kustomization/ResourceSet in environments/ actually builds
flate test all --path ./environments
```

Both run in CI on every PR (`.github/workflows/validate.yml`).

## Secrets

Secret values are encrypted with [SOPS](https://github.com/getsops/sops) using age (`.sops.yaml`). A component's secret manifest goes in `environments/<env>/<component>/secret.yaml`, alongside its `inputprovider.yaml`/`patch.yaml`; `.sops.yaml` matches any file named `secret.yaml` and encrypts only its `data`/`stringData` values, so the rest of the manifest stays readable in diffs.

Flux's `Kustomization` for each environment (in `platform-gitops`) has `spec.decryption` pointed at a `flux-system/sops-age` Secret, created by `platform-core`'s Pulumi stack (`pulumi/modules/flux.py`) from an age private key stored in Bitwarden.

## Adding a new component

1. Under `environments/base/<component>/`, create one subfolder per independently-reconciled concern (or leave it flat if there's only one), each with a `ResourceSet`.
2. If a concern must reconcile after another, set `spec.dependsOn` on its `ResourceSet` to point at the one it depends on.
3. Wire `environments/base/<component>` into every environment overlay that should run it.
4. If the component needs per-environment values, add a `ResourceSetInputProvider` under `environments/<env>/<component>/`.
