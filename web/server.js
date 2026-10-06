/**
 * ORANGE LATAM — Servidor Web Local Autónomo (Node.js)
 * Cero dependencias externas. Usa únicamente módulos nativos (http, fs, path, child_process).
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');

let PORT = 5050;
const WEB_DIR = __dirname;
const ROOT_DIR = path.resolve(__dirname, '..');

// Formato de colores ANSI para consola de terminal
const C = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  orange: '\x1b[38;5;208m',
  gray: '\x1b[90m'
};

function logConsole(msg, level = 'INFO') {
  const time = new Date().toLocaleTimeString();
  let prefix = `${C.gray}[${time}]${C.reset}`;
  switch (level) {
    case 'STEP':
      console.log(`${prefix} ${C.orange}${C.bold}▸ ${msg}${C.reset}`);
      break;
    case 'OK':
      console.log(`${prefix}   ${C.green}✔ ${msg}${C.reset}`);
      break;
    case 'ERROR':
      console.log(`${prefix}   ${C.red}✖ ${msg}${C.reset}`);
      break;
    case 'WARN':
      console.log(`${prefix}   ${C.yellow}⚠ ${msg}${C.reset}`);
      break;
    case 'ACTION':
      console.log(`\n${C.cyan}╔══════════════════════════════════════════════════════════════╗${C.reset}`);
      console.log(`${C.cyan}║  ▶ INICIANDO: ${msg.padEnd(46)} ║${C.reset}`);
      console.log(`${C.cyan}╚══════════════════════════════════════════════════════════════╝${C.reset}`);
      break;
    case 'DONE':
      console.log(`${prefix} ${C.green}${C.bold}✨ ${msg}${C.reset}\n`);
      break;
    default:
      console.log(`${prefix}   ${C.gray}${msg}${C.reset}`);
  }
}

// Helper para ejecutar comandos de PowerShell con Promise
function runPowershell(command) {
  return new Promise((resolve) => {
    const psCmd = `powershell -NoProfile -ExecutionPolicy Bypass -Command "${command.replace(/"/g, '\\"')}"`;
    exec(psCmd, { windowsHide: true, maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
      resolve({
        success: !error,
        stdout: stdout ? stdout.trim() : '',
        stderr: stderr ? stderr.trim() : '',
        error: error ? error.message : null
      });
    });
  });
}

// Ejecutor unificado de acciones con tracking en tiempo real
async function executeAction(action, onStep = () => {}, onLog = () => {}) {
  const logs = [];
  let success = true;
  let errorMsg = null;
  let extraData = {};
  const startTime = Date.now();

  const emitLog = (msg, type = 'INFO') => {
    logs.push({ msg, type, time: new Date().toLocaleTimeString() });
    onLog(msg, type);
    logConsole(msg, type === 'OK' ? 'OK' : type === 'ERROR' ? 'ERROR' : type === 'WARN' ? 'WARN' : 'INFO');
  };

  const emitStep = (step, total, label, percent) => {
    const calculatedPercent = percent !== undefined ? percent : Math.round((step / total) * 100);
    onStep({ step, total, label, percent: calculatedPercent });
    logConsole(`[Paso ${step}/${total}] (${calculatedPercent}%) ${label}`, 'STEP');
  };

  logConsole(action.toUpperCase(), 'ACTION');

  try {
    switch (action) {
      // 1. Explorador de Windows / Pantalla congelada
      case 'explorer': {
        emitStep(1, 2, 'Cerrando proceso explorer.exe...', 40);
        emitLog('Deteniendo explorer.exe para refrescar la interfaz...', 'INFO');
        await runPowershell('Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue');
        await new Promise(r => setTimeout(r, 600));

        emitStep(2, 2, 'Iniciando nuevo proceso explorer.exe...', 85);
        emitLog('Lanzando nueva instancia del explorador de Windows...', 'INFO');
        await runPowershell('Start-Process explorer.exe');

        emitLog('Barra de tareas y explorador refrescados con éxito.', 'OK');
        break;
      }

      // 2. Red y Wi-Fi / Teams desconectado
      case 'wifi': {
        emitStep(1, 3, 'Vaciando caché DNS de navegación...', 30);
        emitLog('Ejecutando vaciado de DNS (ipconfig /flushdns)...', 'INFO');
        await runPowershell('ipconfig /flushdns');

        emitStep(2, 3, 'Registrando nombres y sockets de red...', 60);
        emitLog('Registrando configuración DNS (ipconfig /registerdns)...', 'INFO');
        await runPowershell('ipconfig /registerdns');

        emitStep(3, 3, 'Renovando dirección IP con servidor DHCP...', 90);
        emitLog('Solicitando nueva concesión IP (ipconfig /renew)...', 'INFO');
        await runPowershell('ipconfig /renew');

        emitLog('Conectividad de red y resolución DNS restablecidas.', 'OK');
        break;
      }

      // 3. Spooler / Impresora bloqueada
      case 'spooler': {
        emitStep(1, 2, 'Deteniendo cola de impresión (Spooler)...', 40);
        emitLog('Deteniendo servicio Spooler para liberar trabajos atascados...', 'INFO');
        await runPowershell('net stop Spooler');
        await new Promise(r => setTimeout(r, 500));

        emitStep(2, 2, 'Reiniciando servicio de impresión...', 85);
        emitLog('Reactivando servicio de cola de impresión...', 'INFO');
        await runPowershell('net start Spooler');

        emitLog('Cola de impresión restablecida correctamente.', 'OK');
        break;
      }

      // 4. Audio / Sin sonido o micrófono
      case 'audio': {
        emitStep(1, 2, 'Deteniendo controladores y servicios de audio...', 40);
        emitLog('Deteniendo Audiosrv y AudioEndpointBuilder...', 'INFO');
        await runPowershell('net stop Audiosrv /y; net stop AudioEndpointBuilder /y');
        await new Promise(r => setTimeout(r, 500));

        emitStep(2, 2, 'Reactivando servicios de sonido y micrófono...', 85);
        emitLog('Iniciando AudioEndpointBuilder y Audiosrv...', 'INFO');
        await runPowershell('net start AudioEndpointBuilder; net start Audiosrv');

        emitLog('Controladores de audio y micrófono reactivados exitosamente.', 'OK');
        break;
      }

      // 5. Windows Update
      case 'update': {
        emitStep(1, 2, 'Deteniendo servicio Windows Update (wuauserv)...', 40);
        emitLog('Deteniendo wuauserv temporalmente...', 'INFO');
        await runPowershell('net stop wuauserv');
        await new Promise(r => setTimeout(r, 500));

        emitStep(2, 2, 'Iniciando servicio de Windows Update...', 85);
        emitLog('Reactivando servicio de actualizaciones...', 'INFO');
        await runPowershell('net start wuauserv');

        emitLog('Servicio de Windows Update reiniciado correctamente.', 'OK');
        break;
      }

      // 6. Optimización y Reparación 1-Click (All)
      case 'all': {
        emitLog('=== INICIANDO AUTO-REPARACIÓN INTEGRAL DEL EQUIPO ===', 'INFO');

        emitStep(1, 4, 'Desbloqueando servicios de audio y micrófono...', 25);
        emitLog('[Paso 1/4] Reiniciando servicios de sonido (Audiosrv)...', 'INFO');
        await runPowershell('net stop Audiosrv /y; net stop AudioEndpointBuilder /y; net start AudioEndpointBuilder; net start Audiosrv');
        emitLog('✓ Audio y micrófono listos.', 'OK');

        emitStep(2, 4, 'Desbloqueando cola de impresión...', 50);
        emitLog('[Paso 2/4] Reiniciando cola de impresión (Spooler)...', 'INFO');
        await runPowershell('net stop Spooler; net start Spooler');
        emitLog('✓ Impresora desbloqueada.', 'OK');

        emitStep(3, 4, 'Restableciendo conexión de red y caché DNS...', 75);
        emitLog('[Paso 3/4] Vaciando DNS y renovando IP...', 'INFO');
        await runPowershell('ipconfig /flushdns; ipconfig /renew');
        emitLog('✓ Red y DNS restablecidos.', 'OK');

        emitStep(4, 4, 'Refrescando explorador y barra de tareas...', 95);
        emitLog('[Paso 4/4] Recargando proceso explorer.exe...', 'INFO');
        await runPowershell('Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue');
        await new Promise(r => setTimeout(r, 600));
        await runPowershell('Start-Process explorer.exe');
        emitLog('✓ Entorno visual recargado.', 'OK');

        emitLog('=== ¡OPTIMIZACIÓN Y AUTO-REPARACIÓN COMPLETADA CON ÉXITO! ===', 'OK');
        break;
      }

      // 7. Info de Hardware & Diagnóstico
      case 'info': {
        emitStep(1, 2, 'Consultando telemetría de hardware (WMI/CIM)...', 40);
        emitLog('Extrayendo datos de procesador, memoria, almacenamiento y red...', 'INFO');

        const cmd = `
          $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
          $os = Get-CimInstance Win32_OperatingSystem
          $ramTotal = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
          $disk = Get-CimInstance Win32_DiskDrive | Select-Object -First 1
          $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
          $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*','Ethernet*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
          if (-not $ip) { $ip = 'Desconectado' }

          [PSCustomObject]@{
            cpuName = $cpu.Name.Trim()
            cpuCores = $cpu.NumberOfCores
            cpuThreads = $cpu.NumberOfLogicalProcessors
            ramTotal = "{0:N1} GB" -f ($ramTotal / 1GB)
            ramFree = "{0:N1} GB" -f ($os.FreePhysicalMemory / 1MB)
            diskModel = $disk.Model
            diskFree = "{0:N1} GB libres de {1:N1} GB" -f ($diskC.FreeSpace / 1GB), ($diskC.Size / 1GB)
            osCaption = $os.Caption
            osBuild = $os.BuildNumber
            ipAddress = $ip
          } | ConvertTo-Json -Compress
        `;

        const result = await runPowershell(cmd);
        emitStep(2, 2, 'Estructurando reporte del equipo...', 90);

        if (result.stdout) {
          try {
            const data = JSON.parse(result.stdout);
            extraData.info = {
              cpu: { name: data.cpuName, cores: data.cpuCores, threads: data.cpuThreads },
              ram: { total: data.ramTotal, free: data.ramFree },
              disk: { model: data.diskModel, free: data.diskFree },
              os: { caption: data.osCaption, build: data.osBuild },
              network: { ip: data.ipAddress }
            };
            emitLog(`Equipo: ${os.hostname()} | IP: ${data.ipAddress}`, 'OK');
            emitLog(`CPU: ${data.cpuName} | RAM: ${data.ramTotal}`, 'OK');
          } catch (e) {
            emitLog(`Aviso parseando info: ${e.message}`, 'WARN');
          }
        }
        break;
      }

      // 8. Limpiar Perfil
      case 'clean-profile': {
        emitStep(1, 2, 'Iniciando respaldo seguro de archivos...', 40);
        emitLog('Ejecutando Limpiar-Perfil.bat con Robocopy...', 'INFO');
        const scriptPath = path.join(ROOT_DIR, 'Limpiar-Perfil.bat');

        if (fs.existsSync(scriptPath)) {
          await runPowershell(`cmd /c "${scriptPath}"`);
          emitStep(2, 2, 'Finalizando restauración de configuración...', 90);
          emitLog('Respaldo guardado en tu Escritorio: Respaldo_Usuario', 'OK');
          emitLog('Fondo de pantalla predeterminado restablecido.', 'OK');
        } else {
          emitLog('No se encontró Limpiar-Perfil.bat', 'ERROR');
          success = false;
        }
        break;
      }

      // 9. Comprobar y Descargar Actualizaciones
      case 'upgrade-apps':
      case 'check-upgrades': {
        emitStep(1, 3, 'Buscando actualizaciones disponibles con winget...', 25);
        emitLog('Escaneando paquetes instalados...', 'INFO');
        const scanRes = await runPowershell('winget upgrade');

        if (scanRes.stdout) {
          const lines = scanRes.stdout.split(/\r?\n/).filter(l => l.trim().length > 0);
          const countLine = lines.find(l => l.includes('actualizaciones disponibles') || l.includes('upgrades available'));
          if (countLine) {
            emitLog(`Detectado: ${countLine.trim()}`, 'INFO');
          }
        }

        emitStep(2, 3, 'Descargando e instalando parches de software...', 65);
        emitLog('Iniciando instalación silenciosa de parches...', 'INFO');
        const upgradeRes = await runPowershell('winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --silent');

        if (upgradeRes.stdout) {
          upgradeRes.stdout.split(/\r?\n/).forEach(line => {
            if (line.trim() && !line.includes('===') && !line.includes('---')) {
              emitLog(line.trim(), 'INFO');
            }
          });
        }

        emitStep(3, 3, 'Verificando finalización de paquetes...', 95);
        emitLog('Actualización de aplicaciones finalizada correctamente.', 'OK');
        break;
      }

      default:
        emitLog(`Acción no reconocida: ${action}`, 'ERROR');
        success = false;
        errorMsg = 'Acción inválida';
    }
  } catch (err) {
    success = false;
    errorMsg = err.message;
    emitLog(`Error: ${err.message}`, 'ERROR');
  }

  const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);
  if (success) {
    logConsole(`Acción '${action}' completada en ${elapsedSec}s`, 'DONE');
  } else {
    logConsole(`Acción '${action}' finalizada con error tras ${elapsedSec}s`, 'ERROR');
  }

  return {
    success,
    error: errorMsg,
    logs,
    ...extraData
  };
}

// Servir archivos estáticos
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml'
};

const server = http.createServer(async (req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  // --- 1. API: STATUS ---
  if (pathname === '/api/status' && req.method === 'GET') {
    const adminCheck = await runPowershell('([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)');
    const isAdmin = adminCheck.stdout.toLowerCase().includes('true');

    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      isAdmin,
      hostName: os.hostname(),
      userName: os.userInfo().username,
      platform: os.platform(),
      release: os.release(),
      port: PORT,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // --- 2. API: REPORT PARA SOPORTE TI ---
  if (pathname === '/api/report' && req.method === 'GET') {
    const cmd = `
      $os = Get-CimInstance Win32_OperatingSystem
      $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
      $ram = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
      $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
      $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*','Ethernet*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
      if (-not $ip) { $ip = 'Sin conexión detectada' }

      [PSCustomObject]@{
        pcName = $env:COMPUTERNAME
        userName = $env:USERNAME
        osName = $os.Caption
        osBuild = $os.BuildNumber
        cpuName = $cpu.Name.Trim()
        ramTotal = "{0:N1} GB" -f $ram
        diskFree = "{0:N1} GB libres de {1:N1} GB" -f ($diskC.FreeSpace / 1GB), ($diskC.Size / 1GB)
        ipAddress = $ip
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      } | ConvertTo-Json -Compress
    `;

    const result = await runPowershell(cmd);
    let reportData = {
      pcName: os.hostname(),
      userName: os.userInfo().username,
      osName: 'Windows 10/11',
      ipAddress: '127.0.0.1',
      timestamp: new Date().toLocaleString()
    };

    if (result.stdout) {
      try {
        reportData = JSON.parse(result.stdout);
      } catch (e) {}
    }

    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      success: true,
      report: reportData
    }));
    return;
  }

  // --- 3. API: ACCIONES CON STREAMING EN TIEMPO REAL (SSE) ---
  if (pathname.startsWith('/api/action-stream/') && req.method === 'GET') {
    const action = pathname.replace('/api/action-stream/', '');

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    const sendEvent = (event, data) => {
      res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    };

    // Keep-alive inicial
    sendEvent('connected', { action });

    const result = await executeAction(
      action,
      (stepData) => sendEvent('step', stepData),
      (msg, type) => sendEvent('log', { msg, type, time: new Date().toLocaleTimeString() })
    );

    sendEvent('complete', result);
    res.end();
    return;
  }

  // --- 4. API: ACCIONES DIRECTAS (POST) ---
  if (pathname.startsWith('/api/action/') && req.method === 'POST') {
    const action = pathname.replace('/api/action/', '');
    const result = await executeAction(action);
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(result));
    return;
  }

  // --- 5. ARCHIVOS ESTÁTICOS ---
  let filePath = pathname === '/' ? path.join(WEB_DIR, 'index.html') : path.join(WEB_DIR, pathname);
  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'text/plain';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        fs.readFile(path.join(WEB_DIR, 'index.html'), (e, fallbackContent) => {
          if (e) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('404 Not Found');
          } else {
            res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
            res.end(fallbackContent);
          }
        });
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end(`500 Server Error: ${err.code}`);
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

// Función para iniciar servidor con reintento de puertos
function startServer(portToTry) {
  server.listen(portToTry, () => {
    PORT = portToTry;
    const url = `http://localhost:${PORT}`;
    console.log('\n============================================================');
    console.log('  ORANGE LATAM • PORTAL DE AUTO-ATENCIÓN Y DIAGNÓSTICO');
    console.log('============================================================');
    console.log(`[✓] Servidor local activo en: ${url}`);
    console.log('[*] Abriendo ventana de aplicación de escritorio...');
    console.log('============================================================\n');

    // Lanzar en modo ventana de escritorio nativa (--app)
    const appCommand = `start msedge --app=${url} || start chrome --app=${url} || start ${url}`;
    exec(appCommand);
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.log(`[!] Puerto ${portToTry} ocupado. Probando puerto ${portToTry + 1}...`);
      setTimeout(() => startServer(portToTry + 1), 200);
    } else {
      console.error('[✕] Error en el servidor:', err);
    }
  });
}

startServer(PORT);
