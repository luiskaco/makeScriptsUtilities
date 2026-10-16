# 08. Historial de Cambios (CHANGELOG)

Todas las modificaciones notables de la suite **MakeScriptsUtilities** se documentan en este archivo siguiendo las convenciones de [Keep a Changelog](https://keepachangelog.com/).

---

## [Unreleased]

### Añadido (Added)
- **`PanelUtilidades`**: pestaña «Red» con diagnóstico (IP, puerta de enlace, DNS y MAC; ping al router, al DNS y a internet; resolución de nombres) que concluye dónde falla, y selector de DNS (automático, Google o Cloudflare) aplicado a los adaptadores físicos conectados.
- **`PanelUtilidades`**: gestor de impresoras instaladas en la pestaña «Impresoras» (predeterminada, página de prueba, quitar, con confirmación) y «Limpiar cola a fondo», que detiene el Spooler, borra los trabajos atascados y lo reinicia siempre, incluso si algo falla.
- **`PanelUtilidades`**: botón «Copiar informe para soporte» en Hardware (equipo, usuario, modelo, serie, SO, RAM, disco y red) al portapapeles.
- `PanelUtilidades.exe` recompilado; las tablas comparten el estilo `DataTable`.
- **`PanelUtilidades`**: pestaña «Impresoras» (recupera la función de `AsistenciaOrange`, commit `cde6fc7`). Crea el puerto TCP/IP estándar RAW 9100 con `Add-PrinterPort` y registra la impresora con `Add-Printer` usando un controlador ya instalado; prueba de socket al puerto 9100, validación del nombre y de la IP o host, y opciones de predeterminada y página de prueba. La IP viene prellenada con `192.168.8.1` (editable). Si la impresora ya existe, actualiza puerto y controlador. `PanelUtilidades.exe` recompilado.
- **`PanelUtilidades`**: pestaña «Windows Update», separada de las apps. Usa la API COM `Microsoft.Update.Session` para buscar e instalar las actualizaciones de Windows con casilla y estado por fila. Instala de a una (una que falla no corta a las demás), sin límite de tiempo, y avisa si queda un reinicio pendiente sin reiniciar. Omite las que piden licencia o interacción. Las tablas de las dos pestañas comparten estilos. `PanelUtilidades.exe` recompilado.
- **`PanelUtilidades/`**: panel nativo de Windows (PowerShell + WPF) compilado a `PanelUtilidades.exe`. Trae las 10 acciones del panel web: reinicio de Explorador, red, cola de impresión, audio y Windows Update; mantenimiento completo; hardware; búsqueda de actualizaciones con `winget`; respaldo y limpieza de perfil.

### Cambiado (Changed)
- **`PanelUtilidades`**: paleta pastel en lugar del naranja de marca. Acento lavanda `#A5B4FC` (botones, pestaña activa, selección, ícono y progreso), aviso ámbar suave, OK menta y error rosa; los botones pastel llevan texto oscuro. El tema oscuro no cambia. `PanelUtilidades.exe` recompilado.
- **`PanelUtilidades`**: pestaña Actualizaciones con casillas (marcadas de entrada) y columna de estado; «Actualizar seleccionadas» instala dentro del panel de a una app, con límite de 5 min cada una y sin cortar la serie si una falla. Al vencer el plazo se mata el árbol completo de procesos de `winget`, no solo a `winget`. Si ya hay otro `winget` corriendo, no empieza. `PanelUtilidades.exe` recompilado.
- Red: se reinician los adaptadores físicos conectados, no una interfaz llamada literalmente "Wi-Fi".
- Mantenimiento completo: un paso que falla ya no corta la secuencia.
- Limpieza de perfil: pide confirmación, usa `/XJ` (no sigue las junctions heredadas de Documentos) y excluye `desktop.ini` también en Descargas.
- "Actualizar todo" abre `ActualizarApps.exe` (con log y timeouts) en vez de un `winget upgrade --all` sin control.
- `PanelUtilidades`: el tamaño inicial se ajusta al área útil de la pantalla (antes 1080×800 fijo, más alto que una pantalla 1280×752 en DIPs). Consola plegable (un error la vuelve a desplegar), tarjetas más compactas con el ícono al lado del título y dos columnas por debajo de 880 de ancho.

- **`ActualizarApps`**: `winget source update` (2 min), `winget upgrade` y `winget list` (3 min) ya tienen límite de tiempo; antes podían colgar la ejecución sin fin. Al vencer se mata el árbol de procesos de `winget` y el script sigue (la actualización de fuentes y el chequeo de navegadores se omiten con aviso; si falla el listado de pendientes, termina con error claro). Cada paso muestra su hora en el log, para ver hasta dónde llegó una ejecución cortada. `ActualizarApps.exe` recompilado.

### Eliminado (Removed)
- Panel web (`web/`), su lanzador `Abrir-Utilidad-Web.bat` y `Limpiar-Perfil.bat`.

---

## [1.1.1] - 2026-10-10

### Corregido (Fixed)
- **`ActualizarApps`**: si ya hay otro `winget` corriendo (por ejemplo, un `winget upgrade --all` lanzado a mano), el script espera hasta 10 min a que termine antes de empezar. Correr los dos a la vez producía errores falsos: archivo en uso (`0x80070020`), timeouts y "no applicable update".
- **`ActualizarApps`**: el código `-1978335189` (`0x8A15002B`) se muestra como "sin actualización aplicable" en amarillo y ya no cuenta como fallo en el resumen.
- `ActualizarApps.exe` recompilado.

---

## [1.1.0] - 2026-10-10

### Añadido (Added)
- **`README.md`**: Guía integral del proyecto con badges de compatibilidad, descripción técnica de los módulos `ActualizarApps` e `InfoEquipo`, especificaciones de sistema, comandos de ejecución y guía de compilación con `ps2exe`.
- **Reorganización de workspace**: Traslado de `CLAUDE.md` a la raíz del proyecto para centralizar directivas de compilación y control de dependencias.

---

## [1.0.0] - 2026-10-06

### Añadido (Added)
- **`web/` (Panel Web para Navegador)**: Interfaz gráfica web moderna (HTML5/CSS3/JS) con navegación por pestañas para todos los módulos de la suite, consola terminal en vivo y servidor HTTP local autónomo en PowerShell (`server.ps1`).
- **Lanzadores Web**: `Abrir-Utilidad-Web.bat` y `utilities/Abrir-Web.bat` para iniciar el servidor y abrir el navegador en un clic.
- **`utilities/UtilidadOrangeLatam.GUI.ps1`**: Interfaz gráfica nativa de escritorio en PowerShell y WPF (XAML).
- **Terminal en Tiempo Real**: Panel de logs integrado con soporte para scroll automático, copia al portapapeles y limpieza de buffer.
- **Multihilo Asíncrono**: Ejecución no bloqueante de reinicios de servicios usando `[System.Threading.Tasks.Task]::Run` y sincronización con `Dispatcher`.
- **Lanzador Directo**: Archivo `utilities/UtilidadOrangeLatamGUI.bat` para inicio rápido con doble clic y elevación UAC automática.
- **Documentación Completa `/docs`**:
  - `01_PROJECT_PRD.md`: Requisitos de producto.
  - `02_SDD.md`: Diseño de arquitectura y sistemas.
  - `03_SYSTEM_SPEC.md`: Especificaciones técnicas y dependencias de SO.
  - `04_DATA_MODEL.md`: Estructuras y formatos de datos.
  - `05_ARCHITECTURE.md`: Diagramas y principios de diseño.
  - `06_TASKS.md`: Backlog activo y roadmap.
  - `07_DECISIONS.md`: Decisiones de arquitectura (ADRs).
  - `08_CHANGELOG.md`: Historial de versiones.
  - `CONTEXT.md`: Glosario de términos del dominio.

### Módulos Existentes Documentados
- **`ActualizarApps`**: Actualizador masivo automatizado vía `winget` y binario `ActualizarApps.exe`.
- **`InfoEquipo`**: Diagnóstico y auditoría de hardware mediante WMI/CIM.
- **`Limpiar-Perfil.bat`**: Script de respaldo selectivo con Robocopy y restablecimiento de fondo de pantalla oficial.
- **`utilities/UtilidadOrangeLatam.bat`**: Menú CLI interactivo tradicional para terminales de comandos.
