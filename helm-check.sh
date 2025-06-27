#!/bin/bash
#git clone https://github.com/techiescamp/helm-tutorial.git
#helm create aims-chart

cd aims-chart
helm lint .
helm template .
cd ..
helm install --dry-run my-release aims-chart
