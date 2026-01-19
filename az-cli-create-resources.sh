#!/bin/bash

# --- Variables de Configuración ---
RESOURCE_GROUP="rg-lab-sftp-manual"
LOCATION="eastus2"
VNET_NAME="vnet-sftp-manual"
SUBNET_NAME="subnet-sftp"
NSG_NAME="nsg-sftp-manual"
VM_NAME="vm-sftp-manual"
ADMIN_USERNAME="sftpadmin"
DATA_DISK_SIZE=512

# --- Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Función 1: Crear Recursos con Verificación ---
crear_recursos() {
    echo -e "\n${YELLOW}--- Iniciando Verificación y Despliegue de Infraestructura ---${NC}"

    # 1. Verificar/Crear Grupo de Recursos
    if [ $(az group exists --name $RESOURCE_GROUP) = "true" ]; then
        echo -e "✅ El Grupo de Recursos '$RESOURCE_GROUP' ya existe."
    else
        echo "⏳ Creando Grupo de Recursos..."
        az group create --name $RESOURCE_GROUP --location $LOCATION --output none
        echo -e "${GREEN}✅ RG Creado.${NC}"
    fi

    # 2. Verificar/Crear Red y Seguridad
    # Verificamos si la VNET existe consultando su ID
    VNET_ID=$(az network vnet show --name $VNET_NAME --resource-group $RESOURCE_GROUP --query id -o tsv 2>/dev/null)

    if [ -n "$VNET_ID" ]; then
        echo -e "✅ La red '$VNET_NAME' ya existe."
    else
        echo "⏳ Configurando Red y NSG..."
        az network nsg create -g $RESOURCE_GROUP -n $NSG_NAME -l $LOCATION --output none
        az network nsg rule create -g $RESOURCE_GROUP --nsg-name $NSG_NAME -n AllowSSH --priority 1000 --access Allow --direction Inbound --protocol Tcp --destination-port-ranges 22 --source-address-prefixes '*' --output none
        az network vnet create -g $RESOURCE_GROUP -n $VNET_NAME --address-prefix 10.0.0.0/16 --subnet-name $SUBNET_NAME --subnet-prefix 10.0.0.0/24 --network-security-group $NSG_NAME --output none
        echo -e "${GREEN}✅ Red Configurada.${NC}"
    fi

    # 3. Verificar/Crear VM + Disco
    VM_ID=$(az vm show --name $VM_NAME --resource-group $RESOURCE_GROUP --query id -o tsv 2>/dev/null)

    if [ -n "$VM_ID" ]; then
        echo -e "✅ La VM '$VM_NAME' ya existe."
    else
        # SOLO pedimos contraseña si vamos a crear la VM nueva
        if [ -z "$ADMIN_PASSWORD" ]; then
            DEFAULT_PASS="Manual.$(openssl rand -base64 6)!" 
            echo ""
            echo -e "${YELLOW}🔑 Configuración de Credenciales:${NC}"
            read -s -p "Password Admin VM (Enter para auto): " INPUT_PASS
            echo ""
            if [ -z "$INPUT_PASS" ]; then
                ADMIN_PASSWORD=$DEFAULT_PASS
                echo "⚠️  Usando contraseña autogenerada."
            else
                ADMIN_PASSWORD=$INPUT_PASS
            fi
        fi

        echo "⏳ Creando VM + Disco de $DATA_DISK_SIZE GB (Esto toma unos minutos)..."
        az vm create \
            --resource-group $RESOURCE_GROUP \
            --name $VM_NAME \
            --image "Ubuntu2204" \
            --size "Standard_B1s" \
            --admin-username $ADMIN_USERNAME \
            --admin-password $ADMIN_PASSWORD \
            --vnet-name $VNET_NAME \
            --subnet $SUBNET_NAME \
            --nsg $NSG_NAME \
            --public-ip-sku Standard \
            --data-disk-sizes-gb $DATA_DISK_SIZE \
            --output none
        echo -e "${GREEN}✅ VM Desplegada correctamente.${NC}"
    fi

    # 4. Datos Finales (Siempre los mostramos, aunque la VM ya existiera)
    IP_PUBLICA=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)
    
    echo ""
    echo "=========================================="
    echo -e "   ${GREEN}INFRAESTRUCTURA LISTA${NC}"
    echo "=========================================="
    echo " IP Pública:  $IP_PUBLICA"
    echo " Usuario:     $ADMIN_USERNAME"
    if [ -n "$ADMIN_PASSWORD" ]; then
        echo " Password:    $ADMIN_PASSWORD"
    else
        echo " Password:    (La que configuraste previamente)"
    fi
    echo "=========================================="
    echo "AHORA: Conéctate por SSH y configura el SFTP manualmente."
}

# --- Función 2: Borrar Recursos ---
borrar_recursos() {
    echo ""
    echo -e "${RED}⚠️  ¡ADVERTENCIA! ⚠️${NC}"
    echo "Vas a eliminar el Grupo de Recursos: $RESOURCE_GROUP"
    echo "Esto borrará la VM, el Disco de 512GB, la IP y la Red."
    echo ""
    read -p "¿Estás seguro de continuar? (s/n): " CONFIRM
    
    if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
        echo "⏳ Iniciando eliminación (esto se ejecuta en segundo plano)..."
        az group delete --name $RESOURCE_GROUP --yes --no-wait
        echo -e "${GREEN}✅ Solicitud de eliminación enviada. Los recursos desaparecerán en unos minutos.${NC}"
    else
        echo "❌ Operación cancelada."
    fi
}

# --- Menú Principal ---
while true; do
    echo ""
    echo "----------------------------------------"
    echo "   GESTOR DE INFRAESTRUCTURA SFTP"
    echo "----------------------------------------"
    echo "1. Crear / Verificar Infraestructura"
    echo "2. Eliminar todo el entorno (Cleanup)"
    echo "3. Salir"
    read -p "Elige una opción: " OPCION

    case $OPCION in
        1) crear_recursos ;;
        2) borrar_recursos ;;
        3) echo "Adiós 👋"; exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
done