'use strict';
const http = require('http');
const https = require('https');
const fs = require('fs');
const {readTurnWait}=require('./tx-turn-state.js');
const net = require('net');
const { spawn } = require('child_process');
const readline = require('readline');

const LISTEN_HOST = process.env.XLX_LIVE_HUB_HOST || '127.0.0.1';
const LISTEN_PORT = Number(process.env.XLX_LIVE_HUB_PORT || 8091);
const LOG_FILE = process.env.XLX_LIVE_LOG_FILE || '/var/log/xlx.log';
const ACTIVE_REFRESH_MS = Number(process.env.XLX_LIVE_ACTIVE_MS || 250);
const STANDBY_SAFETY_MS = Number(process.env.XLX_LIVE_IDLE_MS || 3000);
const HEARTBEAT_MS = Number(process.env.XLX_LIVE_HEARTBEAT_MS || 15000);
const SNAPSHOT_MAX_AGE_MS = Math.max(250, Number(process.env.XLX_LIVE_SNAPSHOT_MAX_AGE_MS || 5000));
const MAX_CLIENT_BUFFER = 262144;
const SNAPSHOT_FILE = process.env.XLX_LIVE_SNAPSHOT_FILE || '/run/xlx-modern-live-hub/latest.json';

/* MTR contínuo: um processo por transmissão ativa, nunca por navegador. */
const MTR_WINDOW_MS = 10000;
const MTR_PUBLISH_MS = 1000;
const MAX_MTR_MONITORS = 3;
const MTR_IDLE_GRACE_MS = 30000;

const SOURCE_SCHEME = process.env.XLX_LIVE_SOURCE_SCHEME === 'http' ? 'http' : 'https';
const SOURCE_HOST = process.env.XLX_LIVE_SOURCE_HOST || '127.0.0.1';
const SOURCE_PORT = Number(process.env.XLX_LIVE_SOURCE_PORT || (SOURCE_SCHEME === 'http' ? 80 : 443));
const SOURCE_PATH = process.env.XLX_LIVE_SOURCE_PATH || '/api/live-hub-source';
const SOURCE_SERVERNAME = process.env.XLX_LIVE_SOURCE_SERVERNAME || 'localhost';
const sourceModule = SOURCE_SCHEME === 'http' ? http : https;
const upstreamAgent = SOURCE_SCHEME === 'http'
  ? new http.Agent({ keepAlive: true, maxSockets: 2 })
  : new https.Agent({ keepAlive: true, maxSockets: 2, rejectUnauthorized: false });
const clients = new Set();
const mtrMonitors = new Map();
let latest = null;
let latestSignature = '';
let inFlight = false;
let rerun = false;
let activeTimer = null;
let standbyTimer = null;
let watchDebounce = null;
let upstreamErrors = 0;
let lastFetchAt = 0;
let lastBroadcastAt = 0;
let latestUpdatedAt = 0;
let mtrIdleStopTimer = null;

function writeSnapshot(data) {
  try {
    const tmp = SNAPSHOT_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(data));
    fs.renameSync(tmp, SNAPSHOT_FILE);
  } catch (_) {}
}

function normalizedSignature(data) {
  if (!data || typeof data !== 'object') return '';
  const copy = Object.assign({}, data);
  delete copy.generated_at;
  return JSON.stringify(copy);
}

function sseWrite(res, text) {
  if (res.destroyed || res.writableEnded) return false;
  if (res.writableLength > MAX_CLIENT_BUFFER) {
    try { res.end(); } catch (_) {}
    return false;
  }
  try { return res.write(text); } catch (_) { return false; }
}

function broadcast(data, force = false) {
  const sig = normalizedSignature(data);
  if (!force && sig === latestSignature) return;
  latestSignature = sig;
  latest = data;
  lastBroadcastAt = Date.now();
  const payload = `event: live\nid: ${lastBroadcastAt}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const res of [...clients]) {
    if (!sseWrite(res, payload)) clients.delete(res);
  }
}

function round1(value) {
  return Math.round(Number(value) * 10) / 10;
}

function isPublicTarget(ip) {
  const family = net.isIP(ip);
  if (family === 4) {
    const p = ip.split('.').map(Number);
    if (p.length !== 4 || p.some(n => !Number.isInteger(n) || n < 0 || n > 255)) return false;
    if (p[0] === 0 || p[0] === 10 || p[0] === 127 || p[0] >= 224) return false;
    if (p[0] === 169 && p[1] === 254) return false;
    if (p[0] === 172 && p[1] >= 16 && p[1] <= 31) return false;
    if (p[0] === 192 && p[1] === 168) return false;
    if (p[0] === 100 && p[1] >= 64 && p[1] <= 127) return false;
    if (p[0] === 198 && (p[1] === 18 || p[1] === 19)) return false;
    return true;
  }
  if (family === 6) {
    const v = ip.toLowerCase();
    if (v === '::' || v === '::1') return false;
    if (v.startsWith('fe8') || v.startsWith('fe9') || v.startsWith('fea') || v.startsWith('feb')) return false;
    if (v.startsWith('fc') || v.startsWith('fd') || v.startsWith('ff')) return false;
    return true;
  }
  return false;
}

function monitorKey(module, tx) {
  return [module, tx?.stream_id || '', tx?.started_at || '', tx?.ip || ''].join(':');
}

function newHop() {
  return { ip: '', sent: new Map(), recv: new Map() };
}

function pruneMonitor(monitor, now = Date.now()) {
  const cutoff = now - MTR_WINDOW_MS;
  for (const hop of monitor.hops.values()) {
    for (const [seq, t] of hop.sent) if (t < cutoff) hop.sent.delete(seq);
    for (const [seq, row] of hop.recv) if (row.t < cutoff) hop.recv.delete(seq);
  }
}

function mtrStatus(average, loss, jitter, routePartial) {
  if (average == null || loss == null || jitter == null) {
    return { status: 'unknown', label: 'Medindo' };
  }
  if (routePartial) {
    if (average <= 150 && loss <= 5 && jitter <= 50) return { status: 'warning', label: 'Rota parcial' };
    return { status: 'bad', label: 'Rota parcial ruim' };
  }
  if (loss >= 100) return { status: 'bad', label: 'Sem resposta' };
  if (average <= 80 && loss <= 1 && jitter <= 20) return { status: 'good', label: 'Estável' };
  if (average <= 150 && loss <= 5 && jitter <= 50) return { status: 'warning', label: 'Variação' };
  return { status: 'bad', label: 'Ruim' };
}

function buildMtrResult(monitor) {
  const now = Date.now();
  pruneMonitor(monitor, now);

  const exactCandidates = [];
  let lastResponding = null;
  for (const [position, hop] of [...monitor.hops.entries()].sort((a, b) => a[0] - b[0])) {
    if (hop.recv.size > 0) lastResponding = { position, hop };
    if (hop.ip === monitor.ip && hop.recv.size > 0) exactCandidates.push({ position, hop });
  }
  exactCandidates.sort((a, b) =>
    b.hop.recv.size - a.hop.recv.size
    || b.hop.sent.size - a.hop.sent.size
    || a.position - b.position
  );
  const exact = exactCandidates[0] || null;
  const selected = exact || lastResponding;
  if (!selected) {
    return {
      ok: true,
      state: 'measuring',
      gateway: monitor.gateway,
      status: 'unknown',
      status_label: 'Medindo',
      route_partial: false,
      avg_ms: null,
      loss_pct: null,
      jitter_ms: null,
      history: monitor.history.slice(-8),
      updated_at: Math.floor(now / 1000),
      mode: 'stream',
      sample_window_s: MTR_WINDOW_MS / 1000,
    };
  }

  const hop = selected.hop;
  const sent = hop.sent.size;
  const values = [...hop.recv.values()].map(row => row.ms).filter(Number.isFinite);
  const received = values.length;
  const average = received ? values.reduce((a, b) => a + b, 0) / received : null;
  const variance = received && average != null
    ? values.reduce((sum, value) => sum + Math.pow(value - average, 2), 0) / received
    : null;
  const jitter = variance == null ? null : Math.sqrt(variance);
  const loss = sent > 0 ? Math.max(0, Math.min(100, ((sent - received) / sent) * 100)) : null;
  const routePartial = !exact;
  const status = mtrStatus(average, loss, jitter, routePartial);

  return {
    ok: true,
    state: received >= 2 ? 'ready' : 'measuring',
    gateway: monitor.gateway,
    status: status.status,
    status_label: status.label,
    route_partial: routePartial,
    avg_ms: average == null ? null : round1(average),
    loss_pct: loss == null ? null : round1(loss),
    jitter_ms: jitter == null ? null : round1(jitter),
    history: monitor.history.slice(-8),
    updated_at: Math.floor(now / 1000),
    samples: received,
    probes: sent,
    mode: 'stream',
    sample_window_s: MTR_WINDOW_MS / 1000,
  };
}

function stopMtrMonitor(module) {
  const monitor = mtrMonitors.get(module);
  if (!monitor) return;
  monitor.stopping = true;
  try { monitor.proc.kill('SIGTERM'); } catch (_) {}
  try { monitor.rl.close(); } catch (_) {}
  mtrMonitors.delete(module);
}

function startMtrMonitor(module, tx) {
  if (mtrMonitors.size >= MAX_MTR_MONITORS) return null;
  const ip = String(tx?.ip || '').trim();
  if (!isPublicTarget(ip)) return null;
  const args = ['--raw', '-n', '-i', '1'];
  if (net.isIP(ip) === 4) args.push('-4');
  if (net.isIP(ip) === 6) args.push('-6');
  args.push(ip);
  const proc = spawn('/usr/bin/mtr', args, { stdio: ['ignore', 'pipe', 'pipe'] });
  const monitor = {
    module,
    key: monitorKey(module, tx),
    ip,
    gateway: String(tx?.gateway || tx?.callsign || 'Gateway'),
    hops: new Map(),
    history: [],
    lastResult: null,
    proc,
    rl: null,
    stopping: false,
    startedAt: Date.now(),
    errors: 0,
    sampleVersion: 0,
    lastHistoryVersion: -1,
  };
  const rl = readline.createInterface({ input: proc.stdout, crlfDelay: Infinity });
  monitor.rl = rl;

  rl.on('line', line => {
    const parts = String(line || '').trim().split(/\s+/);
    if (parts.length < 3) return;
    const type = parts[0];
    const position = Number(parts[1]);
    if (!Number.isInteger(position) || position < 0 || position > 64) return;
    if (!monitor.hops.has(position)) monitor.hops.set(position, newHop());
    const hop = monitor.hops.get(position);
    const now = Date.now();
    if (type === 'h') {
      if (net.isIP(parts[2])) hop.ip = parts[2];
      return;
    }
    if (type === 'x') {
      const seq = String(parts[2]);
      hop.sent.set(seq, now);
      return;
    }
    if (type === 'p' && parts.length >= 4) {
      const us = Number(parts[2]);
      const seq = String(parts[3]);
      if (Number.isFinite(us) && us >= 0) {
        hop.recv.set(seq, { t: now, ms: us / 1000 });
        monitor.sampleVersion++;
      }
    }
  });

  proc.stderr.on('data', chunk => {
    if (String(chunk || '').trim()) monitor.errors++;
  });
  proc.on('error', () => { monitor.errors++; });
  proc.on('exit', () => {
    if (mtrMonitors.get(module) === monitor) mtrMonitors.delete(module);
  });

  mtrMonitors.set(module, monitor);
  return monitor;
}

function syncMtrMonitors(data) {
  const active = data && data.active && typeof data.active === 'object' ? data.active : {};
  if (clients.size === 0) {
    return;
  }

  for (const module of [...mtrMonitors.keys()]) {
    const tx = active[module];
    const monitor = mtrMonitors.get(module);
    if (!tx || !monitor || monitor.key !== monitorKey(module, tx)) stopMtrMonitor(module);
  }

  for (const [module, tx] of Object.entries(active).slice(0, MAX_MTR_MONITORS)) {
    if (!tx || !isPublicTarget(String(tx.ip || '').trim())) continue;
    let monitor = mtrMonitors.get(module);
    if (!monitor) monitor = startMtrMonitor(module, tx);
    if (monitor) monitor.gateway = String(tx.gateway || tx.callsign || 'Gateway');
  }
}

function attachMtrSnapshots(data) {
  if (!data || !data.active || typeof data.active !== 'object') return data;
  for (const [module, tx] of Object.entries(data.active)) {
    const monitor = mtrMonitors.get(module);
    if (monitor && monitor.lastResult) tx.network_mtr = monitor.lastResult;
  }
  return data;
}

function publishMtrSnapshots() {
  if (!latest || clients.size === 0 || mtrMonitors.size === 0) return;
  let hasData = false;
  for (const monitor of mtrMonitors.values()) {
    const result = buildMtrResult(monitor);
    if (
      result.avg_ms != null
      && monitor.sampleVersion !== monitor.lastHistoryVersion
    ) {
      monitor.history.push(result.avg_ms);
      monitor.history = monitor.history.slice(-8);
      monitor.lastHistoryVersion = monitor.sampleVersion;
    }
    result.history = monitor.history.slice();
    monitor.lastResult = result;
    hasData = true;
  }
  if (!hasData) return;
  attachMtrSnapshots(latest);
  writeSnapshot(latest);
  broadcast(latest, false);
}

function scheduleMode() {
  if (activeTimer) { clearInterval(activeTimer); activeTimer = null; }
  if (standbyTimer) { clearInterval(standbyTimer); standbyTimer = null; }
  const active = Number(latest?.active_count || 0) > 0;
  if (clients.size === 0) {
    if (mtrIdleStopTimer === null && mtrMonitors.size > 0) {
      mtrIdleStopTimer = setTimeout(() => {
        mtrIdleStopTimer = null;
        if (clients.size === 0) {
          for (const module of [...mtrMonitors.keys()]) stopMtrMonitor(module);
        }
      }, MTR_IDLE_GRACE_MS);
    }
    return;
  }
  if (mtrIdleStopTimer !== null) {
    clearTimeout(mtrIdleStopTimer);
    mtrIdleStopTimer = null;
  }
  syncMtrMonitors(latest || { active: {} });
  if (active) activeTimer = setInterval(() => fetchLive('active'), ACTIVE_REFRESH_MS);
  else standbyTimer = setInterval(() => fetchLive('safety'), STANDBY_SAFETY_MS);
}

function fetchLive(reason = 'event') {
  if (inFlight) { rerun = true; return; }
  inFlight = true;
  const req = sourceModule.request({
    host: SOURCE_HOST,
    port: SOURCE_PORT,
    path: SOURCE_PATH,
    method: 'GET',
    servername: SOURCE_SERVERNAME,
    rejectUnauthorized: false,
    agent: upstreamAgent,
    headers: { Host: SOURCE_SERVERNAME, Accept: 'application/json', 'User-Agent': 'XLX026-LiveHub/1.1' },
    timeout: 1200,
  }, res => {
    let body = '';
    res.setEncoding('utf8');
    res.on('data', chunk => { if (body.length < 1048576) body += chunk; });
    res.on('end', () => {
      lastFetchAt = Date.now();
      if (res.statusCode === 200) {
        try {
          const data = JSON.parse(body);
          if (data && data.ok === true) {
            upstreamErrors = 0;
            const wasActive = Number(latest?.active_count || 0) > 0;
            const nowActive = Number(data.active_count || 0) > 0;
            syncMtrMonitors(data);
            attachMtrSnapshots(data);
            data.tx_turn_wait=readTurnWait();
            latest = data;
            latestUpdatedAt = Date.now();
            writeSnapshot(data);
            broadcast(data, false);
            if (wasActive !== nowActive) scheduleMode();
          }
        } catch (_) { upstreamErrors++; }
      } else upstreamErrors++;
      inFlight = false;
      if (rerun) { rerun = false; setImmediate(() => fetchLive('rerun')); }
    });
  });
  req.on('timeout', () => req.destroy(new Error('timeout')));
  req.on('error', () => {
    upstreamErrors++;
    inFlight = false;
    if (rerun) { rerun = false; setImmediate(() => fetchLive('rerun')); }
  });
  req.end();
}

function addClient(req, res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',
    'Access-Control-Allow-Origin': 'https://xlx026.net',
  });
  res.write('retry: 1500\n\n');
  clients.add(res);
  const snapshotAge = latestUpdatedAt ? Date.now() - latestUpdatedAt : Number.POSITIVE_INFINITY;
  if (latest && snapshotAge <= SNAPSHOT_MAX_AGE_MS) {
    syncMtrMonitors(latest);
    attachMtrSnapshots(latest);
    const payload = `event: live\nid: ${Date.now()}\ndata: ${JSON.stringify(latest)}\n\n`;
    sseWrite(res, payload);
  } else {
    // Never make an old in-memory snapshot authoritative for a new browser.
    // Clearing only the signature forces the next validated upstream fetch to
    // be delivered even when its logical state is unchanged.
    latestSignature = '';
    fetchLive('connect');
  }
  scheduleMode();
  req.on('close', () => {
    clients.delete(res);
    scheduleMode();
  });
}

const server = http.createServer((req, res) => {
  if (req.url === '/stream') return addClient(req, res);
  if (req.url === '/health') {
    const body = JSON.stringify({
      ok: true,
      clients: clients.size,
      active_count: Number(latest?.active_count || 0),
      mtr_monitors: mtrMonitors.size,
      last_fetch_age_ms: lastFetchAt ? Date.now() - lastFetchAt : null,
      last_broadcast_age_ms: lastBroadcastAt ? Date.now() - lastBroadcastAt : null,
      snapshot_age_ms: latestUpdatedAt ? Date.now() - latestUpdatedAt : null,
      upstream_errors: upstreamErrors,
    });
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    return res.end(body);
  }
  res.writeHead(404); res.end('not found');
});

try {
  fs.watch(LOG_FILE, { persistent: true }, () => {
    if (watchDebounce) clearTimeout(watchDebounce);
    watchDebounce = setTimeout(() => fetchLive('log'), 20);
  });
} catch (err) {
  console.error('log watch failed:', err.message);
}

const heartbeat = setInterval(() => {
  const line = `: ping ${Date.now()}\n\n`;
  for (const res of [...clients]) if (!sseWrite(res, line)) clients.delete(res);
}, HEARTBEAT_MS);
const mtrPublisher = setInterval(publishMtrSnapshots, MTR_PUBLISH_MS);

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(`XLX026 live hub listening on ${LISTEN_HOST}:${LISTEN_PORT}`);
  fetchLive('startup');
});

function shutdown() {
  clearInterval(heartbeat);
  clearInterval(mtrPublisher);
  if (mtrIdleStopTimer !== null) clearTimeout(mtrIdleStopTimer);
  if (activeTimer) clearInterval(activeTimer);
  if (standbyTimer) clearInterval(standbyTimer);
  for (const module of [...mtrMonitors.keys()]) stopMtrMonitor(module);
  for (const res of clients) { try { res.end(); } catch (_) {} }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1500).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
