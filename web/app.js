/* ==========================================================================
   ORANGE LATAM — WEB DASHBOARD LOGIC (app.js)
   Handles UI interactions, API calls to local server, and live log updates.
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  // DOM Elements
  const tabButtons = document.querySelectorAll('.tab-btn');
  const tabPanes = document.querySelectorAll('.tab-pane');
  const terminalOutput = document.getElementById('terminal-output');
  const btnClearTerminal = document.getElementById('btn-clear-terminal');
  const btnCopyTerminal = document.getElementById('btn-copy-terminal');
  const chkAutoscroll = document.getElementById('chk-autoscroll');
  const termPulseDot = document.getElementById('term-pulse-dot');
  const termStatusText = document.getElementById('term-status-text');
  const adminStatusText = document.getElementById('admin-status-text');
  const hostText = document.getElementById('host-text');

  // Service Action Buttons
  const serviceButtons = document.querySelectorAll('.btn-service');
  const btnActionAll = document.getElementById('btn-action-all');
  const btnRefreshHardware = document.getElementById('btn-refresh-hardware');
  const btnCheckUpgrades = document.getElementById('btn-check-upgrades');
  const btnUpgradeAll = document.getElementById('btn-upgrade-all');
  const btnRunCleaner = document.getElementById('btn-run-cleaner');

  // 1. Tab Navigation
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset.tab;
      
      tabButtons.forEach(b => b.classList.remove('active'));
      tabPanes.forEach(p => p.classList.remove('active'));

      btn.classList.add('active');
      const targetPane = document.getElementById(targetId);
      if (targetPane) {
        targetPane.classList.add('active');
      }

      // If hardware tab activated and not scanned, trigger scan
      if (targetId === 'tab-hardware' && document.getElementById('hw-cpu-name').textContent.includes('Escanear')) {
        fetchHardwareInfo();
      }
    });
  });

  // 2. Logging Utility
  function appendLog(message, type = 'INFO') {
    const timeStr = new Date().toLocaleTimeString('es-ES', { hour12: false });
    const line = document.createElement('div');
    line.className = `terminal-line line-${type.toLowerCase()}`;

    let tagClass = 'tag-info';
    let tagText = '[INFO]';

    switch (type.toUpperCase()) {
      case 'OK':
      case 'SUCCESS':
        tagClass = 'tag-ok';
        tagText = '[✓ OK]';
        break;
      case 'WARN':
      case 'WARNING':
        tagClass = 'tag-warn';
        tagText = '[! ADVERTENCIA]';
        break;
      case 'ERR':
      case 'ERROR':
        tagClass = 'tag-err';
        tagText = '[✕ ERROR]';
        break;
      default:
        tagClass = 'tag-info';
        tagText = '[i INFO]';
    }

    line.innerHTML = `
      <span class="log-time">[${timeStr}]</span>
      <span class="log-tag ${tagClass}">${tagText}</span>
      <span class="log-msg">${escapeHtml(message)}</span>
    `;

    terminalOutput.appendChild(line);

    if (chkAutoscroll.checked) {
      terminalOutput.scrollTop = terminalOutput.scrollHeight;
    }
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // 3. Status indicator helper
  function setExecutionStatus(isBusy, message = 'Listo para operar') {
    if (isBusy) {
      termPulseDot.className = 'term-pulse-dot busy';
      termStatusText.textContent = message;
      document.querySelectorAll('.btn').forEach(btn => btn.disabled = true);
    } else {
      termPulseDot.className = 'term-pulse-dot';
      termStatusText.textContent = message;
      document.querySelectorAll('.btn').forEach(btn => btn.disabled = false);
    }
  }

  // 4. Generic API Action Invoker
  async function invokeAction(endpoint, actionName) {
    setExecutionStatus(true, `Ejecutando: ${actionName}...`);
    appendLog(`Iniciando acción: ${actionName}`, 'INFO');

    try {
      const response = await fetch(`/api/action/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });

      if (!response.ok) {
        throw new Error(`Servidor respondió con código ${response.status}`);
      }

      const data = await response.json();

      if (data.logs && Array.isArray(data.logs)) {
        data.logs.forEach(log => appendLog(log.msg, log.type || 'INFO'));
      }

      if (data.success) {
        appendLog(`Acción '${actionName}' finalizada con éxito.`, 'SUCCESS');
        setExecutionStatus(false, `Listo — ${actionName} completado.`);
      } else {
        appendLog(`Acción falló: ${data.error || 'Error desconocido'}`, 'ERROR');
        setExecutionStatus(false, `Error en ${actionName}`);
      }

      return data;
    } catch (err) {
      appendLog(`Error de conexión o ejecución: ${err.message}`, 'ERROR');
      setExecutionStatus(false, `Error en ${actionName}`);
    }
  }

  // 5. Wire up service buttons
  serviceButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.dataset.action;
      const title = btn.closest('.service-card').querySelector('.card-title').textContent;
      invokeAction(action, title);
    });
  });

  if (btnActionAll) {
    btnActionAll.addEventListener('click', () => {
      invokeAction('all', 'Mantenimiento General de Servicios');
    });
  }

  // 6. Hardware info loader
  async function fetchHardwareInfo() {
    setExecutionStatus(true, 'Escaneando hardware del equipo...');
    appendLog('Consultando métricas de hardware mediante WMI/CIM...', 'INFO');

    try {
      const response = await fetch('/api/action/info', { method: 'POST' });
      const data = await response.json();

      if (data.success && data.info) {
        const info = data.info;
        
        // CPU
        if (info.cpu) {
          document.getElementById('hw-cpu-name').textContent = info.cpu.name || '-';
          document.getElementById('hw-cpu-cores').textContent = `${info.cpu.cores} Núcleos / ${info.cpu.threads} Hilos`;
        }

        // RAM
        if (info.ram) {
          document.getElementById('hw-ram-total').textContent = info.ram.total || '-';
          document.getElementById('hw-ram-free').textContent = info.ram.free || '-';
        }

        // Disk
        if (info.disk) {
          document.getElementById('hw-disk-model').textContent = info.disk.model || '-';
          document.getElementById('hw-disk-free').textContent = info.disk.free || '-';
        }

        // OS
        if (info.os) {
          document.getElementById('hw-os-caption').textContent = info.os.caption || '-';
          document.getElementById('hw-os-build').textContent = info.os.build || '-';
        }

        appendLog('Auditoría de hardware actualizada correctamente.', 'SUCCESS');
        setExecutionStatus(false, 'Listo — Auditoría de hardware completada.');
      } else {
        appendLog('No se pudieron obtener todos los datos de hardware.', 'WARN');
        setExecutionStatus(false, 'Listo');
      }
    } catch (err) {
      appendLog(`Error al consultar hardware: ${err.message}`, 'ERROR');
      setExecutionStatus(false, 'Error en escaneo de hardware');
    }
  }

  if (btnRefreshHardware) {
    btnRefreshHardware.addEventListener('click', fetchHardwareInfo);
  }

  // 7. Updater & Cleaner Actions
  if (btnCheckUpgrades) {
    btnCheckUpgrades.addEventListener('click', () => {
      invokeAction('check-upgrades', 'Comprobación de Actualizaciones Winget');
    });
  }

  if (btnUpgradeAll) {
    btnUpgradeAll.addEventListener('click', () => {
      invokeAction('upgrade-apps', 'Actualización Masiva de Software');
    });
  }

  if (btnRunCleaner) {
    btnRunCleaner.addEventListener('click', () => {
      if (confirm('¿Deseas respaldar y limpiar el Escritorio, Descargas y Documentos hacia Respaldo_Usuario?')) {
        invokeAction('clean-profile', 'Limpieza y Respaldo de Perfil');
      }
    });
  }

  // 8. Terminal Controls
  btnClearTerminal.addEventListener('click', () => {
    terminalOutput.innerHTML = '';
    appendLog('Consola limpiada por el usuario.', 'INFO');
  });

  btnCopyTerminal.addEventListener('click', () => {
    const text = terminalOutput.innerText;
    navigator.clipboard.writeText(text).then(() => {
      appendLog('Logs copiados al portapapeles del sistema.', 'SUCCESS');
    }).catch(() => {
      appendLog('No se pudo acceder al portapapeles.', 'ERROR');
    });
  });

  // 9. Initial Handshake & System Status
  async function checkInitialStatus() {
    try {
      const res = await fetch('/api/status');
      if (res.ok) {
        const status = await res.json();
        if (status.isAdmin) {
          adminStatusText.textContent = 'Administrador Activo';
        } else {
          adminStatusText.textContent = 'Permisos Limitados';
          document.getElementById('admin-status-pill').className = 'status-pill';
        }
        if (status.hostName) {
          hostText.textContent = status.hostName;
        }
        appendLog(`Conectado al servidor local en ${status.hostName || 'Windows'} (UAC: ${status.isAdmin ? 'Admin' : 'Normal'})`, 'SUCCESS');
      }
    } catch (e) {
      appendLog('Servidor local respondiendo en modo estándar.', 'INFO');
    }
  }

  checkInitialStatus();
});
