#!/usr/bin/env bash
# resign-with-new-key.sh
# Hướng A: Tạo key mới, cập nhật policy, sign image, commit
set -euo pipefail

REGISTRY="ghcr.io"
IMAGE_NAME="nvtank/w10-api"
IMAGE_TAG="a7e981ee69cbdbb232e12de05ac1baf86af19bd5"
IMAGE_REF="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
KEY_DIR="${REPO_ROOT}/signing"

cd "${REPO_ROOT}"

echo "======================================================"
echo "  Bước 1: Tạo cosign key pair mới"
echo "======================================================"
mkdir -p "${KEY_DIR}"
# Tạo key tại thư mục signing/, nếu có rồi thì hỏi overwrite
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix "${KEY_DIR}/cosign"

echo ""
echo "✅ Đã tạo:"
echo "   - ${KEY_DIR}/cosign.key"
echo "   - ${KEY_DIR}/cosign.pub"

echo ""
echo "======================================================"
echo "  Bước 2: Cập nhật cluster-image-policy.yaml trong repo"
echo "======================================================"
# Ghi lại file yaml với public key mới
cat > "${REPO_ROOT}/policies/cluster-image-policy.yaml" <<EOF
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-signed-w10-api
spec:
  mode: enforce
  images:
    - glob: "ghcr.io/nvtank/w10-api:*"
  authorities:
    - name: authority-0
      key:
        data: |
$(sed 's/^/          /' "${KEY_DIR}/cosign.pub")
EOF

echo "✅ policies/cluster-image-policy.yaml đã được cập nhật"

echo ""
echo "======================================================"
echo "  Bước 3: Apply ClusterImagePolicy lên cluster"
echo "======================================================"
kubectl apply -f "${REPO_ROOT}/policies/cluster-image-policy.yaml"
echo "✅ ClusterImagePolicy applied thành công"

echo ""
echo "======================================================"
echo "  Bước 4: Stage files"
echo "======================================================"
git add "${KEY_DIR}/cosign.pub"
git add "${REPO_ROOT}/policies/cluster-image-policy.yaml"
echo "✅ Đã stage files"

echo ""
echo "======================================================"
echo "  Bước 5: Sign image bằng key mới"
echo "======================================================"
echo "🔐 Signing: ${IMAGE_REF}"
COSIGN_PASSWORD="" cosign sign --yes --key "${KEY_DIR}/cosign.key" "${IMAGE_REF}"
echo "✅ Image đã được sign"

echo ""
echo "======================================================"
echo "  Bước 6: Verify signature"
echo "======================================================"
cosign verify \
  --key "${KEY_DIR}/cosign.pub" \
  "${IMAGE_REF}" \
  | jq '.[0].optional // .[0]' 2>/dev/null || \
cosign verify \
  --key "${KEY_DIR}/cosign.pub" \
  "${IMAGE_REF}"
echo "✅ Signature verified thành công"

echo ""
echo "======================================================"
echo "  Bước 7: Commit thay đổi"
echo "======================================================"
git commit -m "fix: rotate cosign key and update cluster image policy"
echo "✅ Đã commit"

echo ""
echo "======================================================"
echo "  Bước 8: Trigger rollout"
echo "======================================================"
kubectl patch rollout api -n demo --type merge \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"resigned\":\"$(date +%s)\"}}}}}"
echo "✅ Rollout triggered"

echo ""
echo "======================================================"
echo "  ⚠️  VIỆC CÒN LẠI (thủ công):"
echo "======================================================"
echo ""
echo "  1. Push code:"
echo "     git push --set-upstream origin w10"
echo ""
echo "  2. Thêm COSIGN_PRIVATE_KEY vào GitHub Secrets:"
echo "     → Vào: https://github.com/nvtank/xbrain-phase2/settings/secrets/actions"
echo "     → New secret: COSIGN_PRIVATE_KEY"
echo "     → Value: nội dung file signing/cosign.key (copy toàn bộ)"
echo ""
echo "  3. Thêm COSIGN_PASSWORD vào GitHub Secrets:"
echo "     → New secret: COSIGN_PASSWORD"
echo "     → Value: passphrase (để trống)"
echo ""
echo "  4. Kiểm tra pods:"
echo "     kubectl get pods -n demo -l app=api \\"
echo "       -o jsonpath='{range .items[*]}{.metadata.name}{\"  \"}{.spec.containers[0].image}{\"  \"}{.status.phase}{\"\n\"}{end}'"
echo ""

# Kiểm tra .gitignore
GITIGNORE="${REPO_ROOT}/.gitignore"
if grep -q "cosign.key" "${GITIGNORE}" 2>/dev/null; then
  echo "  ✅ cosign.key đã có trong .gitignore"
else
  echo "  ⚠️  Thêm cosign.key vào .gitignore..."
  echo "signing/cosign.key" >> "${GITIGNORE}"
  git add .gitignore
  echo "  ✅ Đã thêm signing/cosign.key vào .gitignore"
fi

echo ""
echo "======================================================"
echo "  🎉 HOÀN THÀNH!"
echo "======================================================"
