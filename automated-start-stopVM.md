# Automatización de Encendido/Apagado de VM en Azure (Cost Saving)

Este documento detalla el procedimiento para configurar una **Azure Automation Account** que gestiona el ciclo de vida de una Máquina Virtual (VM) para optimizar costos.

**Objetivo:**

* **Encender** la VM automáticamente de Lunes a Viernes a las **08:00 AM**.
* **Apagar** la VM automáticamente de Lunes a Viernes a las **19:00 PM**.
* Mantener la VM apagada fines de semana.

---

## 1. Prerrequisitos

* Una Máquina Virtual (VM) existente en Azure.
* Permisos de "Owner" o "User Access Administrator" en la suscripción (para asignar roles).

## 2. Creación de la Cuenta de Automatización

1. En el portal de Azure, buscar **"Automation Accounts"**.
2. Crear una nueva cuenta:
* **Resource Group:** El mismo de la VM (recomendado).
* **Region:** **IMPORTANTE:** Debe ser la misma región que la VM.


3. Una vez creada, ir al recurso.

## 3. Configuración de Seguridad (Managed Identity)

Para evitar guardar credenciales en el script, utilizamos la **Identidad Administrada del Sistema**.

1. **En la Automation Account:**
* Ir al menú lateral `Identity` (bajo Account Settings).
* En la pestaña **System assigned**, cambiar el estado a **On**.
* Guardar y confirmar.


2. **En la Máquina Virtual (VM):**
* Ir al menú lateral `Access control (IAM)`.
* Clic en `Add` > `Add role assignment`.
* **Rol:** Seleccionar **"Virtual Machine Contributor"**.
* **Members:** Seleccionar "Managed Identity".
* Clic en `+ Select members` > Elegir la suscripción > En "Managed identity" elegir **Automation Account** > Seleccionar la cuenta creada en el paso 2.
* Guardar cambios.



## 4. Creación del Runbook (Script)

1. En la Automation Account, ir a `Runbooks` > `Create a runbook`.
2. **Nombre:** `StartStop-VM`.
3. **Tipo:** PowerShell.
4. **Runtime Version:** 5.1.
5. Pegar el siguiente código y hacer clic en **Save** y luego **Publish**.

```powershell
Param(
    [string]$ResourceGroupName,
    [string]$VMName,
    [string]$Action
)

# Conectar a Azure usando la Identidad Administrada (System Assigned)
# Esto evita tener que escribir usuarios y contraseñas en el código
Connect-AzAccount -Identity

# Lógica de encendido/apagado
if ($Action -eq "start") {
    Write-Output "Iniciando la VM: $VMName"
    Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
}
elseif ($Action -eq "stop") {
    Write-Output "Deteniendo la VM: $VMName"
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
}
else {
    Write-Error "Acción no válida. Use 'start' o 'stop'."
}

```

## 5. Programación de Horarios (Schedules)

Se deben crear dos programaciones vinculadas al mismo Runbook.

### A. Horario de Encendido (Start)

1. En el Runbook, ir a `Link to schedule`.
2. **Schedule:** Crear nuevo (ej: `Start-MonFri`).
* Hora: 08:00 AM.
* Recurrencia: Semanal (Lunes, Martes, Miércoles, Jueves, Viernes).


3. **Parameters:**
* **ResourceGroupName:** (Nombre del grupo de recursos de la VM).
* **VMName:** (Nombre de la VM).
* **Action:** `start`



### B. Horario de Apagado (Stop)

1. En el Runbook, ir a `Link to schedule`.
2. **Schedule:** Crear nuevo (ej: `Stop-MonFri`).
* Hora: 19:00 PM.
* Recurrencia: Semanal (Lunes, Martes, Miércoles, Jueves, Viernes).


3. **Parameters:**
* **ResourceGroupName:** (Mismo grupo).
* **VMName:** (Misma VM).
* **Action:** `stop`



---

## 6. Validación

Para probar el funcionamiento sin esperar al horario:

1. Abrir el Runbook.
2. Clic en **Start** (icono de play superior).
3. Ingresar los parámetros manualmente y escribir `start` o `stop` en el campo Action.
4. Verificar en el portal si la VM cambió de estado.

---
