#!/bin/bash

kind delete cluster --name istio
kind delete cluster --name source-apps
kind delete cluster --name target-apps
rm -rf istio/ca-cert.pem istio/ca-key.pem istio/root-cert.pem istio/cert-chain.pem root-ca.conf root-cert.csr root-cert.pem root-key.pem root-cert.srl