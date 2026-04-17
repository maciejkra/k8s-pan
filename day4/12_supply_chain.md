# 12 — Supply chain security (teoria + cross-link do D1)

> Krótki rozdział łączący D1 (Cosign + SBOM + Trivy CLI) z D4 (admission, policy).

## Co to jest "supply chain" w kontekście K8s?

Łańcuch od **kodu źródłowego** do **uruchomionego Poda**:
```
git push → CI build → image registry → kubectl apply → klaster runtime
```

Atak może wystąpić na każdym etapie:
| Etap | Atak | Mitigation |
|---|---|---|
| Source | malicious commit | branch protection, signed commits |
| Build | compromised CI runner | ephemeral runners, hermetic builds |
| Image | typosquatting (`debain:latest`) | image allowlist, OPA policy |
| Registry | image substitution (man-in-the-middle) | **Cosign signature** (D1/05) |
| Deploy | manifest tampering | GitOps + signed manifests |
| Runtime | malicious update of running image | Falco (D4/08), immutable tags |

## SLSA — supply chain Levels

[SLSA](https://slsa.dev/) (Supply chain Levels for Software Artifacts) — framework Google wprowadzający 4 poziomy dojrzałości:

| Level | Wymaganie |
|---|---|
| **L1** | Build process documented (np. Dockerfile in repo) |
| **L2** | Hosted, version-controlled build service (GitHub Actions, GitLab CI) |
| **L3** | Hardened build platform (signed provenance, isolated builds) |
| **L4** | Two-party review + hermetic, reproducible builds |

Większość zespołów osiąga L1-L2 łatwo, L3 wymaga inwestycji w narzędzia (Sigstore, Tekton Chains, GitHub Actions OIDC).

## Pełny flow supply chain w K8s

```
1. Developer push → branch protected, signed commits
2. CI (GitHub Actions / Tekton):
   a. lint (hadolint — D1/06)
   b. build → image
   c. trivy image (D1/04) — fail on HIGH/CRITICAL
   d. cosign sign (D1/05) — keyless OIDC
   e. cosign attest --predicate sbom.json (D1/05)
   f. push do registry
3. Admission controller w klastrze (D4/09):
   a. Sigstore Policy Controller weryfikuje cosign signature
   b. OPA/Gatekeeper sprawdza allowlist registries
   c. PSA (D4/02) wymusza non-root etc.
4. Runtime:
   a. Trivy Operator (D4/07) re-skanuje co 6h
   b. Falco (D4/08) detekcja anomalii
   c. Audit log → SIEM
```

## Sigstore Policy Controller (admission verifying signatures)

```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-cosign-signature
spec:
  images:
    - glob: "ghcr.io/myorg/**"
  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subject: "https://github.com/myorg/myrepo/.github/workflows/release.yml@refs/heads/main"
```

Każdy Pod używający `ghcr.io/myorg/...` jest weryfikowany — czy obraz został podpisany przez **konkretny workflow** w **konkretnym repo** w **konkretnym branchu**. Substitution attack = admission denied.

## Praktyka: minimal viable supply chain

Dla zespołu chcącego zacząć:

**Tier 1** (1 dzień pracy):
1. Hadolint w pre-commit (`pre-commit install`)
2. Trivy w CI (action `aquasecurity/trivy-action`) z `severity: HIGH,CRITICAL` i `exit-code: 1`
3. Pinowane base images (`nginx:1.27.0-alpine`, nie `nginx:latest`)
4. OPA/Gatekeeper policy: `K8sAllowedRepos` z listą zaufanych registries

**Tier 2** (1 tydzień):
5. Cosign keyless w CI (GitHub Actions OIDC)
6. SBOM jako artifact PR + CycloneDX attestation
7. Sigstore Policy Controller w klastrze
8. Trivy Operator dla runtime monitoring

**Tier 3** (project):
9. SLSA L3 — provenance generation
10. Renovate/Dependabot dla auto-bump CVE patches
11. Signed K8s manifests (kubectl-cosign sign-blob)
12. Multi-cluster security policy distribution (ArgoCD ApplicationSet)

## Linki

- [SLSA framework](https://slsa.dev/)
- [Sigstore](https://www.sigstore.dev/)
- [Sigstore Policy Controller](https://docs.sigstore.dev/policy-controller/overview/)
- [GitHub Actions: provenance](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Tekton Chains](https://tekton.dev/docs/chains/) — alternatywa dla GitHub Actions OIDC
