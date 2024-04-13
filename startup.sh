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
requirements=("flux" "istioctl")
for binary in ${requirements[@]}; do 
    if ! command -v $binary &> /dev/null; then
        echo "ERROR - $binary not installed."
        exit 1
    fi
done

clusters_file=(istio source-apps)

make -f Makefile.selfsigned.mk root-ca


for cluster in ${clusters_file[@]};do
    make -f Makefile.selfsigned.mk $cluster-cacerts
    kconfig $cluster
    ip=$(cat $KUBECONFIG | grep server | awk '{print $2}' | sed 's/:6443//' | sed 's/https:\/\///')
    echo $ip
    kubectl create namespace istio-system
    kubectl label namespace istio-system topology.istio.io/network=network-$cluster
    kubectl label namespace istio-system istio-injection=enabled 
    kubectl create secret generic cacerts -n istio-system --from-file=$cluster/ca-cert.pem --from-file=$cluster/ca-key.pem --from-file=$cluster/root-cert.pem --from-file=$cluster/cert-chain.pem
    flux bootstrap github --token-auth --owner=$githubuser --repository=gitops-istio-multi-cluster --branch=main --path=gitops/$cluster/flux-resources --personal
    # Wait for Istio namespace and installation / SA conflict istio-reader-service-account
    echo "waiting 5 minutes to resources be running..."
    sleep 300
    istioctl create-remote-secret --name=$cluster > secret-$cluster.yaml
    kubectl patch service istio-eastwestgateway --patch "{\"spec\": {\"externalIPs\": [$ip]}}" -n istio-system
done

kconfig source-apps
kubectl apply -f secret-istio.yaml
# kubectl rollout restart deploy ecsdemo-crystal ecsdemo-frontend ecsdemo-nodejs -n apps

kconfig istio
kubectl apply -f secret-source-apps.yaml
# kubectl rollout restart deploy nginx -n tools

rm -rf secret-istio.yaml secret-source-apps.yaml

echo "DONE"