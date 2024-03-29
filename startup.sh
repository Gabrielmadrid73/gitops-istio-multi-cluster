#!/bin/bash
echo "Checking binaries requirements."
requirements=("kind" "helm" "curl" "flux")
for binary in ${requirements[@]}; do 
    echo $binary
    if ! command -v $binary &> /dev/null; then
        echo "ERROR - $binary not installed."
        if [ $binary = "flux" ]; then
            echo -e "\nInstalling Flux"
            curl -s https://fluxcd.io/install.sh | bash
            continue
        fi
        exit 1
    fi
done

echo -e "\nCreating clusters."
kind create cluster --config=clusters/istio.yaml
kind create cluster --config=clusters/source-apps.yaml
kind create cluster --config=clusters/target-apps.yaml

echo -e "\nCreated clusters:"
kind get clusters

echo -e "\nSetting context to Istio cluster."
kubectl config use-context kind-istio

