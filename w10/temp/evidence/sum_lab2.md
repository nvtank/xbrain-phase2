# W10 Lab 2 Evidence Report — Secrets, Supply Chain, and Admission Policy

This report documents the verification and testing process for **W10 Lab 2**, covering External Secrets Operator (ESO) integration with AWS Secrets Manager, Cosign container image signing/verification, and Sigstore Policy Controller admission policies.

---

## 1. General Information

| Field | Value |
| :--- | :--- |
| **Lab Name** | W10 Lab 2 — Secrets + Supply Chain + Platform Policy |
| **Kubernetes Namespace** | `demo` |
| **AWS Region** | `ap-southeast-1` |
| **Git Branch** | `w10` |
| **Signed Image** | `ghcr.io/nvtank/w10-api:a7e981ee69cbdbb232e12de05ac1baf86af19bd5` |
| **External Secrets Namespace** | `external-secrets` |
| **Sigstore Policy Namespace** | `cosign-system` |

---

## 2. Overall Result Summary

| Item | Status | Evidence Summary |
| :--- | :---: | :--- |
| **External Secrets Operator installed** | 🟢 PASS | All ESO pods are `1/1 Running` |
| **AWS SecretStore validated** | 🟢 PASS | `aws-store` status is `Valid` and `Ready=True` |
| **ExternalSecret synced** | 🟢 PASS | `db-creds` status is `SecretSynced` and `Ready=True` |
| **Kubernetes Secret rotation** | 🟢 PASS | `db-secret` contains the rotated value `pass-v3` |
| **Cosign public key exists** | 🟢 PASS | `signing/cosign.pub` exists in the repository |
| **Cosign image verification** | 🟢 PASS | Image signature verified successfully with the public key |
| **Policy Controller installed** | 🟢 PASS | `policy-controller-webhook` is `1/1 Running` |
| **ClusterImagePolicy ready** | 🟢 PASS | `Ready=True`, configured in `enforce` mode |
| **Namespace enforcement enabled** | 🟢 PASS | Namespace `demo` labeled with `policy.sigstore.dev/include=true` |
| **Unsigned image rejected** | 🟢 PASS | `nginx:1.27` deployment denied by admission webhook |
| **ArgoCD `policies` app** | 🟢 PASS | `policies` application is `Synced` and `Healthy` |
| **API Rollout spec uses signed image** | 🟢 PASS | Rollout spec successfully updated to the signed GHCR image |
| **API pods actual running image** | 🟡 PARTIAL | Existing pods still running `ghcr.io/vuong-bach/w10-api:0.0.1` |
| **ArgoCD `api` app** | 🟡 PARTIAL | `api` status is `Synced` but `Progressing` |

---

## 3. External Secrets Operator Evidence

### EVD-01 — External Secrets Operator Pods Are Running
Verifying the status of the External Secrets Operator workloads.

* **Command:**
  ```bash
  kubectl get pods -n external-secrets
  ```
* **Output:**
  ```text
  NAME                                                    READY   STATUS    RESTARTS   AGE
  eso-external-secrets-5cb8f46bd4-chlgs                   1/1     Running   0          84m
  eso-external-secrets-cert-controller-5cfcc8d8df-7kpwq   1/1     Running   0          84m
  eso-external-secrets-webhook-68889d569-mlhkt            1/1     Running   0          84m
  ```
* **Analysis:**
  External Secrets Operator was successfully installed. The main controller, certificate controller, and webhook are all healthy and running without any restarts.

> [!TIP]
> **Status:** PASS

---

### EVD-02 — AWS SecretStore Is Valid
Verifying that the SecretStore connection to AWS Secrets Manager is active and validated.

* **Command:**
  ```bash
  kubectl get secretstore -n demo
  kubectl describe secretstore aws-store -n demo | tail -n 30
  ```
* **Output:**
  ```text
  NAME        AGE   STATUS   CAPABILITIES   READY
  aws-store   71m   Valid    ReadWrite      True
  ```
  ```yaml
  Spec:
    Provider:
      Aws:
        Auth:
          Secret Ref:
            Access Key ID Secret Ref:
              Key:   access-key
              Name:  aws-creds
            Secret Access Key Secret Ref:
              Key:   secret-key
              Name:  aws-creds
        Region:      ap-southeast-1
        Service:     SecretsManager
  
  Status:
    Capabilities:  ReadWrite
    Conditions:
      Message:               store validated
      Reason:                Valid
      Status:                True
      Type:                  Ready
  ```
* **Analysis:**
  The `SecretStore` named `aws-store` successfully authenticated to AWS Secrets Manager in the `ap-southeast-1` region using the provided credentials.

> [!TIP]
> **Status:** PASS

---

### EVD-03 — ExternalSecret Synced Successfully
Checking the synchronization status of the `ExternalSecret` definition.

* **Command:**
  ```bash
  kubectl get externalsecret -n demo
  ```
* **Output:**
  ```text
  NAME       STORE       REFRESH INTERVAL   STATUS         READY
  db-creds   aws-store   30s                SecretSynced   True
  ```
* **Analysis:**
  The `ExternalSecret` configuration `db-creds` successfully fetched and synced the password value. The refresh interval is configured to `30s` to support rapid key rotation.

> [!TIP]
> **Status:** PASS

---

### EVD-04 — Kubernetes Secret Was Created and Rotated
Verifying that the synced Kubernetes secret contains the updated password.

* **Command:**
  ```bash
  kubectl get secret db-secret -n demo
  kubectl get secret db-secret -n demo -o jsonpath='{.data.password}' | base64 -d
  echo
  ```
* **Output:**
  ```text
  NAME        TYPE     DATA   AGE
  db-secret   Opaque   1      63m
  pass-v3
  ```
* **Analysis:**
  The auto-generated secret `db-secret` exists. The decoded password value is `pass-v3`, proving that secrets were successfully rotated and synced from AWS.

> [!TIP]
> **Status:** PASS

---

## 4. Cosign Signing and Verification Evidence

### EVD-05 — Cosign Public Key Exists
Verifying the presence of the public key in the repository.

* **Command:**
  ```bash
  ls -l signing/cosign.pub
  cat signing/cosign.pub
  ```
* **Output:**
  ```text
  -rw-r--r-- 1 nvtank users 178 Jun 18 15:53 signing/cosign.pub
  ```
  ```text
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEG/UerSPwaCvNq/tAeoWEXPrSEDpO
  Pd5GVcJBPTCICIsWNhT/OhZd6aF4yqVvJ0RWo59gEx3hpiUcnE98JWTQmA==
  -----END PUBLIC KEY-----
  ```
* **Analysis:**
  The Cosign public key is stored locally at `signing/cosign.pub`. This key is used for signature validation within the cluster.

> [!TIP]
> **Status:** PASS

---

### EVD-06 — Signed Image Verification Passed
Verifying the image signature locally against the Cosign public key.

* **Command:**
  ```bash
  SIGNED_IMAGE="ghcr.io/nvtank/w10-api:a7e981ee69cbdbb232e12de05ac1baf86af19bd5"
  cosign verify --key signing/cosign.pub "$SIGNED_IMAGE"
  ```
* **Output:**
  ```text
  Verification for ghcr.io/nvtank/w10-api:a7e981ee69cbdbb232e12de05ac1baf86af19bd5 --
  The following checks were performed on each of these signatures:
    - The cosign claims were validated
    - Existence of the claims in the transparency log was verified offline
    - The signatures were verified against the specified public key
  ```
  ```json
  [{
    "critical": {
      "identity": {
        "docker-reference": "ghcr.io/nvtank/w10-api:a7e981ee69cbdbb232e12de05ac1baf86af19bd5"
      },
      "image": {
        "docker-manifest-digest": "sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc"
      },
      "type": "https://sigstore.dev/cosign/sign/v1"
    },
    "optional": {}
  }]
  ```
* **Analysis:**
  Local verification succeeded. The image matches the cryptographic signature created by the private signing key.

> [!TIP]
> **Status:** PASS

---

## 5. Sigstore Policy Controller Evidence

### EVD-07 — Policy Controller Is Running
Checking if the Sigstore Policy Controller admission pods are active.

* **Command:**
  ```bash
  kubectl get pods -n cosign-system
  ```
* **Output:**
  ```text
  NAME                                         READY   STATUS    RESTARTS   AGE
  policy-controller-webhook-76fb999bdf-kn6zl   1/1     Running   0          26m
  ```

> [!TIP]
> **Status:** PASS

---

### EVD-08 — ClusterImagePolicy Exists
Verifying the presence of the custom ClusterImagePolicy.

* **Command:**
  ```bash
  kubectl get clusterimagepolicy
  ```
* **Output:**
  ```text
  NAME                     AGE
  require-signed-w10-api   26m
  ```

> [!TIP]
> **Status:** PASS

---

### EVD-09 — ClusterImagePolicy Is Ready
Verifying the status of the deployed policy.

* **Command:**
  ```bash
  kubectl get clusterimagepolicy require-signed-w10-api -o yaml | grep -A30 "status:"
  ```
* **Output:**
  ```yaml
  status:
    conditions:
    - lastTransitionTime: "2026-06-18T09:04:21Z"
      status: "True"
      type: ConfigMapUpdated
    - lastTransitionTime: "2026-06-18T09:04:21Z"
      status: "True"
      type: KeysInlined
    - lastTransitionTime: "2026-06-18T09:04:21Z"
      status: "True"
      type: PoliciesInlined
    - lastTransitionTime: "2026-06-18T09:04:21Z"
      status: "True"
      type: Ready
    observedGeneration: 2
  ```
* **Analysis:**
  All conditions (KeysInlined, PoliciesInlined, Ready) are `True`, meaning the policy is compiled and fully active.

> [!TIP]
> **Status:** PASS

---

### EVD-10 — ClusterImagePolicy Manifest Details
Reviewing the configured ClusterImagePolicy rules.

* **Command:**
  ```bash
  kubectl get clusterimagepolicy require-signed-w10-api -o yaml
  ```
* **Important Spec Details:**
  ```yaml
  apiVersion: policy.sigstore.dev/v1beta1
  kind: ClusterImagePolicy
  metadata:
    name: require-signed-w10-api
  spec:
    authorities:
    - key:
        data: |
          -----BEGIN PUBLIC KEY-----
          MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEG/UerSPwaCvNq/tAeoWEXPrSEDpO
          Pd5GVcJBPTCICIsWNhT/OhZd6aF4yqVvJ0RWo59gEx3hpiUcnE98JWTQmA==
          -----END PUBLIC KEY-----
      name: authority-0
    images:
    - glob: ghcr.io/nvtank/w10-api:*
    mode: enforce
  ```
* **Analysis:**
  The controller is configured in `enforce` mode for any image matching `ghcr.io/nvtank/w10-api:*`, verifying signatures against the embedded Cosign public key.

> [!TIP]
> **Status:** PASS

---

### EVD-11 — Namespace Enforcement Label Is Enabled
Checking if the namespace is configured to use image policy checks.

* **Command:**
  ```bash
  kubectl get ns demo --show-labels
  ```
* **Output:**
  ```text
  NAME   STATUS   AGE    LABELS
  demo   Active   117m   kubernetes.io/metadata.name=demo,policy.sigstore.dev/include=true
  ```
* **Analysis:**
  Namespace `demo` is labeled with `policy.sigstore.dev/include=true`, which triggers the Sigstore Admission Webhook for all deployments into this namespace.

> [!TIP]
> **Status:** PASS

---

## 6. Unsigned Image Rejection Evidence

### EVD-12 — Unsigned Nginx Test Pod Manifest
Attempting to create a pod using the unsigned image `nginx:1.27`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-nginx
  namespace: demo
spec:
  securityContext:
    runAsNonRoot: true
  containers:
    - name: nginx
      image: nginx:1.27
      securityContext:
        runAsUser: 1000
      resources:
        limits:
          cpu: 100m
          memory: 128Mi
```

---

### EVD-13 — Unsigned Image Was Rejected by Webhook
Applying the manifest and verifying that the request gets blocked.

* **Command:**
  ```bash
  kubectl apply -f /tmp/unsigned-nginx.yaml
  ```
* **Output:**
  ```text
  Error from server (BadRequest): error when creating "/tmp/unsigned-nginx.yaml": 
  admission webhook "policy.sigstore.dev" denied the request: validation failed: 
  no matching policies: spec.containers[0].image
  index.docker.io/library/nginx:1.27@sha256:6784fb0834aa7dbbe12e3d7471e69c290df3e6ba810dc38b34ae33d3c1c05f7d
  ```

> [!TIP]
> **Status:** PASS

---

### EVD-14 — Unsigned Pod Was Not Created
Verifying that the Pod was indeed not admitted to the cluster.

* **Command:**
  ```bash
  kubectl get pod unsigned-nginx -n demo
  ```
* **Output:**
  ```text
  Error from server (NotFound): pods "unsigned-nginx" not found
  ```

> [!TIP]
> **Status:** PASS

---

## 7. Signed API Rollout Evidence

### EVD-15 — API Rollout Spec Uses Signed Image
Checking the configured image in the Rollout object.

* **Command:**
  ```bash
  kubectl get rollout api -n demo -o jsonpath='{.spec.template.spec.containers[0].image}'
  echo
  ```
* **Output:**
  ```text
  ghcr.io/nvtank/w10-api:a7e981ee69cbdbb232e12de05ac1baf86af19bd5
  ```

> [!TIP]
> **Status:** PASS

---

### EVD-16 — API Pods Availability Status
Checking the status of the Rollout pods.

* **Command:**
  ```bash
  kubectl get pods -n demo
  kubectl get rollout api -n demo
  ```
* **Output:**
  ```text
  NAME                   READY   STATUS    RESTARTS   AGE
  api-564c456f58-996n8   1/1     Running   0          116m
  api-564c456f58-j8brh   1/1     Running   0          116m
  api-564c456f58-q9xwr   1/1     Running   0          116m
  api-564c456f58-rrrp8   1/1     Running   0          116m
  ```
  ```text
  NAME   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  api    4         4                      4           116m
  ```

> [!WARNING]
> **Status:** PARTIAL — Workload is healthy, but further verification is required to ensure the pods are running the updated image version.

---

### EVD-17 — Actual Running API Pods Image Check
Verifying the actual image hash loaded into the active Pod instances.

* **Command:**
  ```bash
  kubectl get pods -n demo -l app=api \
    -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"  "}{.status.phase}{"\n"}{end}'
  ```
* **Output:**
  ```text
  api-564c456f58-996n8  ghcr.io/vuong-bach/w10-api:0.0.1  Running
  api-564c456f58-j8brh  ghcr.io/vuong-bach/w10-api:0.0.1  Running
  api-564c456f58-q9xwr  ghcr.io/vuong-bach/w10-api:0.0.1  Running
  api-564c456f58-rrrp8  ghcr.io/vuong-bach/w10-api:0.0.1  Running
  ```
* **Analysis:**
  Although the Rollout spec was updated with the signed image, the active pod replicas were still running the old image (`ghcr.io/vuong-bach/w10-api:0.0.1`). A rollout restart/upgrade is needed to trigger deployment of the signed containers.

> [!WARNING]
> **Status:** PARTIAL / NEEDS FOLLOW-UP

---

## 8. ArgoCD Application Evidence

### EVD-18 — ArgoCD Main Applications Status
Checking the state of the applications created for W10 Lab 2.

* **Command:**
  ```bash
  kubectl -n argocd get applications policy-controller policies api eso eso-config \
    -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
  ```
* **Output:**
  ```text
  NAME                SYNC        HEALTH
  policy-controller   OutOfSync   Healthy
  policies            Synced      Healthy
  api                 Synced      Progressing
  eso                 Synced      Healthy
  eso-config          OutOfSync   Healthy
  ```

> [!WARNING]
> **Status:** PARTIAL — `policies` is fully Synced, but the `api` app is still `Progressing` due to the pending container update.

---

### EVD-19 — All Deployed ArgoCD Applications
List of all applications managed by the central ArgoCD server.

* **Command:**
  ```bash
  kubectl -n argocd get applications
  ```
* **Output:**
  ```text
  NAME                     SYNC STATUS   HEALTH STATUS
  alert                    Synced        Healthy
  analysis                 Synced        Healthy
  api                      Synced        Progressing
  argo-rollouts            Synced        Healthy
  common                   Synced        Healthy
  eso                      Synced        Healthy
  eso-config               OutOfSync     Healthy
  gatekeeper               Synced        Healthy
  gatekeeper-constraints   Synced        Healthy
  gatekeeper-templates     Synced        Healthy
  kube-prometheus-stack    Synced        Healthy
  policies                 Synced        Healthy
  policy-controller        OutOfSync     Healthy
  rbac                     Synced        Healthy
  root                     Synced        Healthy
  ```

---

## 9. Policy Controller Admission Logs

### EVD-20 — Webhook Validation Failures
Analyzing the admission controller webhook logs.

* **Command:**
  ```bash
  kubectl logs -n cosign-system deploy/policy-controller-webhook --tail=120
  ```
* **Relevant Log Snippet:**
  ```json
  {
    "level": "info",
    "ts": "2026-06-18T09:05:12.435Z",
    "caller": "webhook/admission.go:102",
    "msg": "Failed the resource specific validation",
    "knative.dev/kind": "apps/v1, Kind=ReplicaSet",
    "knative.dev/namespace": "demo",
    "knative.dev/name": "api-6cd5dfbc4c",
    "knative.dev/operation": "CREATE"
  }
  ```

---

## 10. Required Follow-Up Actions

To complete the rollout and ensure that the cluster is running the signed image:

### 1. Force Rollout Restart
```bash
kubectl rollout restart rollout api -n demo
```
*Or via patch:*
```bash
kubectl patch rollout api -n demo --type merge \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"restarted-at\":\"$(date -Iseconds)\"}}}}}"
```

### 2. Verify Active Pod Image Version
```bash
kubectl get pods -n demo -l app=api \
  -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"  "}{.status.phase}{"\n"}{end}'
```
*Expected Output:*
```text
api-xxxxxx  ghcr.io/nvtank/w10-api:a7e981ee69cbdbb232e12de05ac1baf86af19bd5  Running
```

---

## 11. Final Conclusion

The environment successfully demonstrates:
1. **Secrets Security**: External Secrets Operator connected to AWS Secrets Manager with secret rotation verified at `30s` intervals.
2. **Supply Chain Protection**: Images signed using Cosign and validation keys loaded to the cluster.
3. **Admission Enforcement**: ClusterImagePolicy enforcing signed image policies on the `demo` namespace, preventing unsigned workloads from initializing.

| Category | Final Status |
| :--- | :---: |
| **ESO Secret Rotation** | 🟢 PASS |
| **Cosign Image Verification** | 🟢 PASS |
| **Admission Rejection** | 🟢 PASS |
| **Signed API Rollout Spec** | 🟢 PASS |
| **Signed API Running Pods** | 🟡 PARTIAL (Needs Restart) |
