/* ==========================================================================
   ASISTENCIA ORANGE — CONTROLADOR DE USUARIO (app.js)
   Tracking en tiempo real de pasos, logs, auto-reconexión y detección de servidor.
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  let apiBase = window.location.origin.startsWith('http') ? window.location.origin : 'http://localhost:5050';
  let isConnected = false;

  // DOM Elements
  const statusIndicator = document.getElementById('status-indicator');
  const statusLabel = document.getElementById('status-label');

  const btnActionAll = document.getElementById('btn-action-all');
  const actionTiles = document.querySelectorAll('.action-tile');

  const globalProgress = document.getElementById('global-progress');
  const progressName = document.getElementById('progress-name');
  const progressStep = document.getElementById('progress-step');
  const progressStepBadge = document.getElementById('progress-step-badge');
  const progressPercent = document.getElementById('progress-percent');
  const progressBarFill = document.getElementById('progress-bar-fill');

  const resultBanner = document.getElementById('result-banner');
  const resultTitle = document.getElementById('result-title');
  const resultDesc = document.getElementById('result-desc');
  const resultActions = document.getElementById('result-actions');
  const resultThanks = document.getElementById('result-thanks');
  const btnFeedbackYes = document.getElementById('btn-feedback-yes');
  const btnFeedbackNo = document.getElementById('btn-feedback-no');
  const btnCloseBanner = document.getElementById('btn-close-banner');

  const supportCard = document.getElementById('support-card');
  const supportReportText = document.getElementById('support-report-text');
  const btnCopySupport = document.getElementById('btn-copy-support');
  const copySupportText = document.getElementById('copy-support-text');
  const btnMailSupport = document.getElementById('btn-mail-support');
  const btnTeamsSupport = document.getElementById('btn-teams-support');

  const cleanerModal = document.getElementById('cleaner-modal');
  const btnOpenCleaner = document.getElementById('btn-open-cleaner-modal');
  const btnModalBack = document.getElementById('btn-modal-back');
  const btnModalOk = document.getElementById('btn-modal-ok');

  const btnToggleAdvanced = document.getElementById('btn-toggle-advanced');
  const advancedPanel = document.getElementById('advanced-panel');
  const terminalOutput = document.getElementById('terminal-output');
  const btnClearTerminal = document.getElementById('btn-clear-terminal');

  const hwPcName = document.getElementById('hw-pc-name');
  const hwUserName = document.getElementById('hw-user-name');
  const hwIp = document.getElementById('hw-ip');
  const hwRam = document.getElementById('hw-ram');

  let isRunning = false;
  let lastActionTitle = '';
  let activeEventSource = null;

  // ==========================================================================
  // 1. INICIALIZAR Y AUTO-DETECTAR SERVIDOR LOCAL (Detección de puertos y reconexión)
  // ==========================================================================
  const candidateUrls = [
    apiBase,
    'http://localhost:5050',
    'http://127.0.0.1:5050',
    'http://localhost:5051',
    'http://127.0.0.1:5051'
  ];

  async function tryConnect(url) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 1500);
      const res = await fetch(`${url}/api/status`, { signal: controller.signal });
      clearTimeout(timeoutId);
      if (res.ok) {
        const data = await res.json();
        return { ok: true, data, url };
      }
    } catch (e) {}
    return { ok: false };
  }

  async function checkHealth() {
    let connected = false;

    // Probar candidatos hasta encontrar el servidor activo
    for (const url of candidateUrls) {
      const res = await tryConnect(url);
      if (res.ok) {
        apiBase = res.url;
        connected = true;
        if (!isConnected) {
          logEvent(`Conectado al servidor local en ${apiBase} (Equipo: ${res.data.hostName || 'PC'})`, 'ok');
        }
        isConnected = true;
        statusIndicator.className = 'status-indicator online';
        statusLabel.textContent = 'En línea';
        if (hwPcName) hwPcName.textContent = res.data.hostName || 'PC';
        if (hwUserName) hwUserName.textContent = res.data.userName || 'Usuario';
        break;
      }
    }

    if (!connected) {
      if (isConnected) {
        statusIndicator.className = 'status-indicator offline';
        statusLabel.textContent = 'Sin conexión';
        logEvent('Se perdió la conexión con el servidor local. Reintentando...', 'err');
      } else {
        statusIndicator.className = 'status-indicator offline';
        statusLabel.textContent = 'Sin conexión';
      }
      isConnected = false;
    }
  }

  // Polling automático cada 3 segundos si está desconectado o cada 10s si está conectado
  setInterval(() => {
    checkHealth();
  }, 3500);

  async function loadTelemetry() {
    if (!isConnected) return;
    try {
      const res = await fetch(`${apiBase}/api/action/info`, { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        if (data.info) {
          if (hwIp && data.info.network) hwIp.textContent = data.info.network.ip || '-';
          if (hwRam && data.info.ram) hwRam.textContent = data.info.ram.total || '-';
        }
      }
    } catch (e) {}
  }

  // ==========================================================================
  // 2. EJECUCIÓN DE ACCIONES CON STREAMING EN TIEMPO REAL
  // ==========================================================================
  function runAction(actionKey, actionTitle, element = null) {
    if (isRunning) return;

    if (!isConnected) {
      logEvent(`✕ No se puede ejecutar '${actionTitle}': Servidor local desconectado.`, 'err');
      logEvent(`💡 Inicia el servidor ejecutando el archivo 'Abrir-Utilidad-Web.bat' como Administrador.`, 'warn');
      showResult(false, actionTitle, 'El servidor local no está iniciado. Ejecuta el archivo "Abrir-Utilidad-Web.bat" en la carpeta principal como Administrador para habilitar las reparaciones.');
      return;
    }

    isRunning = true;
    lastActionTitle = actionTitle;

    // Ocultar resultados previos
    resultBanner.classList.add('hidden');
    supportCard.classList.add('hidden');

    // Inicializar barra de progreso
    if (progressName) progressName.textContent = actionTitle;
    if (progressStepBadge) progressStepBadge.textContent = 'Iniciando...';
    if (progressStep) progressStep.textContent = 'Preparando entorno de Windows...';
    if (progressPercent) progressPercent.textContent = '5%';
    if (progressBarFill) progressBarFill.style.width = '5%';

    globalProgress.classList.remove('hidden');
    globalProgress.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

    if (element) element.classList.add('is-running');
    logEvent(`▶ Solicitando: ${actionTitle}...`, 'info');

    // Conexión vía Server-Sent Events (SSE) para progreso y logs en tiempo real
    try {
      if (activeEventSource) {
        activeEventSource.close();
      }

      const streamUrl = `${apiBase}/api/action-stream/${actionKey}`;
      activeEventSource = new EventSource(streamUrl);

      activeEventSource.addEventListener('connected', () => {
        logEvent(`Conexión de telemetría en vivo establecida.`, 'info');
      });

      activeEventSource.addEventListener('step', (e) => {
        try {
          const stepData = JSON.parse(e.data);
          if (progressStepBadge) progressStepBadge.textContent = `Paso ${stepData.step} de ${stepData.total}`;
          if (progressStep) progressStep.textContent = stepData.label;
          if (progressPercent) progressPercent.textContent = `${stepData.percent}%`;
          if (progressBarFill) progressBarFill.style.width = `${stepData.percent}%`;
        } catch (err) {}
      });

      activeEventSource.addEventListener('log', (e) => {
        try {
          const logData = JSON.parse(e.data);
          const typeClass = logData.type === 'OK' ? 'ok' : logData.type === 'ERROR' ? 'err' : logData.type === 'WARN' ? 'warn' : 'info';
          logEvent(logData.msg, typeClass);
        } catch (err) {}
      });

      activeEventSource.addEventListener('complete', (e) => {
        activeEventSource.close();
        activeEventSource = null;

        try {
          const resData = JSON.parse(e.data);
          if (progressBarFill) progressBarFill.style.width = '100%';
          if (progressPercent) progressPercent.textContent = '100%';
          if (progressStep) progressStep.textContent = '¡Completado con éxito!';

          setTimeout(() => {
            globalProgress.classList.add('hidden');
            if (resData.success) {
              logEvent(`✓ ${actionTitle} finalizado exitosamente.`, 'ok');
              showResult(true, actionTitle);
            } else {
              logEvent(`✕ Fallo en ${actionTitle}: ${resData.error || 'Error'}`, 'err');
              showResult(false, actionTitle, resData.error);
            }
            isRunning = false;
            if (element) element.classList.remove('is-running');
          }, 350);
        } catch (err) {
          globalProgress.classList.add('hidden');
          showResult(true, actionTitle);
          isRunning = false;
          if (element) element.classList.remove('is-running');
        }
      });

      activeEventSource.onerror = (err) => {
        // Fallback a POST tradicional si SSE se interrumpe
        if (activeEventSource) {
          activeEventSource.close();
          activeEventSource = null;
        }
        fallbackRunAction(actionKey, actionTitle, element);
      };

    } catch (e) {
      fallbackRunAction(actionKey, actionTitle, element);
    }
  }

  // Fallback tradicional vía POST si falla EventSource
  async function fallbackRunAction(actionKey, actionTitle, element) {
    try {
      const res = await fetch(`${apiBase}/api/action/${actionKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });

      const data = await res.json();

      if (data.logs && Array.isArray(data.logs)) {
        data.logs.forEach(l => logEvent(l.msg, l.type === 'OK' ? 'ok' : l.type === 'ERROR' ? 'err' : 'info'));
      }

      if (progressBarFill) progressBarFill.style.width = '100%';
      if (progressPercent) progressPercent.textContent = '100%';

      setTimeout(() => {
        globalProgress.classList.add('hidden');
        if (data.success) {
          logEvent(`✓ ${actionTitle} finalizado.`, 'ok');
          showResult(true, actionTitle);
        } else {
          logEvent(`✕ Fallo en ${actionTitle}: ${data.error || 'Error'}`, 'err');
          showResult(false, actionTitle, data.error);
        }
        isRunning = false;
        if (element) element.classList.remove('is-running');
      }, 300);

    } catch (err) {
      globalProgress.classList.add('hidden');
      logEvent(`✕ Error de comunicación: ${err.message}`, 'err');
      showResult(false, actionTitle, err.message);
      isRunning = false;
      if (element) element.classList.remove('is-running');
    }
  }

  // ==========================================================================
  // 3. MOSTRAR RESULTADO Y SOPORTE
  // ==========================================================================
  function showResult(success, title, errorMsg = null) {
    resultBanner.classList.remove('hidden');
    resultActions.classList.remove('hidden');
    resultThanks.classList.add('hidden');

    if (success) {
      resultTitle.textContent = '¡Listo! Tarea completada.';
      resultDesc.textContent = `Hemos finalizado la reparación de: ${title}.`;
    } else {
      resultTitle.textContent = 'Requirió atención adicional.';
      resultDesc.textContent = errorMsg ? `Detalle: ${errorMsg}` : 'Es posible que se requiera soporte técnico.';
      openSupport();
    }

    resultBanner.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  async function openSupport() {
    supportCard.classList.remove('hidden');
    supportReportText.textContent = 'Generando reporte de diagnóstico...';

    try {
      const res = await fetch(`${apiBase}/api/report`);
      const data = await res.json();
      const rep = data.report || {};

      const report = 
`=========================================
  REPORTE ASISTENCIA TI - ORANGE LATAM
=========================================
Fecha:     ${rep.timestamp || new Date().toLocaleString()}
Equipo:    ${rep.pcName || 'PC'}
Usuario:   ${rep.userName || 'Usuario'}
Windows:   ${rep.osName || 'Win 10/11'} (Build ${rep.osBuild || ''})
IP:        ${rep.ipAddress || '-'}
RAM:       ${rep.ramTotal || '-'}
Problema:  ${lastActionTitle || 'Reparación'}
=========================================`;

      supportReportText.textContent = report;

      const mailSubject = encodeURIComponent(`Soporte TI - ${rep.pcName || 'Equipo'} - ${lastActionTitle}`);
      const mailBody = encodeURIComponent(`Hola Soporte TI,\n\nRequiero asistencia:\n\n${report}`);
      btnMailSupport.href = `mailto:soporte@orangelatam.com?subject=${mailSubject}&body=${mailBody}`;

    } catch (e) {
      supportReportText.textContent = 'Error generando reporte.';
    }

    supportCard.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  // ==========================================================================
  // 4. LOGGING EN CONSOLA AVANZADA
  // ==========================================================================
  function logEvent(msg, type = 'info') {
    const time = new Date().toLocaleTimeString('es-ES', { hour12: false });
    const row = document.createElement('div');
    row.className = `log-row ${type}`;
    row.textContent = `[${time}] ${msg}`;
    
    if (terminalOutput) {
      terminalOutput.appendChild(row);
      terminalOutput.scrollTop = terminalOutput.scrollHeight;
    }
  }

  // ==========================================================================
  // 5. EVENT LISTENERS
  // ==========================================================================

  // Botón Principal 1-Click
  if (btnActionAll) {
    btnActionAll.addEventListener('click', () => {
      runAction(btnActionAll.dataset.action, btnActionAll.dataset.title, btnActionAll.closest('.hero-card'));
    });
  }

  // Tiles Rápidos
  actionTiles.forEach(tile => {
    if (tile.id === 'btn-open-cleaner-modal') return;
    tile.addEventListener('click', () => {
      runAction(tile.dataset.action, tile.dataset.title, tile);
    });
  });

  // Feedback Sí
  btnFeedbackYes.addEventListener('click', () => {
    resultActions.classList.add('hidden');
    resultThanks.classList.remove('hidden');
    supportCard.classList.add('hidden');
  });

  // Feedback No
  btnFeedbackNo.addEventListener('click', () => {
    resultActions.classList.add('hidden');
    openSupport();
  });

  // Cerrar Banner
  btnCloseBanner.addEventListener('click', () => {
    resultBanner.classList.add('hidden');
  });

  // Copiar Reporte
  btnCopySupport.addEventListener('click', async () => {
    const text = supportReportText.textContent;
    try {
      await navigator.clipboard.writeText(text);
      btnCopySupport.classList.add('copied');
      copySupportText.textContent = '✓ ¡Copiado!';
      setTimeout(() => {
        btnCopySupport.classList.remove('copied');
        copySupportText.textContent = '📋 Copiar Reporte';
      }, 3000);
    } catch (e) {
      const temp = document.createElement('textarea');
      temp.value = text;
      document.body.appendChild(temp);
      temp.select();
      document.execCommand('copy');
      document.body.removeChild(temp);
      copySupportText.textContent = '✓ ¡Copiado!';
    }
  });

  // Teams
  btnTeamsSupport.addEventListener('click', () => {
    btnCopySupport.click();
    alert('El reporte fue copiado. Pégalo en tu chat con Soporte en Microsoft Teams.');
  });

  // Modal Limpieza
  if (btnOpenCleaner) {
    btnOpenCleaner.addEventListener('click', () => {
      cleanerModal.classList.remove('hidden');
    });
  }

  btnModalBack.addEventListener('click', () => {
    cleanerModal.classList.add('hidden');
  });

  btnModalOk.addEventListener('click', () => {
    cleanerModal.classList.add('hidden');
    runAction(btnModalOk.dataset.action, btnModalOk.dataset.title);
  });

  // Opciones Avanzadas
  btnToggleAdvanced.addEventListener('click', () => {
    advancedPanel.classList.toggle('hidden');
    if (!advancedPanel.classList.contains('hidden')) {
      loadTelemetry();
      advancedPanel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  });

  btnClearTerminal.addEventListener('click', () => {
    terminalOutput.innerHTML = '<div class="log-row info">[SISTEMA] Consola limpiada.</div>';
  });

  // Inicializar chequeo inicial
  checkHealth();
});
