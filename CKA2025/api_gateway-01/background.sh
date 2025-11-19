#!/bin/bash

# Redirect all output to a log file for debugging
exec > /tmp/background-setup.log 2>&1
set -x

echo "SCRIPT_STARTED" > /tmp/background-status.txt

echo "--- Installing Gateway API CRDs ---"
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
echo "GATEWAY_API_CRDS_APPLIED" >> /tmp/background-status.txt

# Wait for CRDs to be established
kubectl wait --for condition=established --timeout=60s crd/gatewayclasses.gateway.networking.k8s.io || echo "Warning: GatewayClass CRD wait timed out"

echo "--- Installing NGINX Ingress Controller ---"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
echo "INGRESS_NGINX_APPLIED" >> /tmp/background-status.txt

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s || echo "Warning: Ingress controller wait timed out"
echo "INGRESS_NGINX_READY" >> /tmp/background-status.txt

echo "--- Deleting NGINX Ingress Admission Webhook ---"
kubectl delete validatingwebhookconfigurations ingress-nginx-admission || echo "Warning: Could not delete webhook"

echo "--- Installing NGINX Gateway Fabric ---"
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.2/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.2/deploy/default/deploy.yaml
echo "GATEWAY_FABRIC_APPLIED" >> /tmp/background-status.txt

kubectl wait --namespace nginx-gateway \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=nginx-gateway-fabric \
  --timeout=180s || echo "Warning: Gateway Fabric wait timed out"
echo "GATEWAY_FABRIC_READY" >> /tmp/background-status.txt

echo "--- Creating GatewayClass ---"
cat <<EOF > /tmp/nginx-gateway-class.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx-gateway-class
spec:
  controllerName: "nginx.org/gateway-controller"
EOF

kubectl apply -f /tmp/nginx-gateway-class.yaml
echo "GATEWAYCLASS_CREATED" >> /tmp/background-status.txt

kubectl wait --for=condition=Accepted gatewayclass nginx-gateway-class --timeout=120s || echo "Warning: GatewayClass not accepted"

echo "--- Creating Nginx Deployment ---"
cat <<EOF > /tmp/nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.6
        ports:
        - containerPort: 80
EOF

kubectl apply -f /tmp/nginx-deployment.yaml
echo "DEPLOYMENT_CREATED" >> /tmp/background-status.txt

echo "--- Creating Nginx Service ---"
cat <<EOF > /tmp/nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF

kubectl apply -f /tmp/nginx-service.yaml
echo "SERVICE_CREATED" >> /tmp/background-status.txt

echo "--- Creating Ingress ---"
cat <<EOF > /tmp/nginx-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
EOF

kubectl apply -f /tmp/nginx-ingress.yaml
echo "INGRESS_CREATED" >> /tmp/background-status.txt

echo "SETUP_COMPLETE" >> /tmp/background-status.txt
echo "--- Initial setup complete! ---"
echo "Check /tmp/background-setup.log for detailed output"
echo "Check /tmp/background-status.txt for status"