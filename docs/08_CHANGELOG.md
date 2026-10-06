# 08. Historial de Cambios (CHANGELOG)

Todas las modificaciones notables de la suite **MakeScriptsUtilities** se documentan en este archivo siguiendo las convenciones de [Keep a Changelog](https://keepachangelog.com/).

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
