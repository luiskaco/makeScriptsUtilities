# MakeScriptsUtilities

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![Shell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?logo=powershell)](https://learn.microsoft.com/powershell/)
[![PackageManager](https://img.shields.io/badge/Winget-Supported-0078D4)](https://learn.microsoft.com/windows/package-manager/winget/)
[![Architecture](https://img.shields.io/badge/Architecture-x64%20%7C%20ARM64-lightgrey)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#)

Suite de automatización y herramientas de soporte técnico para sistemas operativos Windows. Diseñada para operar sin dependencias pesadas de terceros, utilizando exclusivamente APIs nativas de Windows, **PowerShell**, **WMI/CIM** y **Winget**.

---

## 📋 Contenido

- [Características Principales](#-características-principales)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Módulos](#-módulos)
  - [1. ActualizarApps](#1-actualizarapps)
  - [2. InfoEquipo](#2-infoequipo)
- [Requisitos del Sistema](#-requisitos-del-sistema)
- [Instrucciones de Uso](#-instrucciones-de-uso)
- [Compilación a Ejecutable (.exe)](#-compilación-a-ejecutable-exe)
- [Documentación Técnica](#-documentación-técnica)
- [Buenas Prácticas y Reglas](#-buenas-prácticas-y-reglas)

---

## ✨ Características Principales

- **Cero dependencias externas:** Funciona en cualquier instalación moderna de Windows con PowerShell nativo.
- **Auditoría profunda de hardware:** Inspección de CPU, GPU, RAM, discos, red, BIOS y batería en segundos.
- **Actualización inteligente de software:** Integra `winget` resolviendo discrepancias de catálogo (paquetes localizados en español, navegadores, arquitectura) y consulta de drivers NVIDIA.
- **Ejecutables auto-elevados:** Módulos compilados a binarios `.exe` con solicitud automática de privilegios UAC vía manifiesto.
- **Trazabilidad completa:** Generación automática de reportes y logs detallados con marcas de tiempo en carpetas dedicadas `logs/`.

---

## 📁 Estructura del Proyecto

```text
makeScriptsUtilities/
├── ActualizarApps/              # Módulo de actualización masiva de software
│   ├── ActualizarApps.exe       # Binario compilado con auto-elevación UAC
│   ├── updateScripts.ps1        # Script fuente en PowerShell
│   └── logs/                    # Historial de actualizaciones ejecutadas
├── InfoEquipo/                  # Módulo de diagnóstico y auditoría de hardware
│   ├── InfoEquipo.bat           # Lanzador rápido de un clic (Bypass Policy)
│   ├── InfoEquipo.ps1           # Script PowerShell WMI / CIM
│   └── logs/                    # Reportes generados del sistema
├── docs/                        # Documentación de diseño y arquitectura
│   ├── 01_PROJECT_PRD.md        # Requisitos del producto
│   ├── 02_SDD.md                # Diseño del sistema
│   ├── 03_SYSTEM_SPEC.md        # Especificaciones técnicas
│   ├── 04_DATA_MODEL.md         # Modelo de datos y estructuras WMI
│   ├── 05_ARCHITECTURE.md       # Arquitectura y principios técnicos
│   ├── 06_TASKS.md              # Backlog y seguimiento de tareas
│   ├── 07_DECISIONS.md          # Registro de decisiones de arquitectura (ADRs)
│   ├── 08_CHANGELOG.md          # Historial de cambios
│   └── CONTEXT.md               # Contexto general y glosario
├── .gitignore                   # Exclusiones de Git (logs, temporales)
├── CLAUDE.md                    # Instrucciones y reglas de compilación de binarios
└── README.md                    # Este documento
```

---

## 🛠️ Módulos

### 1. ActualizarApps

Automatiza la detección y actualización de todas las aplicaciones instaladas mediante **Windows Package Manager (`winget`)**.

#### Capacidades:
- **Detección estructurada:** Ejecuta `winget upgrade --include-unknown` y procesa la salida para identificar identificadores reales (`Id`), versiones instaladas y disponibles.
- **Gestión de paquetes localizados:** Resuelve discrepancias frecuentes en aplicaciones multiidioma (como Mozilla Firefox es-ES/es-AR, Google Chrome, Brave, Opera), enlazando directamente con su ID oficial en el catálogo comunitario.
- **Manejo de excepciones:** Notifica de forma clara sobre incompatibilidades de tecnología de instalación (por ejemplo, el caso conocido de Microsoft Edge MSI vs EXE) evitando falsos errores.
- **Auditoría de GPU NVIDIA:** Consulta de forma transparente la API oficial de NVIDIA para verificar si el controlador gráfico instalado se encuentra al día.
- **Logs detallados:** Registra el progreso, errores y tiempos de ejecución en `ActualizarApps/logs/actualizacion_YYYYMMDD_HHMMSS.log`.

---

### 2. InfoEquipo

Herramienta de diagnóstico rápido que genera un reporte exhaustivo del hardware y software de la máquina utilizando consultas **CIM / WMI** optimizadas.

#### Métricas auditadas:
- **Procesador (CPU):** Fabricante, modelo exacto, arquitectura, cantidad de núcleos físicos y procesadores lógicos.
- **Memoria RAM:** Capacidad total, desglose por ranuras/módulos físicos (tamaño, fabricante, velocidad en MHz) y memoria libre disponible.
- **Almacenamiento:** Discos físicos instalados, modelo, interfaz, particiones, letras de unidad, espacio total y porcentaje libre.
- **Gráficos (GPU):** Modelo de tarjeta de video, memoria VRAM dedicada, resolución actual de pantalla y tasa de refresco.
- **Conectividad de Red:** Adaptadores físicos y virtuales activos (Ethernet / Wi-Fi), direcciones IPv4 y IPv6, dirección física (MAC) y velocidad de enlace.
- **Placa Base & Firmware:** Fabricante, modelo de placa, número de serie, versión y fecha de BIOS/UEFI.
- **Sistema Operativo:** Nombre de edición, versión de Windows, compilación (Build), arquitectura y tiempo de actividad del sistema (*uptime*).
- **Monitores y Energía:** Detección de pantallas conectadas y telemetría de batería en equipos portátiles.

---

## 💻 Requisitos del Sistema

| Componente | Requisito Mínimo | Recomendado |
|---|---|---|
| **Sistema Operativo** | Windows 10 (Build 1809 o superior) | Windows 11 (22H2 o superior) |
| **Arquitectura** | x64 o ARM64 | x64 |
| **PowerShell** | Windows PowerShell 5.1 | PowerShell 7+ |
| **Package Manager** | Windows Package Manager (`winget`) | Versión más reciente de Winget |
| **Permisos** | Usuario estándar (con opción a elevar) | Administrador local |

---

## 🚀 Instrucciones de Uso

### Clonar el repositorio

```powershell
git clone https://github.com/luiskaco/makeScriptsUtilities.git
cd makeScriptsUtilities
```

### Ejecutar ActualizarApps

- **Vía ejecutable (Recomendado):**  
  Hacer doble clic en `ActualizarApps\ActualizarApps.exe`. La aplicación solicitará automáticamente elevación UAC y comenzará el análisis y actualización.
- **Vía PowerShell:**
  ```powershell
  # Abrir terminal con permisos de Administrador
  powershell -ExecutionPolicy Bypass -File "D:\Script\ActualizarApps\updateScripts.ps1"
  ```

### Ejecutar InfoEquipo

- **Vía lanzador rápido:**  
  Hacer doble clic en `InfoEquipo\InfoEquipo.bat`. Se abrirá una terminal con el informe formateado a colores.
- **Vía PowerShell:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "D:\Script\InfoEquipo\InfoEquipo.ps1"
  ```

---

## ⚙️ Compilación a Ejecutable (.exe)

El binario `ActualizarApps.exe` se genera a partir de `updateScripts.ps1` usando el módulo `ps2exe` con el flag `-requireAdmin`. Esto garantiza que Windows solicite los privilegios necesarios antes de iniciar la ejecución.

Si realizas modificaciones en `ActualizarApps\updateScripts.ps1`, debes recompilar el ejecutable siguiendo el procedimiento documentado en [`CLAUDE.md`](file:///d:/Script/CLAUDE.md):

```powershell
# 1. Instalar módulo si no está presente
Install-Module -Name ps2exe -Scope CurrentUser

# 2. Compilar con manifiesto de elevación UAC
Import-Module ps2exe
Invoke-ps2exe -inputFile "D:\Script\ActualizarApps\updateScripts.ps1" `
  -outputFile "D:\Script\ActualizarApps\ActualizarApps.exe" `
  -requireAdmin `
  -title "Actualizador de Aplicaciones" `
  -description "Actualiza todas las aplicaciones instaladas via winget" `
  -company "luiskaco" `
  -version "1.0.0.0"
```

> [!IMPORTANT]
> El flag `-requireAdmin` es obligatorio. Sin este parámetro en el manifiesto, `winget` fallará al procesar paquetes que requieran permisos de Administrador.

---

## 📚 Documentación Técnica

La carpeta [`docs/`](file:///d:/Script/docs/) contiene el detalle técnico, arquitectónico y operacional de la suite:

- [PRD - Requisitos de Producto](file:///d:/Script/docs/01_PROJECT_PRD.md)
- [SDD - Diseño de Sistema](file:///d:/Script/docs/02_SDD.md)
- [System Spec - Especificación Técnica](file:///d:/Script/docs/03_SYSTEM_SPEC.md)
- [Data Model - Estructuras de Datos](file:///d:/Script/docs/04_DATA_MODEL.md)
- [Architecture - Principios de Diseño](file:///d:/Script/docs/05_ARCHITECTURE.md)
- [Tasks - Backlog y Roadmap](file:///d:/Script/docs/06_TASKS.md)
- [ADRs - Decisiones de Arquitectura](file:///d:/Script/docs/07_DECISIONS.md)
- [Changelog - Historial de Versiones](file:///d:/Script/docs/08_CHANGELOG.md)

---

## 🔒 Licencia

Distribuido bajo la Licencia MIT. Consulta los archivos de cabecera o documentación interna para más detalles.
