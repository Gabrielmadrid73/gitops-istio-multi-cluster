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
function kconfig () {
    export KUBECONFIG=~/.kube/$1
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
requirements=("helm" "curl" "flux" "istioctl")
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
    kconfig $cluster
    kubectl create namespace istio-system
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    kubectl taint nodes --all node-role.kubernetes.io/master-
    kubectl label namespace istio-system istio-injection=enabled
    kubectl create secret generic cacerts -n istio-system --from-file=istio/ca-cert.pem --from-file=istio/ca-key.pem --from-file=istio/root-cert.pem --from-file=istio/cert-chain.pem
    flux bootstrap github --token-auth --owner=$githubuser --repository=gitops-istio-multi-cluster --branch=main --path=gitops/$cluster/flux-resources --personal
    # Wait for Istio namespace and installation / SA conflict istio-reader-service-account
    sleep 160
    istioctl create-remote-secret --name=$cluster > secret-$cluster.yaml
done
kconfig source-apps
kubectl apply -f secret-istio.yaml
kubectl rollout restart deploy ecsdemo-crystal ecsdemo-frontend ecsdemo-nodejs -n istio-system
kconfig istio
kubectl apply -f secret-source-apps.yaml
kubectl rollout restart deploy nginx -n istio-system

rm -rf secret-istio.yaml secret-source-apps.yaml

