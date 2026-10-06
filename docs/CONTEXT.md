# Glosario del Dominio (CONTEXT)

Este glosario documenta los términos técnicos, componentes del sistema operativo y conceptos de arquitectura utilizados en la suite **MakeScriptsUtilities**.

---

### 1. Componentes del Sistema Operativo Windows
- **WPF (Windows Presentation Foundation):** Subsistema gráfico de .NET utilizado para renderizar interfaces de usuario basadas en vectores y definidas mediante marcado XAML.
- **XAML (Extensible Application Markup Language):** Lenguaje declarativo basado en XML utilizado para definir la jerarquía visual de la GUI.
- **STA (Single-Threaded Apartment):** Modelo de subprocesamiento COM requerido por WPF en el cual todos los objetos de la interfaz gráfica deben ser creados y manipulados por un único hilo.
- **Dispatcher:** Mecanismo de despacho de mensajes en WPF que encola y ejecuta operaciones de forma segura en el hilo principal de la interfaz desde subprocesos secundarios.
- **UAC (User Account Control):** Mecanismo de seguridad de Windows que restringe el acceso de aplicaciones a recursos administrativos a menos que el usuario autorice explícitamente la elevación de privilegios (`RunAs`).

### 2. Servicios de Windows
- **`Spooler` (Print Spooler):** Servicio encargado de gestionar los trabajos de impresión en cola antes de enviarlos a las impresoras físicas o virtuales.
- **`Audiosrv` (Windows Audio):** Servicio principal de gestión de audio para programas y controladores de sonido.
- **`AudioEndpointBuilder` (Windows Audio Endpoint Builder):** Servicio que gestiona la enumeración y descubrimiento de puntos de conexión de audio (altavoces, auriculares, micrófonos).
- **`wuauserv` (Windows Update Service):** Servicio de detección, descarga e instalación de actualizaciones de Windows y controladores de hardware.
- **`explorer.exe` (Windows Shell):** Proceso responsable de la barra de tareas, menú de inicio, bandeja del sistema, explorador de archivos y entorno de escritorio.

### 3. Herramientas y Protocolos
- **`winget` (Windows Package Manager):** Herramienta de línea de comandos oficial de Microsoft para la instalación, actualización y configuración de software.
- **`ps2exe`:** Módulo de PowerShell que compila scripts `.ps1` en ejecutables `.exe` encapsulados con manifiestos de elevación UAC incrustados.
- **`WMI` / `CIM` (Windows Management Instrumentation / Common Information Model):** Infraestructura para la gestión y consulta de telemetría de hardware, controladores y sistema operativo en Windows.
- **`FlushDNS`:** Operación que borra la memoria caché de resolución DNS del sistema local para resolver problemas de conexión a dominios.
- **`Robocopy` (Robust File Copy):** Comando avanzado de duplicación y migración de archivos con tolerancia a fallas y reintentos automáticos.
