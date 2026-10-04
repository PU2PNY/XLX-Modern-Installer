(() => {
  'use strict';

  if (!(window.XLXMODERN_LIVE_CORE_V2 || window.XLXMODERN_LIVE_CORE_V2)) return;
  if (document.body?.dataset?.page !== 'ao-vivo') return;

  let socket = null;
  let retryTimer = null;
  let retryMs = 700;
  let currentLive = null;
  let pendingState = false;
  let stopped = false;
  let transportReady = false;

  const wsUrl = () => {
    const scheme = location.protocol === 'https:' ? 'wss:' : 'ws:';
    return `${scheme}//${location.host}/api/live-v2/ws`;
  };

  function publishTransportState(connected) {
    try {
      window.dispatchEvent(new CustomEvent('xlxmodern-live-core-state', {
        detail: { connected: Boolean(connected), at: Date.now() }
      }));
    } catch (_) {}
  }

  function clearRetry() {
    if (retryTimer !== null) {
      clearTimeout(retryTimer);
      retryTimer = null;
    }
  }

  function scheduleReconnect() {
    if (stopped || document.hidden || retryTimer !== null) return;
    retryTimer = setTimeout(() => {
      retryTimer = null;
      connect();
    }, retryMs);
    retryMs = Math.min(4000, Math.round(retryMs * 1.5));
  }

  function applyState(live) {
    if (!live || live.ok !== true) return;
    currentLive = live;

    try {
      if (typeof xlxmodernLiveShared !== 'undefined') {
        xlxmodernLiveShared = live;
        xlxmodernLiveSharedAt = Date.now();
      }
    } catch (_) {}
    try {
      if (typeof xlxmodernLiveShared !== 'undefined') {
        xlxmodernLiveShared = live;
        xlxmodernLiveSharedAt = Date.now();
      }
    } catch (_) {}

    if (typeof updateLiveTxRx !== 'function') return;

    try {
      if (liveUpdateRunning) {
        if (pendingState) return;
        pendingState = true;
        queueMicrotask(() => {
          pendingState = false;
          if (!document.hidden) updateLiveTxRx();
        });
      } else {
        updateLiveTxRx();
      }
    } catch (_) {}
  }

  function applyVu(module, vu) {
    if (!currentLive?.active?.[module] || !vu) return;
    currentLive.active[module].audio_vu = vu;
    try {
      if (typeof xlxmodernUpdateTxVu === 'function') xlxmodernUpdateTxVu(currentLive);
      else if (typeof xlxmodernUpdateTxVu === 'function') xlxmodernUpdateTxVu(currentLive);
    } catch (_) {}
  }

  function applyMtr(module, mtr) {
    if (!currentLive?.active?.[module] || !mtr) return;
    currentLive.active[module].network_mtr = mtr;
    try { window.XLXMODERNMTR?.push?.(currentLive); } catch (_) {}
  }

  function onPayload(raw) {
    let message;
    try { message = JSON.parse(raw); } catch (_) { return; }
    if (!message || typeof message !== 'object') return;

    if (message.type === 'hello' || message.type === 'state') {
      if (!transportReady) {
        transportReady = true;
        publishTransportState(true);
      }
      applyState(message.data);
      return;
    }
    if (message.type === 'vu') {
      applyVu(String(message.module || '').toUpperCase(), message.audio_vu);
      return;
    }
    if (message.type === 'mtr') {
      applyMtr(String(message.module || '').toUpperCase(), message.network_mtr);
    }
  }

  function connect() {
    if (stopped || document.hidden || socket) return;

    try {
      socket = new WebSocket(wsUrl());
    } catch (_) {
      socket = null;
      scheduleReconnect();
      return;
    }

    socket.addEventListener('open', () => {
      retryMs = 700;
      transportReady = false;
      document.documentElement.dataset.liveCore = 'v2';
    });

    socket.addEventListener('message', event => {
      onPayload(event.data);
    });

    socket.addEventListener('close', () => {
      socket = null;
      transportReady = false;
      delete document.documentElement.dataset.liveCore;
      publishTransportState(false);
      scheduleReconnect();
    });

    socket.addEventListener('error', () => {
      try { socket?.close(); } catch (_) {}
    });
  }

  function disconnect() {
    clearRetry();
    transportReady = false;
    publishTransportState(false);
    const current = socket;
    socket = null;
    if (current) {
      try { current.close(1000, 'hidden'); } catch (_) {}
    }
  }

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      disconnect();
    } else {
      connect();
    }
  });

  window.addEventListener('pagehide', () => {
    stopped = true;
    disconnect();
  }, { once: true });

  connect();
})();
