### 📄 Script 1: `az-cli-create-resources.sh`

Este es el script maestro de **Infraestructura como Código (IaC)**. Su función es interactuar con Azure para aprovisionar "el hardware" necesario antes de configurar el servidor SFTP.

#### 🎯 Funcionalidades Clave

* **Idempotencia (Verificación Inteligente):** Antes de crear cualquier recurso (Grupo de recursos, Red, Disco, VM), el script consulta a Azure si ya existe. Si existe, omite la creación. Esto permite ejecutar el script múltiples veces sin generar errores ni duplicados.
* **Gestión de Disco Independiente:** A diferencia de una creación de VM estándar, este script crea primero un **Disco Gestionado de 512GB** con nivel **Standard SSD** (para optimizar costos y rendimiento) y luego lo adjunta a la máquina virtual.
* **Seguridad de Red:** Configura automáticamente un *Network Security Group (NSG)* abriendo únicamente el puerto **22 (TCP)** para el tráfico SSH/SFTP.

#### ⚙️ Flujo de Ejecución (Opción 1: Crear)

1. **Resource Group:** Crea `rg-lab-sftp-demo` en `eastus2`.
2. **Networking:** Despliega VNet, Subnet y NSG con regla `AllowSSH`.
3. **Almacenamiento:** Aprovisiona un disco de datos de **512 GB** (`StandardSSD_LRS`).
4. **Cómputo:** Despliega una VM Ubuntu 22.04 (`Standard_B1s`) y le adjunta el disco creado en el paso anterior.
5. **Resultado:** Muestra en pantalla la IP Pública y las credenciales de acceso.

#### 🗑️ Limpieza (Opción 2: Eliminar)

Ejecuta el comando `az group delete` con el parámetro `--no-wait`. Esto envía la orden de destrucción a Azure inmediatamente, eliminando la VM, el disco, la IP y la red sin bloquear tu terminal.

#### 📝 Variables Configurables

Al inicio del script puedes ajustar:

* `DATA_DISK_SIZE`: Tamaño del disco de datos (Default: `512` GB).
* `VM_NAME`: Nombre de la instancia.
* `LOCATION`: Región de Azure (Default: `eastus2`).


---

### 📄 Script 2: `nuevo_sftp` (Gestor Interno)

Este script **Bash interactivo** se instala dentro de la Máquina Virtual (en `/usr/local/bin/nuevo_sftp`) y actúa como un panel de control para administrar usuarios y permisos sin necesidad de memorizar comandos complejos de Linux.

#### 🌟 Características Principales

* **Menú Interactivo (CRUD):** Permite Crear, Bloquear, Desbloquear y Borrar archivos de usuarios mediante un menú numérico simple.
* **Seguridad Automática (Chroot Jail):** Al crear un usuario, el script configura automáticamente los permisos `root:root` en la carpeta base y crea las subcarpetas `staging` y `curated` con los permisos correctos. Esto garantiza que el usuario **nunca pueda salir de su carpeta** (Jail).
* **Gestión de Contraseñas:**
* Generación automática de contraseñas seguras con `openssl`.
* O opción de ingreso manual con confirmación.


* **Sistema de Logs:** Todas las acciones administrativas (creación de usuarios, bloqueos, limpiezas) se registran con fecha y hora en `/var/log/sftp_manager.log` para fines de auditoría.
* **Roles:** Permite crear tanto **Clientes SFTP** (restringidos, sin shell) como **Administradores** (con acceso `sudo` y SSH completo).

#### 📋 Funciones del Menú

1. **Crear Cliente SFTP:** Genera un usuario aislado, asigna contraseña y muestra los datos de conexión (Host, User, Pass) listos para enviar al cliente.
2. **Bloquear Cliente (Lock):** Deshabilita el acceso temporalmente (bloquea la contraseña) sin borrar los datos. Útil para suspender servicios por falta de pago o seguridad.
3. **Desbloquear Cliente (Unlock):** Restaura el acceso al usuario bloqueado.
4. **Crear Administrador:** Crea un "Superusuario" con acceso total al sistema (SSH + Sudo), útil para delegar la administración sin compartir la clave de `root`.
5. **Limpiar Archivos:** Borra todo el contenido de las carpetas `staging` y `curated` de un usuario específico (pidiendo confirmación doble).
6. **Ver Logs:** Muestra en pantalla las últimas 10 acciones realizadas en el servidor.

#### 💾 Ubicación y Logs

* **Ruta del Script:** `/usr/local/bin/nuevo_sftp`
* **Archivo de Log:** `/var/log/sftp_manager.log`
* **Ejecución:** Debe correrse siempre con privilegios elevados: `sudo nuevo_sftp`.

---

### 🔗 Flujo de Trabajo Recomendado

1. **Día 0 (Despliegue):**
* Ejecutas `az-cli-create-resources.sh` desde tu PC para crear la infraestructura en Azure.
* Te conectas por SSH y configuras el disco y el SSH manualmente (ver Guía Paso a Paso).
* Instalas el script `nuevo_sftp` en el servidor.


2. **Día 1 (Operación):**
* Cada vez que necesites un usuario nuevo, entras por SSH y corres `sudo nuevo_sftp` -> Opción 1.
* Copias las credenciales que te da el script y se las envías al cliente.


3. **Mantenimiento:**
* Si un cliente deja de trabajar, usas la Opción 2 (Bloquear).
* Si necesitas auditar quién creó un usuario, revisas la Opción 6 (Logs).

---


### 📄 Script 3: `sftp_autoclean.sh` (Mantenimiento Automático)

Este script se encarga de la **higiene del almacenamiento**. En un servidor SFTP activo, es común que los archivos antiguos se acumulen hasta llenar el disco. Este script automatiza el borrado de archivos viejos basándose en una política de retención configurable.

#### 🛡️ Características de Seguridad

* **Ámbito Restringido:** El script no borra "a ciegas". Utiliza un filtro estricto para eliminar **solo** archivos que estén dentro de las carpetas de trabajo (`/staging` y `/curated`). Esto protege los archivos de configuración del sistema o las carpetas raíz de los usuarios.
* **Auditoría (Logs):** Antes de borrar nada, el script registra en `/var/log/sftp_cleanup.log` la lista exacta de archivos que van a ser eliminados. Si algo desaparece, sabrás cuándo y por qué fue.
* **Configurable:** Puedes cambiar la variable `DIAS_ANTIGUEDAD` al inicio del script para ajustar la política (ej: 30, 60, 90 días).

#### ⚙️ Instalación y Programación (Cron)

Este script no se ejecuta manualmente (aunque se puede), sino que está diseñado para vivir en el programador de tareas de Linux (**Cron**).

1. **Crear el script:**
```bash
sudo nano /usr/local/bin/sftp_autoclean.sh
# (Pega el contenido del script aquí)

```


2. **Dar permisos de ejecución:**
```bash
sudo chmod +x /usr/local/bin/sftp_autoclean.sh

```


3. **Programar la tarea (Cronjob):**
Abre el editor de cron:
```bash
sudo crontab -e

```


Agrega la siguiente línea al final del archivo para ejecutarlo **todos los días a las 00:00 hs**:
```bash
0 0 * * * /usr/local/bin/sftp_autoclean.sh

```



#### 🔍 Verificación

Para verificar que el sistema está limpiando correctamente, puedes revisar el log de actividad:

```bash
cat /var/log/sftp_cleanup.log

```

**Salida de ejemplo:**

```text
[2023-10-25 00:00:01] --- Iniciando limpieza diaria (Archivos > 60 días) ---
[2023-10-25 00:00:01] Se eliminarán los siguientes archivos:
/var/sftp/cliente01/staging/backup_old.zip
/var/sftp/cliente02/curated/reporte_v1.csv
[2023-10-25 00:00:02] ✅ Eliminación completada con éxito.
--------------------------------------------------------

```

---

### 🏁 Conclusión del Repositorio

Con estos 3 componentes, tienes una solución **SFTP Enterprise** completa:

1. **Infraestructura (`az-cli...`)**: Despliegue rápido, reproducible y económico en Azure.
2. **Administración (`nuevo_sftp`)**: Gestión de usuarios simplificada, segura y estandarizada.
3. **Mantenimiento (`sftp_autoclean`)**: Ciclo de vida de datos automatizado para evitar problemas de espacio.
