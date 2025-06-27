#!/bin/bash
aimsproject=aims-microsafe

searchpod=""
podname=""

if [ ! -z "$1" ]; then
	aimsproject=$1
fi

echo "Install on project ${aimsproject}"

pod_status()
{
  status=""
  podname=""
  retries=0
  while [ -z "${podname}" ]
  do
    status="$(oc get pods | grep ${searchpod} |  awk -F ' ' '{print $3}')"
    if [ "${status}" == "Running" ]; then
    	podname="$(oc get pods | grep ${searchpod} |  awk -F ' ' '{print $1}')"
    else
    	retries=$((retries+1))	
		echo -e "\nWaiting for the pod to start ${searchpod}..."    
    	read -t 8 -p "Retries ${retries}/20"
    	if [[ "$retries" == '20' ]]; then
                break
        fi
    fi
  done

  if [ -z "${podname}" ]; then
	echo -e "\nNot running pod ${searchpod}.\n"
  else
    echo -e "\nRunning pod ${podname}.\n"
  fi
}


project="$(oc projects 2>/dev/null |  grep 'You have')"
if [ ! -z "${project}" ]; then
  
  app="$(oc projects | grep '\"'${aimsproject}'\"')"
  #echo "Project aims: ${app}"
  if [ -z "${app}" ]; then
  	echo -e "Creating project ${aimsproject}\n"
  	oc new-project ${aimsproject} --display-name 'aims-mob'
  elif [ "${project}" != "${aimsproject}" ]; then  
  	echo -e "Switching to project ${aimsproject}\n"
  	oc project ${aimsproject}
  fi
    
  project="$(oc project 2>/dev/null |  awk -F '"' '{print $2}')"  
  echo "On project: ${project}"
  
  if [ "${project}" == "${aimsproject}" ]; then
    oc adm policy add-scc-to-user privileged -z default -n ${project} 2>/dev/null

    echo 'Deleting previous project...'
    source ./oc-delete-proyect.sh
    
    
    cd aims-chart
    cp -f values-yaml values.yaml
    
    sg='s/app-name/'${project}'/g'
    sed -i ${sg} values.yaml
        
    suppgrp="$(oc describe project ${project} | grep 'supplemental-groups' | awk -F '=' '{print $2}' | awk -F '/' '{print $1}')"
        
    if [ ! -z "${suppgrp}" ]; then
      sg='s/supp-group/'${suppgrp}'/g' 
    else
      sg='s/supp-group//g'
    fi
    
    sed -i ${sg} values.yaml	   

    echo -e "\n"
    cd ..
    echo 'Installing Helm...'
    
    {
    helm install aims-mob aims-chart 2>/dev/null
    } || {
    helm upgrade --install  aims-mob aims-chart 2>/dev/null
    } || {
      echo 'Error al instalar Helm.'
    exit
    }
    searchpod='aims\-db\-' 
    pod_status
    aimsdb=${podname}
    searchpod='comm\-db\-' 
    pod_status
    commdb=${podname}
  
	if [ ! -z "${podname}" ]; then
       

      echo -e "\nSynchronizing routes:\n"
    
      aimshttp="$(oc get routes 2>/dev/null | grep 'aims-mob-admin' | awk -F ' ' '{print $2}')"
      aimsws="$(oc get routes 2>/dev/null | grep 'aims-mob-ws' | awk -F ' ' '{print $2}')"
    
      echo ${aimshttp}
      echo ${aimsws}
      echo -e "${aimsgql} \n"
    
      oc get -o yaml  deployment/aims-http > aims-mob-http.yaml
      oc get -o yaml  deployment/aims-ws > aims-mob-ws.yaml
    
      sg='s/aims-gql.microsafe.com.mx/'${aimsgql}'/g'
      sed -i ${sg} aims-mob-http.yaml    
      sed -i ${sg} aims-mob-ws.yaml
      sg='s/aims-ws.microsafe.com.mx/'${aimsws}'/g'
      sed -i ${sg} aims-mob-http.yaml    
      sg='s/aims-http.microsafe.com.mx/'${aimshttp}'/g'
      sed -i ${sg} aims-mob-ws.yaml
           
      oc replace  deployment/aims-http -f aims-mob-http.yaml
      oc replace  deployment/aims-ws -f aims-mob-ws.yaml
    
      searchpod='aims\-http\-' 
      pod_status
      searchpod='aims\-ws\-' 
      pod_status
    
      rm aims-mob*.yaml
      
      echo -e "\nStatus of project ${project}:\n"
      helm list
      echo -e "\nAIMS URL:"
      oc get routes | grep 'aims-http'
      echo -e "\nSERVICE IP:PORT FOR RANDOMIC LOCK:"
      oc get routes | grep 'comm-ws'
      echo -e "\n"
    else
  	  echo "Pods not found:\n"
  	  oc get pods
  	fi
  else
  	echo "Project not found: ${aimsproject}."
  fi
else
 echo -e "\n Not logged in."
fi

