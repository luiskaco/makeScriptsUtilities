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

## ADR 005: Panel nativo WPF en lugar del panel web
- **Fecha:** 2026-10-15
- **Estado:** Aceptado (reemplaza al panel `web/`)
- **Contexto:** El panel web necesitaba Node.js (o un servidor HTTP en PowerShell de respaldo), un puerto local (5050) y un navegador abierto. Se pidió una versión nativa de Windows y eliminar la web.
- **Alternativas evaluadas:**
  - *C# WPF/WinForms con .NET:* exige el SDK para compilar y un proyecto aparte; rompe con el resto de la suite.
  - *PowerShell + WPF compilado con `ps2exe`:* mismo stack y misma forma de distribución que `ActualizarApps.exe`; no requiere instalar nada.
- **Decisión:** PowerShell + WPF (`PanelUtilidades/PanelUtilidades.ps1`), compilado con `ps2exe -noConsole -STA -requireAdmin`. Las tareas corren en un runspace aparte y se comunican con la UI mediante una `ConcurrentQueue` que vacía un `DispatcherTimer`.
- **Consecuencias:**
  - *Positivas:* un solo `.exe`, sin Node, sin puerto abierto ni navegador. Los comandos externos corren sin ventana (`CreateNoWindow`).
  - *Negativas:* con `-noConsole`, cualquier salida al pipeline del script se muestra como MessageBox, así que hay que suprimirla con `[void]`. Tras cada cambio del `.ps1` hay que recompilar el `.exe`.

---

## ADR 004: Uso de Robocopy en `Limpiar-Perfil.bat`
- **Fecha:** 2026-10-06
- **Estado:** Aceptado
- **Contexto:** El comando `move` estándar de cmd falla al mover directorios bloqueados, árboles profundos o archivos de sistema como `desktop.ini`.
- **Decisión:** Utilizar `robocopy /E /MOVE /XF "desktop.ini" /XD "Respaldo_Usuario" /R:1 /W:1`.
- **Consecuencias:** Migración robusta, tolerante a reintentos rápidos y sin errores por recursión de carpetas.
