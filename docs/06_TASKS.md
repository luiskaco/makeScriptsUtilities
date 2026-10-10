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
  - [ ] Interfaz gráfica con checkboxes para deseleccionar aplicaciones específicas antes de la actualización masiva.
