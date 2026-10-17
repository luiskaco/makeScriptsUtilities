# 06. Backlog y Tareas Activas (TASKS)

## 📌 Estado General del Proyecto
- **Versión Actual:** v1.0.0
- **Estado:** Producción / Estable

---

## 🚀 Tareas Completadas

- [x] **Creación de Interfaz Gráfica WPF/XAML para `utilities/`**
  - Implementación de la ventana moderna con tema oscuro y acentos Orange Latam.
  - Creación del componente de visualización de logs en tiempo real con scroll automático y botones de copiar/limpiar.
  - Implementación del despachador asíncrono (`[System.Threading.Tasks.Task]::Run`) para evitar bloqueos del UI.
  - Integración de los reinicios de Explorador, Red/Wi-Fi, Cola de Impresión, Audio, Windows Update y Mantenimiento General.
  - Creación de lanzador `.bat` para ejecución directa.
- [x] **Módulo de Actualización `ActualizarApps/`**
  - Automatización de `winget` con parsing estructurado de paquetes pendientes.
  - Compilación a binario ejecutable `ActualizarApps.exe` con elevación UAC incrustada.
- [x] **Módulo de Diagnóstico `InfoEquipo/`**
  - Auditoría de CPU, GPU, RAM, Discos, Red, Placa Base y SO mediante WMI/CIM.
- [x] **Script de Mantenimiento de Perfil `Limpiar-Perfil.bat`**
  - Migración con Robocopy a `Respaldo_Usuario` y restablecimiento de wallpaper por defecto.
- [x] **Panel Web para Navegador (`web/`)**
  - Implementación de interfaz web moderna (HTML5, Vanilla CSS glassmorphism, JS) con navegación por pestañas (Servicios, Info Equipo, Actualizador, Limpieza Perfil).
  - Servidor local HTTP y API REST en PowerShell (`web/server.ps1`) con auto-elevación UAC y apertura automática del navegador predeterminado.
  - Consola de logs en vivo en el navegador con terminal interactiva, auto-scroll y botones de copiar/limpiar.
  - Lanzadores directos `Abrir-Utilidad-Web.bat` y `utilities/Abrir-Web.bat`.
- [x] **Panel nativo `PanelUtilidades/` (reemplaza al panel web)**
  - Ventana WPF en PowerShell con pestañas Servicios, Hardware, Actualizaciones, Windows Update, Red, Impresoras y Limpieza de perfil, y consola de log.
  - Tareas en runspace aparte con cola sincronizada; la UI no se bloquea.
  - Compilado a `PanelUtilidades.exe` con `ps2exe -noConsole -STA -requireAdmin`.
  - Pestaña Windows Update (API COM): buscar e instalar actualizaciones del sistema desde el panel (2026-10-16).
  - Pestaña Impresoras: configurar impresora de red TCP/IP 9100, recuperada de `AsistenciaOrange` (2026-10-16).
  - Pestaña Red (diagnóstico y DNS), gestor de impresoras con limpieza de cola a fondo e informe para soporte en Hardware (2026-10-16).
  - Eliminados `web/`, `Abrir-Utilidad-Web.bat` y `Limpiar-Perfil.bat` (su lógica vive ahora en el panel).
- [x] **Estructura Completa de Documentación `/docs` y `README.md`**
  - Creación de los documentos PRD, SDD, SYSTEM SPEC, DATA MODEL, ARCHITECTURE, TASKS, DECISIONS, CHANGELOG y CONTEXT.
  - Creación de `README.md` exhaustivo con badges, arquitectura del repositorio, guía de ejecución, requisitos y procedimiento de compilación con `ps2exe`.
  - Reorganización de `CLAUDE.md` a la raíz del proyecto para reglas globales de desarrollo.

---

## 📋 Tareas Pendientes / Roadmap

- [ ] **Módulo `utilities/`:**
  - [ ] Opción en la GUI para compilar `UtilidadOrangeLatam.GUI.ps1` a `UtilidadOrangeLatam.exe` mediante `ps2exe` con un solo clic.
  - [ ] Añadir selector interactivo para reiniciar adaptadores Ethernet específicos en adición al adaptador Wi-Fi.
- [ ] **Módulo `InfoEquipo/`:**
  - [ ] Crear versión con interfaz gráfica WPF para visualizar tarjetas con gráficos de uso de recursos en tiempo real.
- [ ] **Módulo `ActualizarApps/`:**
  - [x] Interfaz gráfica con checkboxes para deseleccionar aplicaciones específicas antes de la actualización masiva. (Cubierto por "Actualizar seleccionadas" de `PanelUtilidades/`, 2026-10-16.)
  - [x] Endurecimiento: timeouts en `winget source update`, `upgrade` y `list`, y hora por paso en el log (2026-10-16).
  - [ ] Causa de los logs del 2026-10-14 y 2026-10-15 cortados en los pasos ③ y ① sin el cierre del transcript: sin determinar, esos logs no están en este equipo. Si vuelve a pasar, la hora por paso del log indicará dónde se detuvo. Hipótesis: ventana cerrada a mano en ③; `winget source update` colgado en ①.
- [ ] **Módulo `PanelUtilidades/` — sacar más partido a lo existente:**
  - [x] Pestaña Actualizaciones: casillas en la tabla y botón "Actualizar seleccionadas" que instala dentro del panel, con límite de 5 min por app (2026-10-16).
  - [ ] Pestaña Hardware: mostrar si hay driver NVIDIA más nuevo, reutilizando la consulta de `ActualizarApps`.
  - [ ] Botón "Exportar informe" que guarde a archivo el reporte completo de `InfoEquipo`.
- [ ] **Módulo `PanelUtilidades/` — mantenimiento nuevo:**
  - [ ] Limpieza de temporales (`%TEMP%`, `Windows\Temp`, caché de Windows Update y Delivery Optimization) mostrando el espacio liberado. Sin tocar la papelera.
  - [ ] Reparar Windows: `DISM /Online /Cleanup-Image /RestoreHealth` y después `sfc /scannow`, con progreso en la consola (10–20 min).
  - [ ] Crear un punto de restauración (`Checkpoint-Computer`) antes del mantenimiento completo.
  - [ ] Reset de red profundo (`netsh winsock reset` + `netsh int ip reset`), separado del botón de red actual porque exige reiniciar el equipo.
- [ ] **Módulo `PanelUtilidades/` — diagnóstico:**
  - [ ] Salud de la batería: capacidad actual frente a la de diseño (`powercfg /batteryreport`).
  - [ ] Salud del disco: temperatura, desgaste y errores con `Get-StorageReliabilityCounter`.
- [ ] **Módulo `PanelUtilidades/` — automatización:**
  - [ ] Programar `ActualizarApps` en el Programador de tareas (p. ej. domingos 22:00), activable/desactivable desde el panel.
  - [x] Guardar el log del panel a archivo en `PanelUtilidades/logs/`, como hace `ActualizarApps` (2026-10-17). Incluye detalle de winget por app y árbol de procesos al vencer el límite.
  - [ ] **Investigar el bloqueo de «Instalando…» en Edge** (reportado 2026-10-17): no se reprodujo (Edge falla en ~2 s con `0x8A15008E`, tecnología de instalación distinta). Cuando ocurra, revisar el último `PanelUtilidades/logs/panel-*.log`: el código de salida, la salida de winget y los procesos que seguían vivos dicen qué esperaba.
- [ ] **Mantenimiento del repositorio:**
  - [x] Sacados de git los 34 logs versionados (28 de `ActualizarApps/logs/` y 6 de `InfoEquipo/logs/`) con `git rm --cached` (2026-10-16); los archivos siguen en disco.
