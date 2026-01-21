#!/bin/bash

# --- Configuración ---
DIAS_ANTIGUEDAD=60
RUTA_BASE="/var/sftp"
LOG_FILE="/var/log/sftp_cleanup.log"
FECHA=$(date '+%Y-%m-%d %H:%M:%S')

# --- Inicio del proceso ---
echo "[$FECHA] --- Iniciando limpieza diaria (Archivos > $DIAS_ANTIGUEDAD días) ---" >> "$LOG_FILE"

# 1. Buscar y listar archivos que SE VAN A BORRAR (para el log)
# Buscamos solo archivos (-type f) en staging o curated para evitar borrar configs si las hubiera
ARCHIVOS_A_BORRAR=$(find "$RUTA_BASE" -type f \( -path "*/staging/*" -o -path "*/curated/*" \) -mtime +$DIAS_ANTIGUEDAD)

if [ -z "$ARCHIVOS_A_BORRAR" ]; then
    echo "[$FECHA] No se encontraron archivos antiguos para borrar." >> "$LOG_FILE"
else
    # Registrar qué archivos se van a ir
    echo "[$FECHA] Se eliminarán los siguientes archivos:" >> "$LOG_FILE"
    echo "$ARCHIVOS_A_BORRAR" >> "$LOG_FILE"
    
    # 2. Ejecutar el borrado real
    find "$RUTA_BASE" -type f \( -path "*/staging/*" -o -path "*/curated/*" \) -mtime +$DIAS_ANTIGUEDAD -delete
    
    echo "[$FECHA] ✅ Eliminación completada con éxito." >> "$LOG_FILE"
fi

echo "--------------------------------------------------------" >> "$LOG_FILE"
