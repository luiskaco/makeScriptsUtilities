# 07. Registro de Decisiones de Arquitectura (ADRs)

## ADR 001: Elección de PowerShell + WPF (XAML) sobre Windows Forms y Runtimes Externos
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** Se requería una interfaz gráfica para la suite de utilidades de servicios de Windows que fuera moderna, responsiva, atractiva visualmente y fácil de desplegar.
- **Decisión:** Utilizar PowerShell con WPF (XAML) en lugar de Windows Forms tradicional o frameworks externos (como Electron o Python CustomTkinter).
- **Consecuencias:**
  - *Positivas:* Interfaz moderna con temas oscuros, esquinas redondeadas y controles enriquecidos sin necesidad de instalar runtimes de terceros. Compatibilidad nativa con Windows 10 y 11.
  - *Negativas:* Requiere inicializar el hilo en modo STA (`[ApartmentState]::STA`) y manejar la sincronización entre hilos mediante `Dispatcher.Invoke()`.

---

## ADR 002: Ejecución Asíncrona de Tareas de Sistema en la GUI
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** Operaciones como `ipconfig /renew`, timeouts de adaptadores Wi-Fi y reinicios de servicios pueden demorar entre 2 y 10 segundos. Si se ejecutan en el hilo de la UI, la ventana entra en estado "No responde".
- **Decisión:** Encapsular todas las acciones de reinicio en tareas asíncronas (`[System.Threading.Tasks.Task]::Run`) y notificar a la interfaz a través de la cola del Dispatcher.
- **Consecuencias:** La ventana mantiene su animación, interactividad y permite al usuario cancelar, minimizar o ver logs en vivo sin bloqueos.

---

## ADR 003: Compilación con `ps2exe` y Manifiesto UAC `-requireAdmin`
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** Los usuarios y técnicos a menudo ejecutan scripts haciendo doble clic, lo que puede provocar fallos silenciosos si no se inician con privilegios elevados.
- **Decisión:** Utilizar `ps2exe` con el flag `-requireAdmin` para generar binarios `.exe` que disparan el diálogo UAC de Windows de forma nativa antes de iniciar.
- **Consecuencias:** Se garantiza que todas las llamadas a `winget`, `netsh` y `net stop/start` cuenten con los privilegios necesarios desde el arranque.

---

## ADR 004: Uso de Robocopy en `Limpiar-Perfil.bat`
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** El comando `move` estándar de cmd falla al mover directorios bloqueados, árboles profundos o archivos de sistema como `desktop.ini`.
- **Decisión:** Utilizar `robocopy /E /MOVE /XF "desktop.ini" /XD "Respaldo_Usuario" /R:1 /W:1`.
- **Consecuencias:** Migración robusta, tolerante a reintentos rápidos y sin errores por recursión de carpetas.

---

## ADR 005: Paradigma de Interfaz Orientada a Síntomas y Ventana de Aplicación de Escritorio
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** La interfaz técnica original exponía nombres de servicios de Windows (`Spooler`, `wuauserv`, `AudioEndpointBuilder`) y tablas crudas pensadas para administradores, lo que generaba fricción y confusión en usuarios de oficina sin conocimientos informáticos.
- **Decisión:** 
  1. Rediseñar la UI hacia un catálogo de síntomas cotidianos ("No me escuchan", "Sin internet o Teams", "Impresora atascada") y un botón central de "Auto-Reparación en 1 Clic".
  2. Lanzar la interfaz en modo aplicación de escritorio nativa (`--app` con Edge/Chrome o WebView2) para eliminar pestañas y barras de navegación.
  3. Incorporar un flujo de feedback con botón automático para generar y copiar el diagnóstico formateado para soporte IT ante cualquier fallo.
- **Consecuencias:** Mayor adopción, resolución autónoma en <2 clics y recepción de reportes estandarizados por parte de Soporte IT sin que el usuario tenga que redactar logs técnicos.

---

## ADR 006: Migración de Servidor Web Local a Aplicación Nativa de Escritorio WPF / XAML
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** La implementación previa basada en un servidor local HTTP (`Node.js` / `server.ps1`) y navegador web presentaba puntos de fallo externos: puertos de red bloqueados u ocupados (5050/5051), cierre accidental de la ventana de consola del servidor, discrepancias de resolución IPv4/IPv6 (`localhost` vs `127.0.0.1`), y errores de `Failed to fetch`.
- **Decisión:** Implementar la suite completa de Auto-Atención y Diagnóstico como una **aplicación nativa de escritorio pura en Windows (WPF/XAML en PowerShell/STA)** (`AsistenciaOrange.ps1` y `AsistenciaOrange.bat`), eliminando intermediarios HTTP, puertos y dependencias de navegador.
- **Consecuencias:**
  - *Positivas:* 100% de fiabilidad, ejecución en memoria directa mediante hilos asíncronos (`Task.Run`), cero errores de red o puertos, inicio directo con doble clic, elevación UAC limpia y visualización de progreso en tiempo real fluida.
  - *Negativas:* No se puede acceder desde otros dispositivos en la red (diseñado exclusivamente para uso local en la máquina cliente).

