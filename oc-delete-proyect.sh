#!/bin/bash

deployments=$(oc get deployments | grep -E 'aims\-|comm\-|data\-' | awk '{print $1}')

for dpm in $deployments; do
  oc delete deployments $dpm
done

services=$(oc get services | grep -E 'aims\-|comm\-' | awk ' {print $1}')

for svc in $services; do
  oc delete services $svc
done

volumes=$(oc get pvc | grep -E 'aims\-|comm\-' | awk '{print $1}')

for pvc in $volumes; do
  oc delete pvc $pvc
done

routes=$(oc get routes | grep -E 'aims\-|comm\-' | awk '{print $1}')

for rts in $routes; do
  oc delete routes $rts
done

configmap=$(oc get configmap | grep 'aims' | awk '{print $1}')

for cmap in $configmap; do
  oc delete configmap $cmap
done

secrets=$(oc get secrets | grep 'aims' | awk '{print $1}')

for sec in $secrets; do
  oc delete secrets $sec
done