#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

APP_NODE_PORT="${app_node_port}"
PAGE_TITLE="${page_title}"

echo "===== Start bootstrap ====="

echo "===== Create swap ====="
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

echo "===== Install packages ====="
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release apt-transport-https conntrack socat

echo "===== Install Docker ====="
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "===== Install kubectl ====="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "===== Install Minikube ====="
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64

echo "===== Start Minikube ====="
su - ubuntu -c "
  set -euxo pipefail
  minikube start --driver=docker --memory=1800 --cpus=2
  kubectl wait --for=condition=Ready nodes --all --timeout=180s
"

echo "===== Create Kubernetes manifest ====="
cat >/home/ubuntu/web-app.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-app-content
data:
  index.html: |
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>$PAGE_TITLE</title>
    </head>
    <body>
      <h1>$PAGE_TITLE</h1>
      <p>This page is served by nginx running inside Kubernetes.</p>
      <p>Traffic: Browser → ALB → EC2:$APP_NODE_PORT → Minikube NodePort → Service → Pod</p>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: nginx-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-web
  template:
    metadata:
      labels:
        app: nginx-web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
      volumes:
        - name: web-content
          configMap:
            name: web-app-content
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
spec:
  type: NodePort
  selector:
    app: nginx-web
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: $APP_NODE_PORT
EOF

chown ubuntu:ubuntu /home/ubuntu/web-app.yaml

echo "===== Apply Kubernetes manifest ====="
su - ubuntu -c "
  set -euxo pipefail
  kubectl apply -f /home/ubuntu/web-app.yaml
  kubectl rollout status deployment/web-app --timeout=180s
  kubectl get pods -o wide
  kubectl get svc -o wide
"

echo "===== Create socat proxy ====="
NODE_IP="$(su - ubuntu -c 'minikube ip')"

cat >/etc/systemd/system/k8s-nodeport-proxy.service <<EOF
[Unit]
Description=Proxy EC2 host port to Minikube NodePort
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:$APP_NODE_PORT,fork,reuseaddr,bind=0.0.0.0 TCP:$NODE_IP:$APP_NODE_PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable k8s-nodeport-proxy.service
systemctl restart k8s-nodeport-proxy.service

echo "===== Verify app ====="
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:$APP_NODE_PORT/" >/dev/null 2>&1; then
    echo "App is reachable on EC2 port $APP_NODE_PORT"
    exit 0
  fi
  sleep 5
done

echo "App did not become reachable" >&2
systemctl status k8s-nodeport-proxy.service || true
su - ubuntu -c "kubectl get pods,svc,endpoints -o wide" || true
exit 1
