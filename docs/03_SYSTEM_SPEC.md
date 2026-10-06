# 03. Especificaciones Técnicas (SYSTEM SPEC)

## 1. Requisitos de Entorno y Plataforma

| Parámetro | Especificación Mínima | Especificación Recomendada |
|-----------|------------------------|----------------------------|
| **Sistema Operativo** | Windows 10 Versión 1809 (Build 17763) | Windows 11 Versión 23H2+ |
| **Arquitectura** | x64 o ARM64 | x64 |
| **PowerShell** | Windows PowerShell 5.1 | PowerShell 5.1 o PowerShell 7.4+ |
| **.NET Framework** | .NET Framework 4.7.2 (WPF) | .NET Framework 4.8.1 / .NET 8 Desktop Runtime |
| **Gestor de Paquetes** | Windows Package Manager (`winget`) v1.4+ | `winget` v1.7+ |
| **Privilegios** | Cuenta local con privilegios de Administrador | Administrador del dominio o Administrador local |

---

## 2. Dependencias de Comandos del Sistema y Servicios

### 2.1. Servicios de Windows Controlados
- **`Spooler`** (Cola de Impresión): Detenido e iniciado vía `net stop / net start` o `Restart-Service`.
- **`Audiosrv` & `AudioEndpointBuilder`** (Audio de Windows): Detenidos con el modificador `/y` para forzar cierre de dependencias vinculadas y reiniciados en orden jerárquico.
- **`wuauserv`** (Windows Update): Detenido e iniciado para limpiar el estado de descarga de actualizaciones atascadas.
- **`explorer.exe`** (Shell de Windows): Finalizado mediante `Stop-Process -Force` o `taskkill /f /im explorer.exe` y relanzado con `Start-Process`.

### 2.2. Comandos de Red y Shell Utilizados
- **`netsh interface set interface name="Wi-Fi" admin=disable|enable`**: Control directo de adaptadores de red inalámbricos.
- **`ipconfig /flushdns`**: Vaciado y reseteo de la caché de nombres DNS del cliente resolver.
- **`ipconfig /renew`**: Renovación forzada de concesiones DHCP para todas las interfaces de red.
- **`robocopy.exe`**: Motor de replicación y migración de archivos de alto rendimiento con flags `/E /MOVE /XF /XD /R:1 /W:1`.
- **`reg.exe`**: Modificación de claves de configuración en el Registro de Windows.
- **`rundll32.exe user32.dll,UpdatePerUserSystemParameters`**: Notificación a la API de Windows para aplicar cambios inmediatos al entorno gráfico sin requerir cierre de sesión.

---

## 3. Especificaciones de Compilación (`ps2exe`)

Para compilar scripts de PowerShell a ejecutables `.exe` independientes:

```powershell
# Parámetros obligatorios de compilación
Invoke-ps2exe `
    -inputFile "c:\ruta\script.ps1" `
    -outputFile "c:\ruta\binario.exe" `
    -requireAdmin `
    -title "Nombre de la Utilidad" `
    -description "Descripción técnica de la herramienta" `
    -company "Orange Latam" `
    -version "1.0.0.0" `
    -noConsole # (Opcional, únicamente para interfaces puramente gráficas)
```

- **`-requireAdmin`**: Inserta la directiva `<requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>` en el manifiesto incrustado del PE.
- **`-noConsole`**: Suprime la asignación de consola estándar (`AllocConsole`), evitando que aparezca una ventana negra detrás de la GUI.
