#!/bin/bash

# This script sets up the initial environment for the scenario.
# It installs both the NGINX Ingress Controller and NGINX Gateway Fabric,
# and deploys an application with a pre-existing Ingress resource.

echo "--- Installing Gateway API CRDs ---"
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

sleep 10

echo "--- Installing NGINX Ingress Controller ---"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "--- Deleting NGINX Ingress Admission Webhook ---"
kubectl delete validatingwebhookconfigurations ingress-nginx-admission

echo "--- Installing NGINX Gateway Fabric (Gateway API Controller) ---"
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.2/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.2/deploy/default/deploy.yaml

kubectl wait --namespace nginx-gateway \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=nginx-gateway-fabric \
  --timeout=180s

echo "--- Creating GatewayClass for NGINX Gateway Fabric ---"
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx-gateway-class
spec:
  controllerName: "nginx.org/gateway-controller"
EOF

# Wait for the GatewayClass to be accepted by the controller
kubectl wait --for=condition=Accepted gatewayclass nginx-gateway-class --timeout=120s

# Give a moment for all resources to become available
sleep 5

echo "--- Creating the initial Nginx application ---"
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

echo "--- Creating the initial Nginx application (Deployment) ---"
while ! kubectl get deployment nginx-deployment &> /dev/null; do
  kubectl apply -f /tmp/nginx-deployment.yaml
  echo "Waiting for nginx-deployment to be created..."
  sleep 2
done

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

echo "--- Creating the initial Nginx application (Service) ---"
while ! kubectl get service nginx-service &> /dev/null; do
  kubectl apply -f /tmp/nginx-service.yaml
  echo "Waiting for nginx-service to be created..."
  sleep 2
done

echo "--- Creating the existing Ingress resource ---"
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

echo "--- Creating the existing Ingress resource ---"
while ! kubectl get ingress nginx-ingress &> /dev/null; do
  kubectl apply -f /tmp/nginx-ingress.yaml
  echo "Waiting for nginx-ingress to be created..."
  sleep 2
done

echo "--- Initial setup complete! ---"
echo "You now have a running Nginx application exposed via an Ingress resource."
echo "Use 'kubectl get all' and 'kubectl get gatewayclass' to see the resources."