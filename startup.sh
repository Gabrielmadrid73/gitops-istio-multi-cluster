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
        u)
            githubuser=${OPTARG};;
        t)
            githubtoken=${OPTARG};;
        -*)
            echo "Error: Unsupported flag $1" >&2
            exit 1;;
    esac
done

export GITHUB_TOKEN=$githubtoken

echo "Checking binaries requirements."
requirements=("flux" "istioctl" "kind" "git" "kubectl" "make")
for binary in ${requirements[@]}; do 
    if ! command -v $binary &> /dev/null; then
        echo "ERROR - $binary not installed."
        exit 1
    fi
done

clusters_file=(istio source-apps target-apps)

make -f Makefile.selfsigned.mk root-ca

for cluster in ${clusters_file[@]};do
    sed -i '' -e "s/0.0.0.0/$ip/" clusters/$cluster.yaml
    echo -e "\nCreating cluster $cluster."
    kind create cluster --config=clusters/$cluster.yaml
    git restore clusters/$cluster.yaml
    make -f Makefile.selfsigned.mk $cluster-cacerts
    kubectl create namespace istio-system --context=kind-$cluster
    kubectl label namespace istio-system topology.istio.io/network=network-$cluster --context=kind-$cluster
    kubectl create secret generic cacerts -n istio-system --from-file=$cluster/ca-cert.pem --from-file=$cluster/ca-key.pem --from-file=$cluster/root-cert.pem --from-file=$cluster/cert-chain.pem --context=kind-$cluster
    flux bootstrap github --token-auth --owner=$githubuser --repository=gitops-istio-multi-cluster --branch=main --path=gitops/$cluster/flux-resources --personal --context=kind-$cluster
    echo "waiting 2 minutes to resources be running..."
    sleep 120
    istioctl create-remote-secret --name=$cluster --context=kind-$cluster > secret-$cluster.yaml
done

kubectl apply -f secret-source-apps.yaml --context=kind-istio
kubectl apply -f secret-target-apps.yaml --context=kind-istio

kubectl apply -f secret-istio.yaml --context=kind-source-apps
kubectl apply -f secret-target-apps.yaml --context=kind-source-apps

kubectl apply -f secret-istio.yaml --context=kind-target-apps
kubectl apply -f secret-source-apps.yaml --context=kind-target-apps

rm -rf secret-istio.yaml secret-source-apps.yaml secret-target-apps.yaml

echo "DONE"