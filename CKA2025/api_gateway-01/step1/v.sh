#!/bin/bash

# 1. Check Gateway exists
if ! kubectl get gateway nginx-gateway -n default &> /dev/null; then
    echo "'nginx-gateway' Gateway resource not found."
    exit 1
fi

# 2. Check gatewayClassName is 'nginx'
GATEWAY_CLASS=$(kubectl get gateway nginx-gateway -o jsonpath='{.spec.gatewayClassName}')
if [ "$GATEWAY_CLASS" != "nginx" ]; then
    echo "'nginx-gateway' does not use 'nginx' as gatewayClassName."
    exit 1
fi

# 3. Check HTTPRoute exists
if ! kubectl get httproute nginx-httproute -n default &> /dev/null; then
    echo "'nginx-httproute' HTTPRoute resource not found."
    exit 1
fi

# 4. Check HTTPRoute references nginx-gateway
PARENT_REF=$(kubectl get httproute nginx-httproute -o jsonpath='{.spec.parentRefs[0].name}')
if [ "$PARENT_REF" != "nginx-gateway" ]; then
    echo "HTTPRoute does not reference 'nginx-gateway'."
    exit 1
fi

# 5. Check HTTPRoute matches path /
PATH_VALUE=$(kubectl get httproute nginx-httproute -o jsonpath='{.spec.rules[0].matches[0].path.value}')
if [ "$PATH_VALUE" != "/" ]; then
    echo "HTTPRoute does not match path '/'."
    exit 1
fi

# 6. Check HTTPRoute routes to nginx-service
BACKEND_NAME=$(kubectl get httproute nginx-httproute -o jsonpath='{.spec.rules[0].backendRefs[0].name}')
if [ "$BACKEND_NAME" != "nginx-service" ]; then
    echo "HTTPRoute does not route to 'nginx-service'."
    exit 1
fi

# 7. Check HTTPRoute routes to port 80
BACKEND_PORT=$(kubectl get httproute nginx-httproute -o jsonpath='{.spec.rules[0].backendRefs[0].port}')
if [ "$BACKEND_PORT" != "80" ]; then
    echo "HTTPRoute does not route to port 80."
    exit 1
fi

# 8. Check that old Ingress is deleted
if kubectl get ingress nginx-ingress &> /dev/null 2>&1; then
    echo "Old 'nginx-ingress' Ingress still exists. Please delete it."
    exit 1
fi

echo "All resources are correctly configured!"
exit 0