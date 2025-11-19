#!/bin/bash

if ! kubectl get gateway nginx-gateway &> /dev/null; then
    echo "'nginx-gateway' Gateway resource not found."
    exit 1
fi

if ! kubectl get gateway nginx-gateway -o json | grep '"gatewayClassName": "nginx"' &> /dev/null; then
    echo "'nginx-gateway' does not use 'nginx' as gatewayClassName."
    exit 1
fi

if ! kubectl get httproute nginx-httproute &> /dev/null; then
    echo "'nginx-httproute' HTTPRoute resource not found."
    exit 1
fi

if ! kubectl get httproute nginx-httproute -o json | grep '"name": "nginx-gateway"' &> /dev/null; then
    echo "HTTPRoute does not reference 'nginx-gateway'."
    exit 1
fi

if ! kubectl get httproute nginx-httproute -ojsonpath='{.spec.rules[*].matches[*].path.value}' | grep / &> /dev/null; then
    echo "HTTPRoute does not match path '/'."
    exit 1
fi

if ! kubectl get httproute nginx-httproute -o json | grep '"name": "nginx-service"' &> /dev/null; then
    echo "HTTPRoute does not route to 'nginx-service'."
    exit 1
fi
if ! kubectl get httproute nginx-httproute -o json | grep '"port": 80' &> /dev/null; then
    echo "HTTPRoute does not route to port 80."
    exit 1
fi

GATEWAY_IP=$(kubectl get gateway nginx-gateway -o jsonpath='{.status.addresses[0].value}')

if [ -z "$GATEWAY_IP" ]; then
    echo "Could not determine Gateway IP address."
    exit 1
fi


if ! curl -s --max-time 5 "http://$GATEWAY_IP/" | grep -i nginx &> /dev/null; then
    echo "Gateway is not routing traffic to nginx backend."
    exit 1
fi

echo "All resources are correctly configured!"
exit 0