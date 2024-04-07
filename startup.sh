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
        if [ $binary = "flux" ]; then
            echo -e "\nInstalling Flux"
            curl -s https://fluxcd.io/install.sh | bash
            continue
        fi
        exit 1
    fi
done

clusters_file=(istio source-apps)
ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d\  -f2)

for cluster in ${clusters_file[@]}; do 
    sed -i '' -e "s/0.0.0.0/$ip/" clusters/$cluster.yaml
    echo -e "\nCreating cluster $cluster."
    kind create cluster --config=clusters/$cluster.yaml
done
git restore ./clusters

echo -e "\nCreated clusters:"
kind get clusters
clusters=$(kind get clusters)

for cluster in ${clusters[@]};do
    echo -e "\nSetting context to $cluster cluster."
    kubectl config use-context kind-$cluster
    flux bootstrap github --token-auth --owner=$githubuser --repository=gitops-istio-multi-cluster --branch=main --path=gitops/$cluster --personal
    istioctl create-remote-secret --context=kind-$cluster --name=$cluster > secret-$cluster.yaml
done

sleep 120

kubectl apply -f secret-istio.yaml --context=kind-source-apps
kubectl apply -f secret-source-apps.yaml --context=kind-istio