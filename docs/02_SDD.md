# 02. Diseño del Sistema (SDD) — Suite MakeScriptsUtilities

## 1. Arquitectura General

La suite está estructurada como un conjunto desacoplado de herramientas nativas para Windows. Cada componente opera de forma independiente y comparte convenciones de diseño visual, elevación de privilegios y registro de eventos.

```
makeScriptsUtilities/
├── ActualizarApps/            # Gestor de actualización winget (CLI + .exe)
│   ├── ActualizarApps.exe    # Binario standalone compilado con ps2exe
│   ├── updateScripts.ps1     # Lógica central en PowerShell
│   ├── CLAUDE.md             # Guía de compilación
│   └── logs/                 # Registros de actualización
├── InfoEquipo/               # Módulo de auditoría de hardware (WMI/CIM)
│   ├── InfoEquipo.ps1        # Script de extracción de métricas
│   ├── InfoEquipo.bat        # Lanzador rápido
│   └── logs/                 # Reportes exportados
├── utilities/                # Gestor y reinicio de servicios
│   ├── UtilidadOrangeLatam.GUI.ps1 # Interfaz gráfica moderna WPF/XAML
│   ├── UtilidadOrangeLatamGUI.bat  # Lanzador directo de la GUI
│   └── UtilidadOrangeLatam.bat     # Menú de consola tradicional
├── Limpiar-Perfil.bat        # Mantenimiento y respaldo de perfil de usuario
└── docs/                     # Suite de documentación del proyecto
```

---

## 2. Arquitectura de la Interfaz Gráfica (WPF / XAML)

El componente `utilities/UtilidadOrangeLatam.GUI.ps1` implementa una arquitectura desacoplada basada en eventos y despacho asíncrono sobre el motor de renderizado WPF de .NET.

```
┌─────────────────────────────────────────────────────────────┐
│                    Ventana WPF (XAML UI)                   │
│  ┌───────────────────────┐   ┌───────────────────────────┐  │
│  │ Panel de Botones      │   │ Terminal de Logs en Vivo │  │
│  │ (Acciones de Servicio)│   │ (TextBox Scrolleable)     │  │
│  └───────────┬───────────┘   └─────────────▲─────────────┘  │
└──────────────┼─────────────────────────────┼────────────────┘
               │ Evento Click                │ Dispatcher.Invoke()
               ▼                             │
┌────────────────────────────────────────────┴────────────────┐
│               Manejador Asíncrono (Task::Run)              │
│  1. Desactiva controles de UI                              │
│  2. Actualiza barra de estado a "BUSY"                     │
│  3. Ejecuta comando del sistema (netsh, net stop, etc.)     │
│  4. Emite líneas de log con timestamp al Dispatcher         │
│  5. Restablece controles y estado a "DONE" o "ERROR"       │
└─────────────────────────────────────────────────────────────┘
```

### 2.1. Componentes Clave de la GUI:
1. **Thread Apartment STA:** Se valida y fuerza el modo `[ApartmentState]::STA` necesario para la interoperabilidad de controles WPF en PowerShell.
2. **Elevación UAC Transparente:** Valida la pertenencia al rol `Administrator`. Si no está elevado, ejecuta `Start-Process powershell -Verb RunAs` y cierra la instancia previa.
3. **Dispatcher & Thread Safety:** Las llamadas desde hilos secundarios hacia los elementos visuales (`txtLogs`, `txtStatusMessage`, `btn*`) se canalizan a través de `$window.Dispatcher.Invoke()`.
4. **Resistencia a Congelamiento:** Todo proceso de red o reinicio de servicios se ejecuta dentro de un `[System.Threading.Tasks.Task]::Run`, permitiendo que la ventana responda a eventos del usuario (como scroll o redimensionamiento) en todo momento.

---

## 3. Arquitectura del Actualizador (`ActualizarApps`)

1. **Parser de Salida Winget:** Invoca `winget upgrade --include-unknown` capturando la salida en texto plano, detecta los encabezados tabulares (`Name`, `Id`, `Version`, `Available`, `Source`) y mapea cada registro en un objeto estructurado `[PSCustomObject]`.
2. **Filtrado y Ejecución:** Itera sobre la lista de paquetes pendientes ejecutando `winget upgrade --id <Id> --silent --accept-source-agreements --accept-package-agreements`.
3. **Compilación Binaria:** Utiliza el módulo `ps2exe` para empaquetar el script en un ejecutable PE de 64 bits con manifiesto `requireAdministrator`.

---

## 4. Arquitectura de Auditoría (`InfoEquipo`)

1. **Capa de Abstracción WMI/CIM:** Emplea los cmdlets `Get-CimInstance` / `Get-WmiObject` sobre los namespaces de administración `root/cimv2` y `root/wmi`.
2. **Colección de Entidades:**
   - `Win32_Processor` (CPU)
   - `Win32_PhysicalMemory` (RAM)
   - `Win32_DiskDrive` & `Win32_LogicalDisk` (Almacenamiento)
   - `Win32_VideoController` (Gráficos)
   - `Win32_NetworkAdapterConfiguration` (Redes)
   - `Win32_BaseBoard` & `Win32_OperatingSystem` (Sistema)
3. **Formateador de Datos:** Normaliza capacidades en bytes a unidades legibles (GB, MB) y renderiza tablas ASCII coloreadas en la consola.
