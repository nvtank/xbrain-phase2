# W10 Lab 1 Evidence Report — RBAC and Admission Controller

This report documents the verification and testing process for **W10 Lab 1**, which covers local API services, Kubernetes Role-Based Access Control (RBAC), and OPA Gatekeeper Admission Policies.

---

## 1. Local API Verification

Testing health checking and metric collection of the Flask-based API running locally.

### Healthz Endpoint Verification
```bash
curl -i http://localhost:8080/healthz
```

**Response:**
```http
HTTP/1.1 200 OK
Server: Werkzeug/3.1.8 Python/3.13.14
Date: Thu, 18 Jun 2026 04:43:33 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 2
Connection: close

ok
```

### Root Endpoint Verification
```bash
curl -i http://localhost:8080/
```

**Response:**
```http
HTTP/1.1 200 OK
Server: Werkzeug/3.1.8 Python/3.13.14
Date: Thu, 18 Jun 2026 04:43:33 GMT
Content-Type: application/json
Content-Length: 31
Connection: close

{"ok":true,"version":"v0.0.1"}
```

### Prometheus Metrics Endpoint
```bash
curl -s http://localhost:8080/metrics | head -n 10
```

**Response:**
```prometheus
# HELP python_gc_objects_collected_total Objects collected during gc
# TYPE python_gc_objects_collected_total counter
python_gc_objects_collected_total{generation="0"} 358.0
python_gc_objects_collected_total{generation="1"} 0.0
python_gc_objects_collected_total{generation="2"} 0.0
# HELP python_gc_objects_uncollectable_total Uncollectable objects found during GC
# TYPE python_gc_objects_uncollectable_total counter
python_gc_objects_uncollectable_total{generation="0"} 0.0
python_gc_objects_uncollectable_total{generation="1"} 0.0
python_gc_objects_uncollectable_total{generation="2"} 0.0
```

---

## 2. RBAC Policy Verification

Verification of permissions for different roles (`developer` - alice, `sre` - bob, `viewer` - carol) inside and outside the `demo` namespace.

### Permission Validation Matrix

| Target Action | Executed Command | Allowed? |
| :--- | :--- | :---: |
| **Alice** can create Deployments in namespace `demo`? | `kubectl auth can-i create deploy -n demo --as alice` | **YES** |
| **Alice** can create Deployments in namespace `kube-system`? | `kubectl auth can-i create deploy -n kube-system --as alice` | **NO** |
| **Bob** can get Pods in all namespaces? | `kubectl auth can-i get pods -A --as bob` | **YES** |
| **Carol** can delete Cluster Nodes? | `kubectl auth can-i delete nodes --as carol` | **NO** |

### Execution Logs
```bash
❯ kubectl auth can-i create deploy -n demo --as alice
yes

❯ kubectl auth can-i create deploy -n kube-system --as alice
no

❯ kubectl auth can-i get pods -A --as bob
yes

❯ kubectl auth can-i delete nodes --as carol
Warning: resource 'nodes' is not namespace scoped
no
```

> [!NOTE]
> * **Alice** is successfully restricted within her designated namespace `demo` via a namespace-scoped `RoleBinding`.
> * **Bob** and **Carol** use cluster-wide `ClusterRoleBinding` configurations.

---

## 3. OPA Gatekeeper Admission Policies

Checking the active ConstraintTemplates and Constraints loaded into the Cluster via ArgoCD.

### Active Templates
```bash
❯ kubectl get constrainttemplates
```
```text
NAME                        AGE
k8sdisallowedtags           38m
k8spspallowedusers          38m
k8spsphostnetworkingports   38m
k8srequiredresources        38m
k8srequireownerlabel        38m
```

### Active Constraints
```bash
❯ kubectl get constraints
```
```text
NAME                                                              ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
k8sdisallowedtags.constraints.gatekeeper.sh/disallow-latest-tag   deny                 0

NAME                                                                 ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
k8spspallowedusers.constraints.gatekeeper.sh/require-non-root-user   deny                 0

NAME                                                                        ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
k8spsphostnetworkingports.constraints.gatekeeper.sh/disallow-host-network   deny                 0

NAME                                                                      ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
k8srequiredresources.constraints.gatekeeper.sh/require-container-limits   deny                 0

NAME                                                                               ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
k8srequireownerlabel.constraints.gatekeeper.sh/require-owner-label-on-deployment   deny                 0
```

---

## 4. Policy Rejection Test Cases

Each security constraint was validated against a non-compliant manifest to ensure the request was blocked by Gatekeeper.

### Test Case 4.1: Block `latest` Tag
An attempt to deploy a pod with `nginx:latest` must be rejected.

* **Manifest:**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: bad-latest
    namespace: demo
  spec:
    securityContext:
      runAsNonRoot: true
    containers:
      - name: nginx
        image: nginx:latest
        securityContext:
          runAsUser: 1000
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
  ```
* **Execution:**
  ```bash
  ❯ kubectl apply -f /tmp/bad-latest.yaml
  ```
* **Result:**
  > [!WARNING]
  > `Error from server (Forbidden): error when creating "/tmp/bad-latest.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [disallow-latest-tag] container <nginx> uses a disallowed tag <nginx:latest>; disallowed tags are ["latest"]`

---

### Test Case 4.2: Enforce Resource Limits
An attempt to deploy a pod without container limits must be rejected.

* **Manifest:**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: bad-no-limits
    namespace: demo
  spec:
    securityContext:
      runAsNonRoot: true
    containers:
      - name: nginx
        image: nginx:1.27
        securityContext:
          runAsUser: 1000
  ```
* **Execution:**
  ```bash
  ❯ kubectl apply -f /tmp/bad-no-limits.yaml
  ```
* **Result:**
  > [!WARNING]
  > `Error from server (Forbidden): error when creating "/tmp/bad-no-limits.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [require-container-limits] container <nginx> does not have <{"cpu", "memory"}> limits defined`

---

### Test Case 4.3: Block Root User Execution
An attempt to deploy a container running as root user (`runAsUser: 0`) must be rejected.

* **Manifest:**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: bad-root
    namespace: demo
  spec:
    containers:
      - name: nginx
        image: nginx:1.27
        securityContext:
          runAsUser: 0
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
  ```
* **Execution:**
  ```bash
  ❯ kubectl apply -f /tmp/bad-root.yaml
  ```
* **Result:**
  > [!WARNING]
  > `Error from server (Forbidden): error when creating "/tmp/bad-root.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [require-non-root-user] Container nginx is attempting to run as disallowed user 0. Allowed runAsUser: {"rule": "MustRunAsNonRoot"}`

---

### Test Case 4.4: Block Host Network Access
An attempt to use host hostNetwork (`hostNetwork: true`) must be rejected.

* **Manifest:**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: bad-hostnetwork
    namespace: demo
  spec:
    hostNetwork: true
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
* **Execution:**
  ```bash
  ❯ kubectl apply -f /tmp/bad-hostnetwork.yaml
  ```
* **Result:**
  > [!WARNING]
  > `The pods "bad-hostnetwork" is invalid: : ValidatingAdmissionPolicy 'gatekeeper-k8spsphostnetworkingports' with binding 'gatekeeper-k8spsphostnetworkingports-disallow-host-network' denied request: The specified hostNetwork and hostPort are not allowed, pod: bad-hostnetwork`

---

## 5. Policy Acceptance Test Case

### Test Case 5.1: Deploy Compliant Pod
A Pod that adheres to all security policies should pass admission checks successfully.

* **Manifest:**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: good-pod
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
* **Execution & Verification:**
  ```bash
  ❯ kubectl apply -f /tmp/good-pod.yaml
  pod/good-pod created

  ❯ kubectl get pod good-pod -n demo
  NAME       READY   STATUS              RESTARTS   AGE
  good-pod   0/1     ContainerCreating   0          0s

  ❯ kubectl delete -f /tmp/good-pod.yaml
  pod "good-pod" deleted from demo namespace
  ```
* **Result:**
  > [!TIP]
  > **PASS** - Pod was successfully admitted and initialized.

---

## 6. Custom Rego Rule Verification

Testing the custom ConstraintTemplate (`K8sRequireOwnerLabel`) checking for the presence of the `owner` label on Deployments.

### Test Case 6.1: Reject Deployment without `owner` label

* **Manifest:**
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: deploy-no-owner
    namespace: demo
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: deploy-no-owner
    template:
      metadata:
        labels:
          app: deploy-no-owner
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
* **Execution:**
  ```bash
  ❯ kubectl apply -f /tmp/deploy-no-owner.yaml
  ```
* **Result:**
  > [!WARNING]
  > `Error from server (Forbidden): error when creating "/tmp/deploy-no-owner.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [require-owner-label-on-deployment] Deployment <deploy-no-owner> must have metadata.labels.owner`

---

### Test Case 6.2: Accept Deployment with `owner` label

* **Manifest:**
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: deploy-with-owner
    namespace: demo
    labels:
      owner: team-platform
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: deploy-with-owner
    template:
      metadata:
        labels:
          app: deploy-with-owner
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
* **Execution & Verification:**
  ```bash
  ❯ kubectl apply -f /tmp/deploy-with-owner.yaml
  deployment.apps/deploy-with-owner created

  ❯ kubectl get deploy deploy-with-owner -n demo
  NAME                READY   UP-TO-DATE   AVAILABLE   AGE
  deploy-with-owner   0/1     1            0           0s

  ❯ kubectl delete -f /tmp/deploy-with-owner.yaml
  deployment.apps "deploy-with-owner" deleted from demo namespace
  ```
* **Result:**
  > [!TIP]
  > **PASS** - Deployment containing `owner: team-platform` label was admitted successfully.