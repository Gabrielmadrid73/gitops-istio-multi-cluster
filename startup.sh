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
requirements=("kind" "helm" "curl" "flux")
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

echo -e "\nCreating clusters."
kind create cluster --config=clusters/istio.yaml
kind create cluster --config=clusters/source-apps.yaml
kind create cluster --config=clusters/target-apps.yaml

echo -e "\nCreated clusters:"
kind get clusters
clusters=$(kind get clusters)

for cluster in ${clusters[@]};do
    echo -e "\nSetting context to $cluster cluster."
    kubectl config use-context kind-$cluster
    flux bootstrap github --token-auth --owner=$githubuser --repository=gitops-istio-multi-cluster --branch=main --path=gitops/$cluster --personal
done

