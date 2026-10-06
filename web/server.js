/**
 * ORANGE LATAM — Servidor Web Local Autónomo (Node.js)
 * Cero dependencias externas. Usa únicamente módulos nativos (http, fs, path, child_process).
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');

const PORT = 5050;
const WEB_DIR = __dirname;
const ROOT_DIR = path.resolve(__dirname, '..');

// Helper para ejecutar comandos de PowerShell con Promise
function runPowershell(command) {
  return new Promise((resolve) => {
    // Encapsular en comando powershell seguro
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

// Servir archivos estáticos
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon'
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
    // Comprobar privilegios de administrador
    const adminCheck = await runPowershell('([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)');
    const isAdmin = adminCheck.stdout.toLowerCase().includes('true');

    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      isAdmin,
      hostName: os.hostname(),
      platform: os.platform(),
      release: os.release(),
      port: PORT,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // --- 2. API: ACCIONES ---
  if (pathname.startsWith('/api/action/') && req.method === 'POST') {
    const action = pathname.replace('/api/action/', '');
    const logs = [];
    let success = true;
    let errorMsg = null;
    let extraData = {};

    console.log(`[${new Date().toLocaleTimeString()}] Ejecutando acción: ${action}`);

    try {
      switch (action) {
        // 1. Explorador de Windows
        case 'explorer': {
          logs.push({ msg: 'Cerrando proceso explorer.exe...', type: 'INFO' });
          await runPowershell('Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue');
          await new Promise(r => setTimeout(r, 800));
          logs.push({ msg: 'Iniciando nuevo proceso explorer.exe...', type: 'INFO' });
          await runPowershell('Start-Process explorer.exe');
          logs.push({ msg: 'Explorador de Windows reiniciado correctamente.', type: 'OK' });
          break;
        }

        // 2. Red y Wi-Fi
        case 'wifi': {
          logs.push({ msg: 'Deshabilitando interfaz Wi-Fi...', type: 'INFO' });
          await runPowershell('netsh interface set interface name="Wi-Fi" admin=disable');
          await new Promise(r => setTimeout(r, 2000));

          logs.push({ msg: 'Habilitando interfaz Wi-Fi...', type: 'INFO' });
          await runPowershell('netsh interface set interface name="Wi-Fi" admin=enable');

          logs.push({ msg: 'Vaciando caché DNS (ipconfig /flushdns)...', type: 'INFO' });
          await runPowershell('ipconfig /flushdns');
          await new Promise(r => setTimeout(r, 2500));

          logs.push({ msg: 'Renovando concesión IP (ipconfig /renew)...', type: 'INFO' });
          await runPowershell('ipconfig /renew');

          logs.push({ msg: 'Conectividad y resolución de red restablecidas con éxito.', type: 'OK' });
          break;
        }

        // 3. Spooler
        case 'spooler': {
          logs.push({ msg: 'Deteniendo servicio Spooler de impresión...', type: 'INFO' });
          await runPowershell('net stop Spooler');
          await new Promise(r => setTimeout(r, 500));
          logs.push({ msg: 'Iniciando servicio Spooler...', type: 'INFO' });
          await runPowershell('net start Spooler');
          logs.push({ msg: 'Cola de impresión reiniciada con éxito.', type: 'OK' });
          break;
        }

        // 4. Audio
        case 'audio': {
          logs.push({ msg: 'Deteniendo servicios de audio (Audiosrv & AudioEndpointBuilder)...', type: 'INFO' });
          await runPowershell('net stop Audiosrv /y; net stop AudioEndpointBuilder /y');
          await new Promise(r => setTimeout(r, 500));
          logs.push({ msg: 'Iniciando AudioEndpointBuilder y Audiosrv...', type: 'INFO' });
          await runPowershell('net start AudioEndpointBuilder; net start Audiosrv');
          logs.push({ msg: 'Servicios de audio reiniciados con éxito.', type: 'OK' });
          break;
        }

        // 5. Windows Update
        case 'update': {
          logs.push({ msg: 'Deteniendo servicio de Windows Update (wuauserv)...', type: 'INFO' });
          await runPowershell('net stop wuauserv');
          await new Promise(r => setTimeout(r, 500));
          logs.push({ msg: 'Iniciando servicio Windows Update...', type: 'INFO' });
          await runPowershell('net start wuauserv');
          logs.push({ msg: 'Servicio de Windows Update reiniciado correctamente.', type: 'OK' });
          break;
        }

        // 6. Mantenimiento Completo
        case 'all': {
          logs.push({ msg: '=== INICIANDO SECUENCIA COMPLETA DE MANTENIMIENTO ===', type: 'INFO' });

          logs.push({ msg: '[1/5] Reiniciando Spooler de Impresión...', type: 'INFO' });
          await runPowershell('net stop Spooler; net start Spooler');

          logs.push({ msg: '[2/5] Reiniciando Servicios de Audio...', type: 'INFO' });
          await runPowershell('net stop Audiosrv /y; net stop AudioEndpointBuilder /y; net start AudioEndpointBuilder; net start Audiosrv');

          logs.push({ msg: '[3/5] Reiniciando Windows Update...', type: 'INFO' });
          await runPowershell('net stop wuauserv; net start wuauserv');

          logs.push({ msg: '[4/5] Reiniciando interfaz de red y vaciando DNS...', type: 'INFO' });
          await runPowershell('netsh interface set interface name="Wi-Fi" admin=disable');
          await new Promise(r => setTimeout(r, 1500));
          await runPowershell('netsh interface set interface name="Wi-Fi" admin=enable; ipconfig /flushdns');
          await new Promise(r => setTimeout(r, 2000));
          await runPowershell('ipconfig /renew');

          logs.push({ msg: '[5/5] Reiniciando Explorador de Windows...', type: 'INFO' });
          await runPowershell('Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue');
          await new Promise(r => setTimeout(r, 800));
          await runPowershell('Start-Process explorer.exe');

          logs.push({ msg: '=== MANTENIMIENTO COMPLETO FINALIZADO CON ÉXITO ===', type: 'OK' });
          break;
        }

        // 7. Info de Hardware
        case 'info': {
          logs.push({ msg: 'Consultando telemetría de hardware (WMI/CIM)...', type: 'INFO' });
          const cmd = `
            $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
            $os = Get-CimInstance Win32_OperatingSystem
            $ramTotal = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
            $disk = Get-CimInstance Win32_DiskDrive | Select-Object -First 1
            $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

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
            } | ConvertTo-Json -Compress
          `;

          const result = await runPowershell(cmd);
          if (result.stdout) {
            try {
              const data = JSON.parse(result.stdout);
              extraData.info = {
                cpu: { name: data.cpuName, cores: data.cpuCores, threads: data.cpuThreads },
                ram: { total: data.ramTotal, free: data.ramFree },
                disk: { model: data.diskModel, free: data.diskFree },
                os: { caption: data.osCaption, build: data.osBuild }
              };
              logs.push({ msg: `CPU detectado: ${data.cpuName}`, type: 'OK' });
              logs.push({ msg: `Memoria RAM total: ${data.ramTotal} | SO: ${data.osCaption}`, type: 'OK' });
            } catch (e) {
              logs.push({ msg: `Error parseando info: ${e.message}`, type: 'WARN' });
            }
          }
          break;
        }

        // 8. Limpiar Perfil
        case 'clean-profile': {
          logs.push({ msg: 'Iniciando respaldo y limpieza con Robocopy...', type: 'INFO' });
          const scriptPath = path.join(ROOT_DIR, 'Limpiar-Perfil.bat');
          if (fs.existsSync(scriptPath)) {
            const res = await runPowershell(`cmd /c "${scriptPath}"`);
            logs.push({ msg: 'Respaldo completado en %USERPROFILE%\\Desktop\\Respaldo_Usuario', type: 'OK' });
            logs.push({ msg: 'Fondo de pantalla predeterminado restablecido.', type: 'OK' });
          } else {
            logs.push({ msg: 'No se encontró Limpiar-Perfil.bat', type: 'ERROR' });
            success = false;
          }
          break;
        }

        // 9. Comprobar Actualizaciones
        case 'check-upgrades': {
          logs.push({ msg: 'Ejecutando winget upgrade para escanear paquetes...', type: 'INFO' });
          const res = await runPowershell('winget upgrade');
          if (res.stdout) {
            res.stdout.split(/\r?\n/).forEach(line => {
              if (line.trim()) logs.push({ msg: line, type: 'INFO' });
            });
          }
          logs.push({ msg: 'Comprobación de paquetes finalizada.', type: 'OK' });
          break;
        }

        // 10. Actualizar Software
        case 'upgrade-apps': {
          logs.push({ msg: 'Iniciando actualización de aplicaciones vía winget...', type: 'INFO' });
          const res = await runPowershell('winget upgrade --all --silent --accept-source-agreements --accept-package-agreements');
          logs.push({ msg: 'Proceso de actualización winget finalizado.', type: 'OK' });
          break;
        }

        default:
          logs.push({ msg: `Acción no reconocida: ${action}`, type: 'ERROR' });
          success = false;
          errorMsg = 'Acción inválida';
      }
    } catch (err) {
      success = false;
      errorMsg = err.message;
      logs.push({ msg: `Error: ${err.message}`, type: 'ERROR' });
    }

    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      success,
      error: errorMsg,
      logs,
      ...extraData
    }));
    return;
  }

  // --- 3. ARCHIVOS ESTÁTICOS ---
  let filePath = pathname === '/' ? path.join(WEB_DIR, 'index.html') : path.join(WEB_DIR, pathname);
  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'text/plain';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        // Fallback a index.html
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

server.listen(PORT, '127.0.0.1', () => {
  const url = `http://localhost:${PORT}`;
  console.log('\n============================================================');
  console.log('     ORANGE LATAM • PANEL WEB DE CONTROL WINDOWS');
  console.log('============================================================');
  console.log(`[✓] Servidor web activo en: ${url}`);
  console.log('[*] Abriendo navegador predeterminado automáticamente...');
  console.log('============================================================\n');

  // Abrir navegador en Windows
  exec(`start ${url}`);
});
