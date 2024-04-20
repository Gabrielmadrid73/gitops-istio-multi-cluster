./startup.sh -u $GITHUB_USER -t $GITHUB_TOKEN

kubectl port-forward service/istio-ingressgateway -n istio-system --context=kind-istio 8080:80

for x in {0..500}; do curl -H 'Host: helloworld.batatinha.com' http://127.0.0.1:8080/hello; done

kubectl get secret -n istio-system --context=kind-istio

kubectl delete secret istio-remote-secret-source-apps -n istio-system --context=kind-istio