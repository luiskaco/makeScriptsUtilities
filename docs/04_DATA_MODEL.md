# 04. Modelo de Datos y Estructuras (DATA MODEL)

## 1. Estructura de Mensajes y Logs de la GUI (`UtilidadOrangeLatam.GUI.ps1`)

Los eventos generados por la interfaz gráfica se transmiten a la consola mediante una estructura normalizada de registro:

```powershell
[PSCustomObject]@{
    Timestamp = [DateTime]::Now.ToString("HH:mm:ss")  # Formato: 24h
    Level     = "INFO" | "SUCCESS" | "WARN" | "ERROR" # Severidad del evento
    Prefix    = "[i INFO]" | "[✓ OK]" | "[! ADVERTENCIA]" | "[✕ ERROR]"
    Message   = [string]                              # Texto informativo o técnico
}
```

### Formato de salida en terminal:
```text
[15:40:12] [✓ OK] Utilidad Orange Latam iniciada con éxito.
[15:40:12] [i INFO] Permisos de Administrador verificados.
[15:40:30] [i INFO] Iniciando tarea: Reinicio de Cola de Impresión
[15:40:31] [✓ OK] Tarea 'Reinicio de Cola de Impresión' completada correctamente.
```

---

## 2. Estructura de Datos de Actualización (`ActualizarApps`)

La salida tabular de `winget` es transformada internamente en una colección de objetos fuertemente tipados:

```powershell
[PSCustomObject]@{
    Name             = [string] # Nombre comercial del software (ej. "Google Chrome")
    Id               = [string] # Identificador único de paquete (ej. "Google.Chrome")
    InstalledVersion = [string] # Versión actualmente instalada en el equipo
    AvailableVersion = [string] # Versión más reciente disponible en repositorio
    Source           = [string] # Origen del paquete ("winget", "msstore", etc.)
    UpdateStatus     = "Pending" | "Success" | "Failed" | "Skipped"
}
```

---

## 3. Modelo de Telemetría de Hardware (`InfoEquipo`)

El módulo `InfoEquipo` estructura las consultas WMI/CIM en las siguientes entidades:

### 3.1. Entidad `ProcessorInfo`
```json
{
  "DeviceID": "CPU0",
  "Name": "Intel(R) Core(TM) i7-13700K",
  "NumberOfCores": 16,
  "NumberOfLogicalProcessors": 24,
  "MaxClockSpeed": 3400,
  "Architecture": "x64"
}
```

### 3.2. Entidad `MemoryInfo`
```json
{
  "TotalPhysicalBytes": 34359738368,
  "TotalFormatted": "32.0 GB",
  "FreePhysicalBytes": 18253611008,
  "FreeFormatted": "17.0 GB",
  "SlotsUsed": 2,
  "TotalSlots": 4
}
```

### 3.3. Entidad `StorageDriveInfo`
```json
{
  "DeviceID": "\\\\.\\PHYSICALDRIVE0",
  "Model": "Samsung SSD 980 PRO 1TB",
  "InterfaceType": "NVMe",
  "SizeBytes": 1000204886016,
  "Partitions": [
    {
      "DriveLetter": "C:",
      "FileSystem": "NTFS",
      "TotalSize": "953.2 GB",
      "FreeSpace": "420.5 GB"
    }
  ]
}
```

---

## 4. Estructura de Respaldo de Usuario (`Limpiar-Perfil.bat`)

La estructura generada en el almacenamiento del usuario sigue la siguiente jerarquía fija:

```
%USERPROFILE%\Desktop\Respaldo_Usuario\
├── Escritorio\    # Archivos, accesos directos y carpetas originales del Escritorio
├── Descargas\     # Instaladores, documentos descargados y archivos temporales
└── Documentos\    # Archivos personales y datos de usuario
```
