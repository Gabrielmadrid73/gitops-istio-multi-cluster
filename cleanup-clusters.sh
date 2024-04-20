#!/bin/bash

rm -rf istio/*.pem source-apps/*.pem root-*
kind delete clusters -A