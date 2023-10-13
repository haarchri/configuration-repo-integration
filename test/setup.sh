#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"
echo "Waiting until configuration package is healthy/installed..."
${KUBECTL} wait configuration.pkg configuration-repo-integration --for=condition=Healthy --timeout 5m
${KUBECTL} wait configuration.pkg configuration-repo-integration --for=condition=Installed --timeout 5m

echo "Creating upbound cloud credential secret..."
${KUBECTL} -n upbound-system create secret generic up-creds --from-literal=credentials="${UPTEST_UPBOUND_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "Creating github cloud credential secret..."
${KUBECTL} -n upbound-system create secret generic github-creds --from-literal=credentials="${UPTEST_GITHUB_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "Waiting until all installed provider packages are healthy..."
${KUBECTL} wait provider.pkg --all --for condition=Healthy --timeout 5m

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
kubectl wait xrd --all --for condition=Established

echo "Creating a default upbound provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: upbound.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: creds
      name: up-creds
      namespace: upbound-system
    source: Secret
EOF

echo "Creating a default upbound provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: github.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: creds
      name: github-creds
      namespace: upbound-system
    source: Secret
EOF
