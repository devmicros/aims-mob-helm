#!/bin/bash

# --- Configuración de variables ---
# Define el nombre del proyecto de OpenShift. Puedes pasarlo como argumento ($1).
OS_NAMESPACE=${1:-microsafe-aims-mobile}
# Nombre del release de Helm.
PROJECT_RELEASE="aims-mobile"
PROJECT_PATH="helm-aims-mobile"

# --- Funciones de utilidad ---
# Función para verificar si el usuario está autenticado en OpenShift
check_oc_login() {
    if ! oc whoami &> /dev/null; then
        echo "Error: No has iniciado sesión en OpenShift. Por favor, ejecuta 'oc login' primero."
        exit 1
    fi
}


# Paso 1: Verificar el inicio de sesión en OpenShift
check_oc_login

echo "---"
echo "Comenzando la instalación para el proyecto '${OS_NAMESPACE}'."

# Paso 2: Verificar y crear el proyecto si no existe
CURRENT_PROJECT=$(oc project -q)
if [ "$CURRENT_PROJECT" != "$OS_NAMESPACE" ]; then
    if ! oc get project "$OS_NAMESPACE" &> /dev/null; then
        echo "Creando el proyecto '${OS_NAMESPACE}'..."
        oc new-project "$OS_NAMESPACE" --display-name="Aims Mobile" || exit 1
    else
        echo "Cambiando al proyecto '${OS_NAMESPACE}'..."
        oc project "$OS_NAMESPACE" || exit 1
    fi
fi

echo "---"
echo "Actualmente en el proyecto: '$(oc project -q)'"

# Paso 3: Instala o actualiza el Helm chart
echo "Instalando/Actualizando el Helm chart en el proyecto '${OS_NAMESPACE}'..."
helm upgrade --install "$PROJECT_RELEASE" "$PROJECT_PATH" -n "$OS_NAMESPACE"

# Verifica si el comando de Helm fue exitoso
if [ $? -ne 0 ]; then
    echo "Error: La implementación de Helm falló."
    exit 1
fi

echo "---"
echo "Helm deployment iniciado. Verificando el estado de los pods..."

# Paso 4: Esperar a que los pods estén listos de manera más robusta
# Verificar los pods para el servicio aims-db
for i in {1..12}; do # Espera hasta 12 veces (3 minutos)
    POD_STATUS=$(oc get pods -n "$OS_NAMESPACE" -l app=aims-db-service -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    if [ "$POD_STATUS" == "true" ]; then
        echo "Pod 'aims-db-service' está listo."
        break
    fi
    echo "Esperando a 'aims-db-service'..."
    sleep 15
done

# Verifica los pods para el servicio aims-mob
for i in {1..12}; do # Espera hasta 12 veces (3 minutos)
    POD_STATUS=$(oc get pods -n "$OS_NAMESPACE" -l app=aims-mob-service -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    if [ "$POD_STATUS" == "true" ]; then
        echo "Pod 'aims-mob-service' está listo."
        break
    fi
    echo "Esperando a 'aims-mob-service'..."
    sleep 15
done

# Si el bucle termina sin encontrar el pod listo, el script saldrá con un mensaje
if [ "$POD_STATUS" != "true" ]; then
    echo "Error: Los pods no están listos después de 3 minutos. Por favor, verifique el estado manualmente."
    exit 1
fi

# Paso 5: Obtiene las rutas y muestra el resumen del despliegue
echo "---"
echo "Pods listos. Obteniendo las URLs de las rutas..."
ADMIN_URL=$(oc get route aims-mob-admin -n "$OS_NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null)
SERVICE_URL=$(oc get route aims-mob-service -n "$OS_NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null)

echo "--- DEPLOYMENT SUMMARY ---"
echo "Admin URL: https://${ADMIN_URL}"
echo "Service URL: https://${SERVICE_URL}"
echo "--------------------------"
