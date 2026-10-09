# 06. Backlog y Tareas Activas (TASKS)

## 📌 Estado General del Proyecto
- **Versión Actual:** v1.1.0-dev
- **Estado:** En desarrollo (Feature: Portal de Auto-Atención para Usuarios)

---

## ⏳ En Progreso (In Progress)

*(No hay tareas activas en desarrollo)*

---

## 🚀 Tareas Completadas

- [x] **Fix: Resolución de Excepción Null en Mapeo XAML (`AsistenciaOrange.ps1`)**
  - Corrección de mapeo de `$btnCloseResult` que faltaba declarar en `FindName`.
  - Inclusión del control `btnCancelPrinter` en el XAML y mapeo correspondiente.
  - Auditoría de 54 controles XAML validada al 100% en `auditar-codigo.ps1`.
- [x] **Configurador e Instalador de Impresoras de Red (TCP/IP Port 9100)**
  - Panel interactivo con formulario: Nombre personalizado de impresora, IP de red, Selector dinámico de controladores de Windows.
  - Test de conectividad a socket TCP IP:9100 antes de instalación.
  - Creación automática de `Add-PrinterPort` (puerto estándar 9100 RAW) y `Add-Printer`.
  - Opción de página de prueba y establecimiento como predeterminada.
- [x] **Compilación de Ejecutables Nativos Windows (`.exe`)**
  - Generación de binario standalone `AsistenciaOrange.exe` (subsystem `WinExe` sin ventana CMD de fondo, UAC integrado, modo STA para WPF).
  - Generación de binario standalone `utilities/UtilidadOrangeLatam.exe` para administradores TI.
  - Creación del script y lanzador maestro `compilar-binarios.ps1` y `compilar-binarios.bat`.
- [x] **Portal de Auto-Atención Nativo de Escritorio (WPF / XAML)**
  - Construcción de aplicación 100% nativa en Windows (`AsistenciaOrange.ps1`, `AsistenciaOrange.bat` y `AsistenciaOrange.exe`).
  - Eliminación de dependencias de servidores HTTP, puertos locales de red y navegadores web.
  - Soporte de tarjeta 1-Click Auto-Fix, 6 tarjetas de síntomas, telemetría WMI, barra de progreso nativa en tiempo real y consola integrada.
  - Flujo de feedback posterior y generación automática de reporte para Soporte TI (Copiar, Correo, Teams).
- [x] **Fix: Estabilidad de Conexión y Optimización de Telemetría**
  - Corrección de saturación por peticiones repetitivas de telemetría WMI (`loadTelemetry`).
  - Binding dual IPv4 / IPv6 para compatibilidad total con navegadores en `http://localhost:5050` y `http://127.0.0.1:5050`.
  - Simplificación y robustecimiento de elevación UAC en `Abrir-Utilidad-Web.bat`.
- [x] **Visualización de Progreso en Tiempo Real y Tracking de Pasos en Consola y Web**
  - Consola de terminal (CMD / PowerShell / Node.js) con tracking detallado de pasos `[Paso X/Y] (Z%)`, timestamps y colores ANSI.
  - Endpoint de Server-Sent Events (SSE) `/api/action-stream/:action` en servidores Node.js (`server.js`) y PowerShell (`server.ps1`).
  - Barra de progreso interactiva en la interfaz web con porcentaje, indicador de paso actual y barra de llenado fluida.
  - Consola web integrada (`terminal-output`) con streaming de logs en vivo en tiempo real.
- [x] **Portal de Auto-Atención y Diagnóstico para Usuarios Finales (UI/UX)**
  - Rediseño completo de la interfaz hacia un enfoque de síntomas cotidianos (Audio, Red/Teams, Impresión, Pantalla/Congelamiento, Actualizaciones).
  - Implementación del botón Hero *"Optimizar y Reparar mi Equipo"* (1-Click Auto-Fix).
  - Apertura en modo ventana de escritorio nativa (`--app` sin barras de navegación).
  - Flujo de feedback posterior a la acción: *"¿Se solucionó tu problema?"* con generación automática de *"Copiar reporte para Soporte IT"*.
  - Modales de confirmación con salvaguardas para acciones críticas (Restablecimiento de perfil).
  - Vista colapsable de telemetría y consola técnica para personal de soporte.
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
- [x] **Estructura Completa de Documentación `/docs`**
  - Creación de los documentos PRD, SDD, SYSTEM SPEC, DATA MODEL, ARCHITECTURE, TASKS, DECISIONS, CHANGELOG y CONTEXT.

---

## 📋 Tareas Pendientes / Roadmap

- [ ] **Módulo `utilities/`:**
  - [ ] Añadir selector interactivo para reiniciar adaptadores Ethernet específicos en adición al adaptador Wi-Fi.
- [ ] **Módulo `InfoEquipo/`:**
  - [ ] Crear versión con interfaz gráfica WPF para visualizar tarjetas con gráficos de uso de recursos en tiempo real.
- [ ] **Módulo `ActualizarApps/`:**
  - [ ] Interfaz gráfica con checkboxes para deseleccionar aplicaciones específicas antes de la actualización masiva.
