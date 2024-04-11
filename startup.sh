#!/bin/bash
Help()
{
    # Display Help
    echo "The commands are: "
    echo
    echo "u    Github Username to authenticate on repository."
    echo "t    Github PAT to authenticate on repository, see the docs https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens ."
    echo
    echo "Usage: "
    echo
    echo "./startup.sh -u <string> -t <string>"
    echo
}

while getopts ":u:t:" option; do
    case $option in
        h)
            Help
            exit;;
         \?)
            echo "Error: Invalid option"
            exit;;
        u) githubuser=${OPTARG};;
        t) githubtoken=${OPTARG};;
    esac
done

export GITHUB_TOKEN=$githubtoken

echo "Checking binaries requirements."
requirements=("kind" "helm" "curl" "flux" "istioctl")
for binary in ${requirements[@]}; do 
    if ! command -v $binary &> /dev/null; then
        echo "ERROR - $binary not installed."
        exit 1
    fi
done

clusters_file=(istio source-apps)

make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk istio-cacerts

for cluster in ${clusters_file[@]};do
    kubectl create namespace istio-system --kubeconfig=~/.kube/$cluster
    kubectl label namespace istio-system istio-injection=enabled --kubeconfig=~/.kube/$cluster
    kubectl create secret generic cacerts -n istio-system --from-file=istio/ca-cert.pem --from-file=istio/ca-key.pem --from-file=istio/root-cert.pem --from-file=istio/cert-chain.pem --kubeconfig=~/.kube/$cluster
    flux bootstrap github --token-auth --owner=$githubuser --repository=gitops-istio-multi-cluster --branch=main --path=gitops/$cluster/flux-resources --personal --kubeconfig=~/.kube/$cluster
    # Wait for Istio namespace and installation / SA conflict istio-reader-service-account
    sleep 160
    istioctl create-remote-secret --name=$cluster --kubeconfig=~/.kube/$cluster > secret-$cluster.yaml
done

kubectl apply -f secret-istio.yaml --kubeconfig=~/.kube/source-apps
kubectl apply -f secret-source-apps.yaml --kubeconfig=~/.kube/istio

rm -rf secret-istio.yaml secret-source-apps.yaml

kubectl rollout restart deploy ecsdemo-crystal ecsdemo-frontend ecsdemo-nodejs -n istio-system --kubeconfig=~/.kube/source-apps
kubectl rollout restart deploy nginx -n istio-system --kubeconfig=~/.kube/istio