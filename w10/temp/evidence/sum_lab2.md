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
| **API pods actual running image** | 🟢 PASS | All four API pods are running the signed digest image |
| **ArgoCD `api` app** | 🟢 PASS | `api` status is `Synced` and `Healthy` |

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

> [!TIP]
> **Status:** PASS

---

### EVD-17 — Signed API Pods Are Running

* **Command:**
  ```bash
  kubectl get pods -n demo -l app=api \
    -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"  "}{.status.phase}{"\n"}{end}'
  ```
* **Output:**
  ```text
  api-7877bdc754-7d2bl  ghcr.io/nvtank/w10-api@sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc  Running
  api-7877bdc754-sb8rd  ghcr.io/nvtank/w10-api@sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc  Running
  api-7877bdc754-vh85l  ghcr.io/nvtank/w10-api@sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc  Running
  api-7877bdc754-vn67x  ghcr.io/nvtank/w10-api@sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc  Running
  ```
* **Analysis:**
  All four API pods are now running the signed digest image:
  `ghcr.io/nvtank/w10-api@sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc`
  This confirms that the rollout successfully replaced the old unsigned image with the signed image.

> [!TIP]
> **Status:** PASS

---

### EVD-18 — ArgoCD API and Policies Applications Are Healthy

* **Command:**
  ```bash
  kubectl -n argocd get applications api policies \
    -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
  ```
* **Output:**
  ```text
  NAME       SYNC     HEALTH
  api        Synced   Healthy
  policies   Synced   Healthy
  ```
* **Analysis:**
  Both the api and policies ArgoCD applications are fully synced and healthy. This confirms that the GitOps-managed rollout and admission policy are in the desired state.

> [!TIP]
> **Status:** PASS

---

### EVD-19 — Rollout Events Show Successful Signed Image Deployment

* **Command:**
  ```bash
  kubectl get events -n demo --sort-by=.lastTimestamp | tail -40
  ```
* **Important Output:**
  ```text
  Normal    SuccessfulCreate        replicaset/api-7877bdc754      Created pod: api-7877bdc754-sb8rd
  Normal    Pulled                  pod/api-7877bdc754-sb8rd       Container image "ghcr.io/nvtank/w10-api@sha256:d324b1f33999c78a98e545127ec2a8c10c507e69ba9c05defe9bdfd98174babc" already present on machine
  Normal    Started                 pod/api-7877bdc754-sb8rd       Started container api
  Normal    SuccessfulCreate        replicaset/api-7877bdc754      Created pod: api-7877bdc754-vn67x
  Normal    Started                 pod/api-7877bdc754-vn67x       Started container api
  Normal    SuccessfulCreate        replicaset/api-7877bdc754      Created pod: api-7877bdc754-7d2bl
  Normal    Started                 pod/api-7877bdc754-7d2bl       Started container api
  Normal    SuccessfulCreate        replicaset/api-7877bdc754      Created pod: api-7877bdc754-vh85l
  Normal    Started                 pod/api-7877bdc754-vh85l       Started container api
  Normal    MetricSuccessful        analysisrun/api-7877bdc754-3   Metric 'success-rate' Completed. Result: Successful
  Normal    AnalysisRunSuccessful   analysisrun/api-7877bdc754-3   Analysis Completed. Result: Successful
  ```
* **Analysis:**
  The recent events show that the new ReplicaSet api-7877bdc754 successfully created pods using the signed digest image. The Argo Rollouts analysis also completed successfully with AnalysisRunSuccessful.

  Older ReplicaSetCreateError events are historical errors from before the image was re-signed in the compatible legacy Cosign format. The latest events show that the rollout is now successful.

> [!TIP]
> **Status:** PASS

---

## 8. Final Lab 2 Status

| Category | Final Status |
| :--- | :---: |
| **External Secrets Operator** | 🟢 PASS |
| **AWS SecretStore** | 🟢 PASS |
| **ExternalSecret Sync** | 🟢 PASS |
| **Secret Rotation** | 🟢 PASS |
| **Cosign Image Verification** | 🟢 PASS |
| **Sigstore Policy Controller** | 🟢 PASS |
| **ClusterImagePolicy Enforcement** | 🟢 PASS |
| **Unsigned Image Rejection** | 🟢 PASS |
| **Signed API Rollout** | 🟢 PASS |
| **ArgoCD API and Policies Health** | 🟢 PASS |

**Final result:** **W10 Lab 2: PASS**
