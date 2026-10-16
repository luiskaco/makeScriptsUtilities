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
  - Ventana WPF en PowerShell con pestañas Servicios, Hardware, Actualizaciones y Limpieza de perfil, y consola de log.
  - Tareas en runspace aparte con cola sincronizada; la UI no se bloquea.
  - Compilado a `PanelUtilidades.exe` con `ps2exe -noConsole -STA -requireAdmin`.
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
  - [ ] Interfaz gráfica con checkboxes para deseleccionar aplicaciones específicas antes de la actualización masiva. (Se cubre con la tarea "Actualizar solo las seleccionadas" de `PanelUtilidades/`.)
  - [ ] Investigar por qué los logs del 2026-10-14 y 2026-10-15 quedaron cortados en los pasos ③ y ① sin el cierre del transcript (ventana cerrada a mano o `winget` colgado; `winget source update` no tiene timeout).
- [ ] **Módulo `PanelUtilidades/` — sacar más partido a lo existente:**
  - [ ] Pestaña Actualizaciones: casillas en la tabla y botón "Actualizar seleccionadas" que instale dentro del panel, con límite de tiempo por app como `ActualizarApps`.
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
  - [ ] Guardar el log del panel a archivo en `PanelUtilidades/logs/`, como hace `ActualizarApps`.
- [ ] **Mantenimiento del repositorio:**
  - [ ] Sacar de git los 28 logs de `ActualizarApps/logs/` que siguen versionados pese al `.gitignore` (`git rm --cached`).
