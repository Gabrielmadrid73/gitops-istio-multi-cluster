#!/bin/bash

kind delete cluster --name istio
kind delete cluster --name source-apps
kind delete cluster --name target-apps
