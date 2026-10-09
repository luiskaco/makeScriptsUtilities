# 08. Historial de Cambios (CHANGELOG)

Todas las modificaciones notables de la suite **MakeScriptsUtilities** se documentan en este archivo siguiendo las convenciones de [Keep a Changelog](https://keepachangelog.com/).

---

## [1.2.1] - 2026-10-09

### Añadido (Added)
- **Mejoras de UX y Micro-interacciones Táctiles en WPF (`AsistenciaOrange.ps1`)**:
  - Implementación de elevación y transformaciones de escala en hover (`1.02x` / `1.03x` / `1.04x`) y compresión táctil al clic (`0.96x` - `0.98x`).
  - Resplandores dinámicos con `DropShadowEffect` reactivos al ratón en botones principales y tarjetas de síntomas.
  - Telemetría de hardware rediseñada con chips de datos encapsulados e iconos temáticos (`💻 Equipo`, `👤 Usuario`, `🌐 IP`, `⚡ RAM`).
  - Tooltips contextuales explicativos en cada acción y control interactivo.
- **Configurador de Impresoras de Red (TCP/IP Puerto 9100)**:
  - Formulario interactivo en WPF para configuración de impresoras de red por IP y puerto estándar 9100 RAW.
  - Asignación de nombre personalizado, prueba de socket en vivo (`Test-PrinterPort9100`) y selección automática de controladores del sistema.
  - Creación de puerto con `Add-PrinterPort`, registro con `Add-Printer`, envío opcional de página de prueba y establecimiento como predeterminada.

### Corregido (Fixed)
- **Mapeo de Controles XAML (`AsistenciaOrange.ps1`)**:
  - Corrección de excepción por valor null al registrar eventos de botones (`$btnCloseResult`, `$btnCancelPrinter`).
  - Mapeo y validación de 54 controles XAML al 100% en la suite `auditar-codigo.ps1`.

---

## [1.2.0] - 2026-10-06

### Añadido (Added)
- **Aplicación de Escritorio Nativa (`AsistenciaOrange.ps1` y `AsistenciaOrange.bat`)**:
  - Aplicación 100% nativa en Windows con WPF / XAML, sin necesidad de servidor web local, Node.js ni navegadores.
  - Tarjeta Hero 1-Click *"Reparar Todo el Equipo"* con ejecución secuencial y barra de progreso fluida por pasos.
  - 6 Tarjetas de síntomas: Audio/Micrófono, Internet/Wi-Fi, Impresora, Pantalla/Barra, Actualizar Programas (winget) y Limpieza de Perfil (Robocopy).
  - Telemetría de hardware en tiempo real (CPU, RAM, Disco, IP, Usuario, SO).
  - Panel de Feedback y Escalamiento a Soporte TI con generación automática de diagnóstico estructurado listo para copiar en Teams o enviar por correo.
  - Consola técnica integrada colapsable con registro de logs en tiempo real, auto-scroll y botones de copiar/limpiar.
- **ADR 006**: Registro de decisión arquitectónica sobre la migración a escritorio nativo puro.

---

## [1.1.1] - 2026-10-06

### Añadido (Added)
- **Tracking de Pasos en Vivo y Streaming en Consola y Web**:
  - Consola de terminal (CMD / PowerShell / Node.js) con visualización estructurada por pasos `[Paso X/Y] (Z%)`, marcas de tiempo y colores ANSI.
  - Streaming en tiempo real mediante Server-Sent Events (SSE) en `/api/action-stream/:action` en servidores Node.js (`server.js`) y PowerShell (`server.ps1`).
  - Barra de progreso web con medidor fluido, badge de paso actual y porcentaje dinámico.
  - Consola web integrada (`terminal-output`) con streaming de logs instantáneo en tiempo real.

### Corregido (Fixed)
- **Saturación por Telemetría Cíclica:** Eliminada la invocación automática de `loadTelemetry` en el bucle de heartbeat para evitar sobrecarga de procesos PowerShell/WMI cada 3.5s.
- **Resolución de Host y Binding de Red:** Configuración de escucha dual IPv4 / IPv6 en `server.js` y prefijos dobles en `server.ps1` para garantizar conectividad transparente con `localhost` y `127.0.0.1`.
- **Lanzador `.bat`:** Optimización del flujo de elevación UAC en `Abrir-Utilidad-Web.bat` para evitar cierres prematuros de ventana.

---

## [1.1.0] - 2026-10-06

### Añadido (Added)
- **Portal de Auto-Atención y Diagnóstico para Usuarios Finales**:
  - Rediseño visual centrado en síntomas de uso cotidiano (Audio, Internet/Red, Impresora, Pantalla trabada, Actualización y Limpieza de perfil).
  - Botón Hero *"Optimizar y Reparar mi Equipo"* para auto-reparación inteligente en 1 clic.
  - Apertura en modo ventana de aplicación de escritorio (`--app` con Edge/Chrome) sin barras de navegación web.
  - Flujo interactivo de feedback: consulta *"¿Se solucionó tu problema?"* al finalizar cualquier acción.
  - Módulo de Escalamiento a Soporte TI: generación automática de reporte de diagnóstico estructurado listo para copiar en Teams o enviar por correo con 1 clic.
  - Modal de confirmación con advertencias visuales para acciones de riesgo (Limpieza y Respaldo de Perfil).
  - Panel colapsable de "Modo TI" con telemetría de hardware (CPU, RAM, Disco C:, IP) y consola terminal de logs en tiempo real.
- **ADR 005**: Registro de decisión arquitectónica sobre el nuevo paradigma de interacción por síntomas y ventana tipo app.

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
