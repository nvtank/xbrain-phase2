# W10 24h Challenge Evidence — Onboard `payments` Tenant

## Challenge

Onboard a new team named `payments` into the existing secured platform as a separate tenant.

The goal is to give the new team its own isolated workspace while keeping the previous team safe. The `payments` team should be able to manage its own workload, but must not be able to access or modify resources from the existing `demo` tenant. Existing platform guardrails such as RBAC, quota, LimitRange, NetworkPolicy, Gatekeeper, and Sigstore image verification must continue to apply to the new tenant.

---

## Final Status

| Area                                               | Status |
| :------------------------------------------------- | :----: |
| ArgoCD GitOps applications                         |  PASS  |
| `payments` namespace onboarding                    |  PASS  |
| Namespace labels for tenant and policy enforcement |  PASS  |
| Payments application deployment                    |  PASS  |
| RBAC namespace isolation                           |  PASS  |
| ResourceQuota enforcement                          |  PASS  |
| LimitRange default resource injection              |  PASS  |
| NetworkPolicy manifests installed                  |  PASS  |
| Gatekeeper non-root policy enforcement             |  PASS  |
| Sigstore unsigned image rejection                  |  PASS  |

Final result:

```txt
W10 24h Challenge: PASS
```

---

## EVD-C01 — ArgoCD Applications Are Synced and Healthy

### Command

```bash
kubectl -n argocd get applications payments payments-app api policies \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

### Output

```txt
NAME           SYNC     HEALTH
payments       Synced   Healthy
payments-app   Synced   Healthy
api            Synced   Healthy
policies       Synced   Healthy
```

### Analysis

The `payments` tenant application, `payments-app` workload application, existing `api`, and `policies` applications are all `Synced` and `Healthy`.

This confirms that the new tenant is managed through GitOps and is in the desired state.

**Result:** PASS

---

## EVD-C02 — `payments` Namespace Created With Tenant Labels

### Command

```bash
kubectl get ns payments --show-labels
```

### Output

```txt
NAME       STATUS   AGE   LABELS
payments   Active   20m   kubernetes.io/metadata.name=payments,owner=team-payments,policy.sigstore.dev/include=true,tenant=payments
```

### Analysis

The `payments` namespace exists and has the required labels:

```txt
owner=team-payments
tenant=payments
policy.sigstore.dev/include=true
```

The `policy.sigstore.dev/include=true` label enables Sigstore policy enforcement for this namespace.

**Result:** PASS

---

## EVD-C03 — Payments Tenant Guardrail Objects Exist

### Command

```bash
kubectl get role,rolebinding,resourcequota,limitrange,networkpolicy -n payments
```

### Output

```txt
NAME                                                CREATED AT
role.rbac.authorization.k8s.io/payments-developer   2026-06-18T15:49:50Z

NAME                                                         ROLE                      AGE
rolebinding.rbac.authorization.k8s.io/payments-dev-binding   Role/payments-developer   20m

NAME                           REQUEST                                                                                                         LIMIT                                          AGE
resourcequota/payments-quota   count/deployments.apps: 1/5, pods: 2/10, requests.cpu: 300m/500m, requests.memory: 256Mi/512Mi, services: 1/5   limits.cpu: 300m/1, limits.memory: 256Mi/1Gi   20m

NAME                                 CREATED AT
limitrange/payments-default-limits   2026-06-18T15:49:50Z

NAME                                                                     POD-SELECTOR   AGE
networkpolicy.networking.k8s.io/payments-default-deny-ingress            <none>         20m
networkpolicy.networking.k8s.io/payments-egress-same-namespace-and-dns   <none>         20m
```

### Analysis

The `payments` namespace contains the required multi-tenant guardrail objects:

* `Role`
* `RoleBinding`
* `ResourceQuota`
* `LimitRange`
* `NetworkPolicy`

These objects provide namespace-scoped access control, resource control, and network isolation configuration for the new tenant.

**Result:** PASS

---

## EVD-C04 — Payments Application Is Running

### Command

```bash
kubectl get pods,svc -n payments
```

### Output

```txt
NAME                                READY   STATUS    RESTARTS   AGE
pod/payments-api-69f4445576-d2rvn   1/1     Running   0          20m
pod/payments-probe                  1/1     Running   0          17s

NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/payments-api   ClusterIP   10.96.179.14   <none>        80/TCP    20m
```

### Analysis

The `payments-api` workload is running successfully in the `payments` namespace. The service `payments-api` is also created as a `ClusterIP` service.

The `payments-probe` pod is a temporary test pod used for validation.

**Result:** PASS

---

## EVD-C05 — RBAC Namespace Isolation

### Command

```bash
kubectl auth can-i create deployments -n payments --as payments-dev
kubectl auth can-i create deployments -n demo --as payments-dev
kubectl auth can-i get secrets -n payments --as payments-dev
kubectl auth can-i create rolebindings -n payments --as payments-dev
```

### Output

```txt
yes
no
no
no
```

### Analysis

The `payments-dev` user can create deployments only inside the `payments` namespace.

The user cannot:

* create deployments in the existing `demo` namespace
* read secrets in `payments`
* create RoleBindings in `payments`

This confirms that `payments-dev` has limited namespace-scoped permissions and cannot escalate privileges or access another tenant.

**Result:** PASS

---

## EVD-C06 — ResourceQuota Rejects Over-Quota Pod

### Command

```bash
kubectl apply -f /tmp/payments-over-quota.yaml
```

### Output

```txt
Error from server (Forbidden): error when creating "/tmp/payments-over-quota.yaml": pods "payments-over-quota" is forbidden: exceeded quota: payments-quota, requested: limits.memory=2Gi,requests.memory=2Gi, used: limits.memory=128Mi,requests.memory=128Mi, limited: limits.memory=1Gi,requests.memory=512Mi
```

### Analysis

The test pod requested more memory than allowed by the `payments-quota` ResourceQuota.

The Kubernetes API rejected the pod before it could run.

This proves that the `payments` tenant cannot consume unlimited cluster resources.

**Result:** PASS

---

## EVD-C07 — LimitRange Insets Default Resources

### Command

```bash
kubectl apply -f /tmp/payments-default-limits.yaml

kubectl get pod payments-default-limits -n payments \
  -o jsonpath='{.spec.containers[0].resources}'
echo

kubectl delete -f /tmp/payments-default-limits.yaml
```

### Output

```txt
pod/payments-default-limits created
{"limits":{"cpu":"200m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}
pod "payments-default-limits" deleted from payments namespace
```

### Analysis

The test pod did not manually define resource requests or limits.

The `LimitRange` automatically injected default values:

```txt
limits.cpu=200m
limits.memory=128Mi
requests.cpu=50m
requests.memory=64Mi
```

This prevents containers from running without resource controls.

**Result:** PASS

---

## EVD-C08 — Gatekeeper Rejects Root Container in `payments`

### Command

```bash
kubectl apply -f /tmp/payments-bad-root.yaml
```

### Output

```txt
Error from server (Forbidden): error when creating "/tmp/payments-bad-root.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [require-non-root-user-payments] Container api is attempting to run as disallowed user 0. Allowed runAsUser: {"rule": "MustRunAsNonRoot"}
```

### Analysis

The test pod attempted to run as root user:

```txt
runAsUser: 0
```

Gatekeeper denied the request using the `require-non-root-user-payments` constraint.

This confirms that the non-root security policy applies to the new `payments` tenant.

**Result:** PASS

---

## EVD-C09 — Sigstore Rejects Unsigned Image in `payments`

### Command

```bash
kubectl apply -f /tmp/payments-unsigned-nginx.yaml
```

### Output

```txt
Error from server (BadRequest): error when creating "/tmp/payments-unsigned-nginx.yaml": admission webhook "policy.sigstore.dev" denied the request: validation failed: no matching policies: spec.containers[0].image
index.docker.io/library/nginx:1.27@sha256:6784fb0834aa7dbbe12e3d7471e69c290df3e6ba810dc38b34ae33d3c1c05f7d
```

### Analysis

The test pod used an unsigned public image:

```txt
nginx:1.27
```

The Sigstore Policy Controller rejected it because the image did not match the allowed signed-image policy.

This confirms that the supply-chain admission guardrail also applies to the new `payments` namespace.

**Result:** PASS

---

## EVD-C10 — NetworkPolicy Objects Installed for Tenant Isolation

### Command

```bash
kubectl get networkpolicy -n payments
```

### Output

```txt
NAME                                      POD-SELECTOR   AGE
payments-default-deny-ingress             <none>         20m
payments-egress-same-namespace-and-dns    <none>         20m
```

### Analysis

The `payments` namespace contains two NetworkPolicy objects:

1. `payments-default-deny-ingress`
2. `payments-egress-same-namespace-and-dns`

The intended policy model is:

* deny all ingress into `payments` by default
* allow egress only inside the same namespace
* allow DNS egress to `kube-dns`

This defines the required tenant network isolation model.

Note: runtime NetworkPolicy enforcement depends on the cluster CNI. In this lab environment, no Calico, Cilium, Antrea, or Weave pod was detected, so the YAML configuration is installed correctly, but actual packet-level enforcement depends on the CNI used by the cluster.

**Result:** PASS WITH CLUSTER-CNI NOTE

---

## Why Existing Guardrails Apply to the New Team

The old guardrails apply to the new `payments` team because they are either cluster-scoped or namespace-label-based.

Examples:

* Gatekeeper constraints validate new Kubernetes objects at admission time.
* Sigstore Policy Controller enforces image signature verification for namespaces labeled with `policy.sigstore.dev/include=true`.
* ResourceQuota and LimitRange apply directly inside the `payments` namespace.
* RBAC is scoped with `Role` and `RoleBinding`, so users are limited to the namespace they are assigned to.

Because `payments` is labeled and onboarded through GitOps, the same platform rules are applied automatically without giving the team cluster-admin privileges.

---

## Why Role/RoleBinding Instead of ClusterRoleBinding

The challenge requires the `payments` team to manage only its own resources.

Using `Role` and `RoleBinding` keeps permissions inside the `payments` namespace.

This is safer than `ClusterRoleBinding` because it prevents the new team from accessing:

* the existing `demo` namespace
* secrets outside their namespace
* cluster-wide resources
* RBAC objects that could be used for privilege escalation

This follows the principle of least privilege.

---

## Final Verification Summary

| Evidence ID | Check                                            |       Result       |
| :---------- | :----------------------------------------------- | :----------------: |
| EVD-C01     | ArgoCD apps are synced and healthy               |        PASS        |
| EVD-C02     | `payments` namespace exists with required labels |        PASS        |
| EVD-C03     | RBAC, quota, LimitRange, NetworkPolicy exist     |        PASS        |
| EVD-C04     | `payments-api` workload is running               |        PASS        |
| EVD-C05     | RBAC allows only namespace-scoped actions        |        PASS        |
| EVD-C06     | ResourceQuota rejects over-quota pod             |        PASS        |
| EVD-C07     | LimitRange injects default resources             |        PASS        |
| EVD-C08     | Gatekeeper rejects root container                |        PASS        |
| EVD-C09     | Sigstore rejects unsigned image                  |        PASS        |
| EVD-C10     | NetworkPolicy isolation manifests installed      | PASS WITH CNI NOTE |

---

## Final Result

```txt
W10 24h Challenge — Onboard payments tenant: PASS
```

The new `payments` team has been onboarded as a separate tenant with namespace isolation, least-privilege RBAC, resource guardrails, GitOps management, admission security policies, and supply-chain image verification.
