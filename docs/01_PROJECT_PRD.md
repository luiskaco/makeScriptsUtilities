# 01. Requisitos de Producto (PRD) — Suite MakeScriptsUtilities

## 1. Resumen Ejecutivo

**MakeScriptsUtilities** (Orange Latam Utilities) es una suite de herramientas de administración, soporte técnico y mantenimiento para sistemas operativos Windows (10/11). Su propósito es automatizar y simplificar tareas operativas críticas que usualmente requieren intervención manual por línea de comandos o apertura de múltiples consolas MMC (services.msc, regedit, device manager).

---

## 2. Objetivos del Producto

- **Reducción de Tiempo de Soporte:** Disminuir en más del 80% el tiempo necesario para resolver problemas comunes de red, audio, cola de impresión y perfiles de usuario.
- **Accesibilidad y Usabilidad:** Proveer interfaces gráficas (GUI) modernas e intuitivas en adición a los scripts de consola (CLI), permitiendo que tanto técnicos como usuarios finales puedan ejecutar diagnósticos y reparaciones de forma segura.
- **Cero Dependencias Externas Pesadas:** Aprovechar el ecosistema nativo de Windows (PowerShell, WPF/XAML, WMI/CIM, Batch, Winget, Robocopy) sin necesidad de instalar runtimes adicionales como Python, Java o Node.js.
- **Portabilidad y Compilación a Binarios:** Capacidad de compilar herramientas clave en ejecutables `.exe` independientes y auto-elevados con `ps2exe`.

---

## 3. Módulos y Requisitos Funcionales

### 3.1. Módulo `utilities/` (Gestor y Reinicio de Servicios)
- **GUI Moderna (WPF/XAML):** Interfaz oscura con paleta Orange Latam (`#13141F`, `#FF7A00`), diseño adaptativo y botones con feedback visual.
- **Consola Integrada:** Visualizador de terminal en tiempo real con scroll automático, marcas de tiempo, etiquetas de severidad (`[INFO]`, `[OK]`, `[ERROR]`) y opciones de copiado/limpieza.
- **Ejecución Asíncrona (Multihilo):** Las acciones corren en tareas de fondo (`Task::Run`) sin bloquear ni congelar la ventana.
- **Acciones Disponibles:**
  1. *Explorador de Windows:* Finalización y recarga de `explorer.exe`.
  2. *Red y Wi-Fi:* Reinicio de interfaz Wi-Fi, vaciado de caché DNS (`ipconfig /flushdns`) y renovación DHCP (`ipconfig /renew`).
  3. *Cola de Impresión:* Reinicio limpio del servicio `Spooler`.
  4. *Servicios de Audio:* Parada y reinicio coordinado de `AudioEndpointBuilder` y `Audiosrv`.
  5. *Windows Update:* Reinicio del servicio de actualización `wuauserv`.
  6. *Mantenimiento General:* Ejecución encadenada de todos los procedimientos de mantenimiento en un solo clic.
- **Versión CLI (`.bat`):** Menú interactivo tradicional de consola para terminales sin soporte gráfico o sesiones remotas.

### 3.2. Módulo `ActualizarApps/` (Actualizador Masivo de Software)
- **Detección Automatizada:** Ejecuta `winget upgrade --include-unknown` y procesa la tabla para listar paquetes con actualizaciones pendientes.
- **Actualización Selectiva o Total:** Permite actualizar todas las aplicaciones o filtrar por software crítico.
- **Sistema de Logs:** Registro detallado con marcas de tiempo en la carpeta `logs/`.
- **Binario `.exe`:** Compilado con `ps2exe` y solicitud nativa de permisos de Administrador vía manifiesto UAC (`-requireAdmin`).

### 3.3. Módulo `InfoEquipo/` (Auditoría e Información de Hardware/SO)
- **Telemetría Completa vía WMI/CIM:**
  - *Procesador (CPU):* Nombre, núcleos físicos/lógicos, arquitectura y carga.
  - *Memoria RAM:* Capacidad total instalada, slots ocupados y memoria libre.
  - *Almacenamiento:* Discos físicos, particiones, sistema de archivos y espacio libre.
  - *Adaptadores Gráficos (GPU):* Fabricante, modelo, memoria VRAM y resolución activa.
  - *Red:* Direcciones IPv4, MAC, adaptador activo y estado de conexión.
  - *Sistema Operativo & Placa Base:* Versión, compilación (Build), número de serie y fabricante.
- **Generación de Reportes:** Salida formateada en consola y exportación a archivos de log.

### 3.4. Script Raíz `Limpiar-Perfil.bat` (Restablecimiento de Perfil de Usuario)
- **Respaldo Seguro:** Mueve el contenido de `Escritorio`, `Descargas` y `Documentos` a `%USERPROFILE%\Desktop\Respaldo_Usuario` utilizando `robocopy /E /MOVE`.
- **Exclusiones de Seguridad:** Protege `desktop.ini` y la propia carpeta de respaldo para evitar recursiones.
- **Restablecimiento Visual:** Restaura el fondo de pantalla por defecto de Windows modificando el Registro (`HKCU\Control Panel\Desktop`) y refrescando el shell mediante `user32.dll!UpdatePerUserSystemParameters`.

---

## 4. Requisitos No Funcionales

| Requisito | Criterio |
|-----------|----------|
| **Compatibilidad** | Windows 10 (1809+) y Windows 11 en arquitecturas x64 y ARM64. |
| **Seguridad / Privilegios** | Verificación y auto-elevación UAC (Administrador) en todas las herramientas que tocan servicios o registros. |
| **Rendimiento** | Tiempo de arranque de la GUI menor a 1.2 segundos; consumo de RAM inferior a 45 MB. |
| **Resiliencia** | Manejo de excepciones en cada acción para evitar que fallas en un servicio interrumpan el flujo general. |
