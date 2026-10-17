use anyhow::{Context, Result};
use axum::{
    extract::{ws::{Message, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use chrono::{Datelike, Local, NaiveDateTime, TimeZone};
use futures_util::{SinkExt, StreamExt};
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    fs::{self, File},
    io::{Read, Seek, SeekFrom},
    net::SocketAddr,
    path::{Path, PathBuf},
    sync::Arc,
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::{io::{AsyncBufReadExt, BufReader as AsyncBufReader}, process::Command, sync::{broadcast, Mutex, RwLock}, task::JoinHandle};

const LOG_FILE: &str = "/var/log/xlx.log";
const STATUS_FILE: &str = "/var/cache/xlx026-dashboard/status.json";
const RADIOID_ALIAS_FILE: &str = "/var/lib/xlx026-identity/radioid-aliases.json";
const VU_DIR: &str = "/run/xlx-vu-tap";
const VU_DMR_FALLBACK_DIR: &str = "/run/xlx-dmr-normalizer";
const MAX_LOG_BOOT_BYTES: u64 = 524_288;
const VU_FRESH_MS: i64 = 1800;

#[derive(Clone, Debug, Serialize, Deserialize, Default, PartialEq)]
struct Country {
    #[serde(default)]
    code: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    flag: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default, PartialEq)]
struct AudioVu {
    rms_dbfs: f64,
    peak_dbfs: f64,
    level: String,
    protocol: String,
    #[serde(default)]
    mode: String,
    ts_ms: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default, PartialEq)]
struct Tx {
    key: String,
    module: String,
    stream_id: u64,
    callsign: String,
    #[serde(default)]
    suffix: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    location: String,
    #[serde(default)]
    country: Country,
    #[serde(default)]
    protocol: String,
    started_at: i64,
    #[serde(default)]
    qrz: String,
    #[serde(default)]
    gateway: String,
    #[serde(default)]
    via: String,
    #[serde(default)]
    peer: String,
    #[serde(default)]
    ip: String,
    #[serde(default = "tx_state")]
    state: String,
    #[serde(default)]
    gateway_suffix: String,
    #[serde(default)]
    network_callsign: String,
    #[serde(default)]
    identity_source: String,
    #[serde(default)]
    origin_match: String,
    #[serde(default)]
    identity_match: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    audio_vu: Option<AudioVu>,
}

fn tx_state() -> String { "transmitting".to_string() }

#[derive(Clone, Debug, Serialize, Deserialize, Default, PartialEq)]
struct Snapshot {
    ok: bool,
    generated_at: i64,
    active_count: usize,
    active: HashMap<String, Tx>,
}

#[derive(Clone, Debug, Default)]
struct RecentClient {
    callsign: String,
    suffix: String,
    ip: String,
    protocol: String,
    module: String,
}

#[derive(Clone)]
struct AppState {
    snapshot: Arc<RwLock<Snapshot>>,
    bus: broadcast::Sender<String>,
    mtr_tasks: Arc<Mutex<HashMap<String, MtrTask>>>,
}

struct MtrTask {
    key: String,
    handle: JoinHandle<()>,
}

#[derive(Clone)]
struct ParserRules {
    opening: Regex,
    closing: Regex,
    new_client: Regex,
    link_module: Regex,
}

impl ParserRules {
    fn new() -> Result<Self> {
        Ok(Self {
            opening: Regex::new(
                r"Opening stream on module\s+([A-Z])\s+for\s+(?:client\s+)?([A-Z0-9/\-]+)(?:\s+([A-Z0-9]{1,4}))?.*?with sid\s+(\d+)"
            )?,
            closing: Regex::new(r"Closing stream of module\s+([A-Z])")?,
            new_client: Regex::new(
                r"New client\s+([A-Z0-9]+)(?:\s+([A-Z0-9]+))?\s+at\s+([0-9A-Fa-f:\.]+).*?protocol\s+([A-Za-z0-9+_\-]+)"
            )?,
            link_module: Regex::new(
                r"(?:client\s+)?([A-Z0-9]+)(?:\s+([A-Z0-9]+))?\s+linking on module\s+([A-Z])"
            )?,
        })
    }
}

fn now_s() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as i64
}
fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_millis() as i64
}

fn parse_log_time(line: &str) -> i64 {
    if line.len() < 17 { return now_s(); }
    let prefix = &line[..17.min(line.len())];
    let year = Local::now().year();
    let with_year = format!("{} {}", prefix, year);
    if let Ok(dt) = NaiveDateTime::parse_from_str(&with_year, "%d %b, %H:%M:%S %Y") {
        if let Some(local) = Local.from_local_datetime(&dt).single() {
            return local.timestamp();
        }
    }
    now_s()
}

fn normalize_protocol(raw: &str) -> String {
    let p = raw.trim().to_uppercase();
    if p.contains("DMR") { return "DMR".into(); }
    if p.contains("YSF") || p.contains("C4FM") { return "C4FM/YSF".into(); }
    if p.contains("DSTAR") || p.contains("D-STAR") || p.contains("DPLUS") || p.contains("DEXTRA") || p.contains("DCS") {
        return "D-STAR".into();
    }
    p
}

fn read_status() -> Option<Value> {
    fs::read_to_string(STATUS_FILE).ok().and_then(|s| serde_json::from_str(&s).ok())
}

fn copy_str(v: &Value, key: &str) -> String {
    v.get(key).and_then(Value::as_str).unwrap_or("").trim().to_string()
}

fn copy_u64(v: &Value, key: &str) -> u64 {
    v.get(key).and_then(Value::as_u64).unwrap_or(0)
}

fn copy_i64(v: &Value, key: &str) -> i64 {
    v.get(key).and_then(Value::as_i64).unwrap_or(0)
}

fn apply_connection(tx: &mut Tx, c: &Value) {
    if tx.name.is_empty() { tx.name = copy_str(c, "name"); }
    if tx.location.is_empty() { tx.location = copy_str(c, "location"); }
    if tx.protocol.is_empty() { tx.protocol = normalize_protocol(&copy_str(c, "protocol")); }
    if tx.qrz.is_empty() { tx.qrz = copy_str(c, "qrz"); }
    if tx.via.is_empty() { tx.via = copy_str(c, "via"); }
    if tx.peer.is_empty() { tx.peer = copy_str(c, "peer"); }
    if tx.ip.is_empty() { tx.ip = copy_str(c, "ip"); }
    if tx.country.code.is_empty() {
        if let Some(country) = c.get("country") {
            tx.country = serde_json::from_value(country.clone()).unwrap_or_default();
        }
    }
}

fn enrich_tx(tx: &mut Tx, status: Option<&Value>, recent: &[RecentClient]) {
    if let Some(s) = status {
        if let Some(conns) = s.get("connections").and_then(Value::as_array) {
            let mut best: Option<&Value> = None;
            for c in conns {
                let call = copy_str(c, "callsign").to_uppercase();
                let suffix = copy_str(c, "suffix").to_uppercase();
                let module = copy_str(c, "module").to_uppercase();
                if call == tx.callsign && module == tx.module {
                    if !tx.suffix.is_empty() && suffix == tx.suffix { best = Some(c); break; }
                    if best.is_none() { best = Some(c); }
                }
            }
            if let Some(c) = best { apply_connection(tx, c); }
        }

        if let Some(stx) = s.get("modules")
            .and_then(|m| m.get(&tx.module))
            .and_then(|m| m.get("transmission"))
            .filter(|v| v.is_object())
        {
            let sid = copy_u64(stx, "stream_id");
            let started = copy_i64(stx, "started_at");
            let identity_source = copy_str(stx, "identity_source");
            let same_stream = sid > 0 && sid == tx.stream_id;
            let same_time = started > 0 && (started - tx.started_at).abs() <= 2;
            if (same_stream || same_time) && identity_source.starts_with("xlxd-station") {
                // PHP atual copia o sufixo STATION inclusive quando vazio.
                tx.suffix = copy_str(stx, "suffix").to_uppercase();
                for key in ["callsign","name","location","protocol","qrz","gateway","gateway_suffix","network_callsign","identity_source","origin_match"] {
                    let val = copy_str(stx, key);
                    if !val.is_empty() {
                        match key {
                            "callsign" => tx.callsign = val.to_uppercase(),
                            "name" => tx.name = val,
                            "location" => tx.location = val,
                            "protocol" => tx.protocol = normalize_protocol(&val),
                            "qrz" => tx.qrz = val,
                            "gateway" => tx.gateway = val.to_uppercase(),
                            "gateway_suffix" => tx.gateway_suffix = val.to_uppercase(),
                            "network_callsign" => tx.network_callsign = val.to_uppercase(),
                            "identity_source" => tx.identity_source = val,
                            "origin_match" => tx.origin_match = val,
                            _ => {}
                        }
                    }
                }
                if let Some(country) = stx.get("country") {
                    tx.country = serde_json::from_value(country.clone()).unwrap_or_else(|_| tx.country.clone());
                }
                tx.identity_match = if same_stream {
                    "station-stream-time-gateway".into()
                } else {
                    "station-time-gateway".into()
                };
            }
        }
    }

    if tx.ip.is_empty() || tx.protocol.is_empty() {
        if let Some(c) = recent.iter().rev().find(|c| {
            c.callsign == tx.callsign && (tx.suffix.is_empty() || c.suffix == tx.suffix)
        }) {
            if tx.ip.is_empty() { tx.ip = c.ip.clone(); }
            if tx.protocol.is_empty() { tx.protocol = normalize_protocol(&c.protocol); }
            if tx.suffix.is_empty() { tx.suffix = c.suffix.clone(); }
        }
    }

    if tx.name.is_empty() { tx.name = tx.callsign.clone(); }
    if tx.qrz.is_empty() { tx.qrz = format!("https://www.qrz.com/db/{}", tx.callsign); }
    if tx.gateway.is_empty() { tx.gateway = tx.callsign.clone(); }
    if tx.network_callsign.is_empty() { tx.network_callsign = tx.gateway.clone(); }
    if tx.gateway_suffix.is_empty() { tx.gateway_suffix = tx.suffix.clone(); }
    if tx.protocol.is_empty() { tx.protocol = "Digital".into(); }
}

fn apply_verified_radioid_alias(tx: &mut Tx) {
    if !tx.protocol.to_uppercase().contains("DMR") { return; }
    let old = tx.callsign.to_uppercase();
    let raw = match fs::read_to_string(RADIOID_ALIAS_FILE) { Ok(v) => v, Err(_) => return };
    let data: Value = match serde_json::from_str(&raw) { Ok(v) => v, Err(_) => return };
    let item = match data.get(&old) { Some(v) => v, None => return };
    let current = copy_str(item, "callsign").to_uppercase();
    let id = copy_str(item, "id");
    if id.len() != 7 || !id.bytes().all(|b| b.is_ascii_digit())
        || current.len() < 3 || current.len() > 8
        || !current.bytes().all(|b| b.is_ascii_alphanumeric()) || current == old { return; }
    if tx.network_callsign.is_empty() { tx.network_callsign = old.clone(); }
    tx.callsign = current.clone();
    tx.name = copy_str(item, "name");
    tx.location = copy_str(item, "location");
    tx.qrz = format!("https://www.qrz.com/db/{}", current);
    if tx.gateway == old { tx.gateway = current; }
}

fn active_signature(s: &Snapshot) -> String {
    let mut rows: Vec<String> = s.active.values().map(|tx| {
        format!("{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
            tx.module, tx.stream_id, tx.started_at, tx.callsign, tx.suffix,
            tx.name, tx.protocol, tx.gateway, tx.ip, tx.identity_source)
    }).collect();
    rows.sort();
    rows.join("\n")
}

async fn broadcast_state(state: &AppState) {
    let mut snap = state.snapshot.write().await;
    snap.ok = true;
    snap.generated_at = now_s();
    snap.active_count = snap.active.len();
    let msg = json!({"type":"state","data":&*snap}).to_string();
    let _ = state.bus.send(msg);
}

async fn send_vu_event(state: &AppState, module: &str, vu: AudioVu) {
    {
        let mut snap = state.snapshot.write().await;
        if let Some(tx) = snap.active.get_mut(module) {
            if tx.audio_vu.as_ref() == Some(&vu) { return; }
            tx.audio_vu = Some(vu.clone());
            snap.generated_at = now_s();
        } else { return; }
    }
    let _ = state.bus.send(json!({"type":"vu","module":module,"audio_vu":vu}).to_string());
}

fn read_vu_file(path: &Path) -> Option<AudioVu> {
    let raw = fs::read_to_string(path).ok()?;
    let v: Value = serde_json::from_str(&raw).ok()?;
    let ts = v.get("ts_ms")?.as_i64()?;
    let age = now_ms() - ts;
    if age < -250 || age > VU_FRESH_MS { return None; }
    let rms = v.get("rms_dbfs")?.as_f64()?;
    let peak = v.get("peak_dbfs")?.as_f64()?;
    Some(AudioVu {
        rms_dbfs: rms.clamp(-90.0, 3.0),
        peak_dbfs: peak.clamp(-90.0, 3.0),
        level: v.get("level").and_then(Value::as_str).unwrap_or("").to_string(),
        protocol: v.get("protocol").and_then(Value::as_str).unwrap_or("").to_uppercase(),
        mode: v.get("mode").and_then(Value::as_str).unwrap_or("").to_string(),
        ts_ms: ts,
    })
}

fn vu_candidates(tx: &Tx) -> Vec<PathBuf> {
    if tx.ip.is_empty() { return vec![]; }
    let slug = tx.ip.replace('.', "_").replace(':', "_");
    let p = tx.protocol.to_uppercase();
    let mut fams: Vec<&str> = Vec::new();
    if p.contains("DMR") { fams.push("dmr"); }
    if p.contains("YSF") || p.contains("C4FM") { fams.push("ysf"); }
    if p.contains("D-STAR") || p.contains("DSTAR") || p.contains("DPLUS") || p.contains("DEXTRA") || p.contains("DCS") { fams.push("dstar"); }
    if fams.is_empty() { fams.extend(["dmr","ysf","dstar"]); }
    let mut out = vec![];
    for fam in fams {
        out.push(Path::new(VU_DIR).join(format!("vu-{}-{}.json", fam, slug)));
        if fam == "dmr" {
            out.push(Path::new(VU_DMR_FALLBACK_DIR).join(format!("vu-{}.json", slug)));
            out.push(Path::new(VU_DMR_FALLBACK_DIR).join(format!("vu-dmr-{}.json", slug)));
        }
    }
    out
}

async fn refresh_vu_for_active(state: &AppState) {
    let active = state.snapshot.read().await.active.clone();
    for (module, tx) in active {
        let mut best: Option<AudioVu> = None;
        for p in vu_candidates(&tx) {
            if let Some(vu) = read_vu_file(&p) {
                if best.as_ref().map(|b| vu.ts_ms > b.ts_ms).unwrap_or(true) { best = Some(vu); }
            }
        }
        if let Some(vu) = best {
            send_vu_event(state, &module, vu).await;
        }
    }
}

fn process_line(
    line: &str,
    rules: &ParserRules,
    active: &mut HashMap<String, Tx>,
    recent: &mut Vec<RecentClient>,
    status: Option<&Value>,
) -> bool {
    let mut changed = false;

    if let Some(c) = rules.new_client.captures(line) {
        recent.push(RecentClient {
            callsign: c.get(1).map(|x| x.as_str().to_uppercase()).unwrap_or_default(),
            suffix: c.get(2).map(|x| x.as_str().to_uppercase()).unwrap_or_default(),
            ip: c.get(3).map(|x| x.as_str().to_string()).unwrap_or_default(),
            protocol: c.get(4).map(|x| x.as_str().to_string()).unwrap_or_default(),
            module: String::new(),
        });
        if recent.len() > 256 { recent.drain(0..(recent.len()-256)); }
    }

    if let Some(c) = rules.link_module.captures(line) {
        let call = c.get(1).map(|x| x.as_str().to_uppercase()).unwrap_or_default();
        let suffix = c.get(2).map(|x| x.as_str().to_uppercase()).unwrap_or_default();
        let module = c.get(3).map(|x| x.as_str().to_uppercase()).unwrap_or_default();
        if let Some(rc) = recent.iter_mut().rev().find(|x| x.callsign == call && (suffix.is_empty() || x.suffix == suffix)) {
            rc.module = module;
        }
    }

    if let Some(c) = rules.opening.captures(line) {
        let module = c.get(1).unwrap().as_str().to_uppercase();
        let callsign = c.get(2).unwrap().as_str().trim().to_uppercase();
        let mut suffix = c.get(3).map(|x| x.as_str().trim().to_uppercase()).unwrap_or_default();
        if suffix == "ON" || suffix == "VIA" || suffix == "WITH" { suffix.clear(); }
        let sid = c.get(4).and_then(|x| x.as_str().parse::<u64>().ok()).unwrap_or(0);
        let started = parse_log_time(line);
        let mut tx = Tx {
            key: format!("{}:{}:{}", module, sid, started),
            module: module.clone(),
            stream_id: sid,
            callsign,
            suffix,
            started_at: started,
            state: "transmitting".into(),
            ..Default::default()
        };
        enrich_tx(&mut tx, status, recent);
        apply_verified_radioid_alias(&mut tx);
        let old = active.insert(module, tx.clone());
        changed = old.as_ref() != Some(&tx);
    }

    if let Some(c) = rules.closing.captures(line) {
        let module = c.get(1).unwrap().as_str().to_uppercase();
        if active.remove(&module).is_some() { changed = true; }
    }

    changed
}

fn read_tail_lines(path: &str, max_bytes: u64) -> Result<(Vec<String>, u64)> {
    let mut f = File::open(path).with_context(|| format!("open {}", path))?;
    let len = f.metadata()?.len();
    let start = len.saturating_sub(max_bytes);
    f.seek(SeekFrom::Start(start))?;
    let mut raw = String::new();
    f.read_to_string(&mut raw)?;
    if start > 0 {
        if let Some(pos) = raw.find('\n') { raw = raw[pos+1..].to_string(); }
    }
    Ok((raw.lines().map(str::to_string).collect(), len))
}

async fn bootstrap_from_log(state: &AppState, rules: &ParserRules) -> Result<u64> {
    let (lines, offset) = read_tail_lines(LOG_FILE, MAX_LOG_BOOT_BYTES)?;
    let status = read_status();
    let mut recent: Vec<RecentClient> = Vec::new();
    let mut active: HashMap<String, Tx> = HashMap::new();
    for line in lines {
        process_line(&line, rules, &mut active, &mut recent, status.as_ref());
    }
    {
        let mut snap = state.snapshot.write().await;
        snap.ok = true;
        snap.generated_at = now_s();
        snap.active = active;
        snap.active_count = snap.active.len();
    }
    refresh_vu_for_active(state).await;
    Ok(offset)
}

async fn log_task(state: AppState, rules: ParserRules, mut offset: u64) -> Result<()> {
    use std::os::unix::fs::MetadataExt;

    let mut current_inode = fs::metadata(LOG_FILE).map(|m| m.ino()).unwrap_or(0);
    let mut recent: Vec<RecentClient> = Vec::new();

    loop {
        // 25 ms = detecção praticamente imediata sem fila de eventos acumulável.
        tokio::time::sleep(Duration::from_millis(25)).await;

        let meta = match fs::metadata(LOG_FILE) {
            Ok(m) => m,
            Err(_) => continue,
        };
        let inode = meta.ino();
        let len = meta.len();

        // Rotação/recriação: reaponta para o arquivo novo sem reiniciar o serviço.
        // Preserva TX já ativo durante a troca de inode; o novo log continuará
        // entregando os eventos de fechamento/abertura normalmente.
        if inode != current_inode {
            current_inode = inode;
            offset = 0;
            eprintln!("log inode changed; following new xlx.log inode={}", inode);
        } else if len < offset {
            offset = 0;
            eprintln!("log truncated; reset offset");
        }

        if len == offset { continue; }

        let mut f = match File::open(LOG_FILE) { Ok(f) => f, Err(_) => continue };
        if f.seek(SeekFrom::Start(offset)).is_err() { continue; }
        let mut raw = String::new();
        if f.read_to_string(&mut raw).is_err() { continue; }
        offset = f.stream_position().unwrap_or(len);

        if raw.is_empty() { continue; }

        // A maior parte do xlx.log é keepalive/status sem impacto visual.
        // Ignora antes de JSON/regex/locks.
        let interesting =
            raw.contains("Opening stream on module") ||
            raw.contains("Closing stream of module") ||
            raw.contains("New client") ||
            raw.contains("linking on module");

        if !interesting { continue; }

        // status.json só é necessário para enriquecer uma nova transmissão.
        let status = if raw.contains("Opening stream on module") {
            read_status()
        } else {
            None
        };

        let before = {
            let snap = state.snapshot.read().await;
            active_signature(&snap)
        };

        {
            let mut snap = state.snapshot.write().await;
            for line in raw.lines() {
                if line.contains("Opening stream on module")
                    || line.contains("Closing stream of module")
                    || line.contains("New client")
                    || line.contains("linking on module")
                {
                    process_line(line, &rules, &mut snap.active, &mut recent, status.as_ref());
                }
            }
            if let Some(ref status) = status {
                for tx in snap.active.values_mut() {
                    enrich_tx(tx, Some(status), &recent);
                }
            }
            snap.generated_at = now_s();
            snap.active_count = snap.active.len();
        }

        let after = {
            let snap = state.snapshot.read().await;
            active_signature(&snap)
        };

        if before != after {
            broadcast_state(&state).await;
            sync_mtr_tasks(&state).await;
            refresh_vu_for_active(&state).await;
        }
    }
}

async fn status_task(state: AppState) -> Result<()> {
    let mut last_stamp: Option<(u64, u128)> = None;

    loop {
        let active_now = state.snapshot.read().await.active_count > 0;
        tokio::time::sleep(if active_now {
            Duration::from_millis(250)
        } else {
            Duration::from_secs(2)
        }).await;

        let meta = match fs::metadata(STATUS_FILE) {
            Ok(m) => m,
            Err(_) => continue,
        };
        let modified = meta.modified().ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let stamp = (meta.len(), modified);

        if last_stamp == Some(stamp) { continue; }
        last_stamp = Some(stamp);

        // Sem TX não há identidade de box para enriquecer.
        if state.snapshot.read().await.active_count == 0 { continue; }

        let status = match read_status() { Some(s) => s, None => continue };
        let before = { let guard = state.snapshot.read().await; active_signature(&guard) };
        {
            let mut snap = state.snapshot.write().await;
            for tx in snap.active.values_mut() {
                enrich_tx(tx, Some(&status), &[]);
                apply_verified_radioid_alias(tx);
            }
            snap.generated_at = now_s();
            snap.active_count = snap.active.len();
        }
        let after = { let guard = state.snapshot.read().await; active_signature(&guard) };
        if before != after {
            broadcast_state(&state).await;
            sync_mtr_tasks(&state).await;
        }
    }
}

async fn vu_task(state: AppState) -> Result<()> {
    loop {
        let active_now = state.snapshot.read().await.active_count > 0;

        if active_now {
            // Somente o estado mais recente interessa ao VU; não existe backlog.
            refresh_vu_for_active(&state).await;
            tokio::time::sleep(Duration::from_millis(80)).await;
        } else {
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
    }
}


#[derive(Default)]
struct MtrHop {
    ip: String,
    sent: HashMap<String, i64>,
    recv: HashMap<String, (i64, f64)>,
}

fn public_ipv4(ip: &str) -> bool {
    let p: Vec<u8> = match ip.split('.').map(str::parse::<u8>).collect::<Result<Vec<_>,_>>() {
        Ok(v) if v.len()==4 => v,
        _ => return false,
    };
    if p[0]==0 || p[0]==10 || p[0]==127 || p[0]>=224 { return false; }
    if p[0]==169 && p[1]==254 { return false; }
    if p[0]==172 && (16..=31).contains(&p[1]) { return false; }
    if p[0]==192 && p[1]==168 { return false; }
    if p[0]==100 && (64..=127).contains(&p[1]) { return false; }
    if p[0]==198 && (p[1]==18 || p[1]==19) { return false; }
    true
}

fn mtr_result(hops: &mut HashMap<usize,MtrHop>, target: &str, history: &mut Vec<f64>) -> Option<Value> {
    let now=now_ms();
    let cutoff=now-10_000;
    for hop in hops.values_mut() {
        hop.sent.retain(|_,t| *t>=cutoff);
        hop.recv.retain(|_,(t,_)| *t>=cutoff);
    }

    let mut exact: Vec<(usize,&MtrHop)>=hops.iter()
        .filter(|(_,h)| h.ip==target && !h.recv.is_empty())
        .map(|(i,h)|(*i,h)).collect();
    exact.sort_by(|a,b| b.1.recv.len().cmp(&a.1.recv.len()).then_with(|| a.0.cmp(&b.0)));

    let selected = if let Some(x)=exact.first().copied() {
        Some((x.0,x.1,false))
    } else {
        hops.iter().filter(|(_,h)|!h.recv.is_empty()).max_by_key(|(i,_)|*i).map(|(i,h)|(*i,h,true))
    }?;

    let hop=selected.1;
    let sent=hop.sent.len();
    let values: Vec<f64>=hop.recv.values().map(|(_,v)|*v).collect();
    if values.is_empty(){return None}
    let avg=values.iter().sum::<f64>()/values.len() as f64;
    let var=values.iter().map(|v|(v-avg)*(v-avg)).sum::<f64>()/values.len() as f64;
    let jitter=var.sqrt();
    let loss=if sent>0 { (((sent as isize-values.len() as isize).max(0) as f64)/sent as f64*100.0).clamp(0.0,100.0) } else {0.0};
    let partial=selected.2;

    let avg=(avg*10.0).round()/10.0;
    let jitter=(jitter*10.0).round()/10.0;
    let loss=(loss*10.0).round()/10.0;
    if history.last().map(|v|(*v-avg).abs()>0.01).unwrap_or(true) {
        history.push(avg);
        if history.len()>8 { history.remove(0); }
    }

    let (status,label)=if partial {
        if avg<=150.0 && loss<=5.0 && jitter<=50.0 {("warning","Rota parcial")} else {("bad","Rota parcial ruim")}
    } else if loss>=100.0 {("bad","Sem resposta")}
    else if avg<=80.0 && loss<=1.0 && jitter<=20.0 {("good","Estável")}
    else if avg<=150.0 && loss<=5.0 && jitter<=50.0 {("warning","Variação")}
    else {("bad","Ruim")};

    Some(json!({
        "ok":true,
        "state": if values.len()>=2 {"ready"} else {"measuring"},
        "status":status,
        "status_label":label,
        "route_partial":partial,
        "avg_ms":avg,
        "loss_pct":loss,
        "jitter_ms":jitter,
        "history":history,
        "updated_at":now_s(),
        "samples":values.len(),
        "probes":sent,
        "mode":"stream-rust",
        "sample_window_s":10
    }))
}

async fn run_mtr_task(state: AppState, module: String, key: String, ip: String, gateway: String) {
    let mut child=match Command::new("/usr/bin/mtr")
        .args(["--raw","-n","-i","1","-4",&ip])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .kill_on_drop(true)
        .spawn() {
            Ok(c)=>c,
            Err(_)=>return,
        };
    let stdout=match child.stdout.take(){Some(s)=>s,None=>return};
    let mut lines=AsyncBufReader::new(stdout).lines();
    let mut hops: HashMap<usize,MtrHop>=HashMap::new();
    let mut history=Vec::<f64>::new();
    let mut publish=tokio::time::interval(Duration::from_millis(1000));
    publish.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut idle_secs=0u32;

    loop {
        tokio::select! {
            line=lines.next_line()=> {
                match line {
                    Ok(Some(line))=>{
                        let parts:Vec<&str>=line.split_whitespace().collect();
                        if parts.len()<3{continue}
                        let pos=match parts[1].parse::<usize>(){Ok(v) if v<=64=>v,_=>continue};
                        let hop=hops.entry(pos).or_default();
                        match parts[0] {
                            "h"=> { hop.ip=parts[2].to_string(); }
                            "x"=> { hop.sent.insert(parts[2].to_string(),now_ms()); }
                            "p" if parts.len()>=4 => {
                                if let Ok(us)=parts[2].parse::<f64>() {
                                    hop.recv.insert(parts[3].to_string(),(now_ms(),us/1000.0));
                                }
                            }
                            _=>{}
                        }
                    }
                    _=>break
                }
            }
            _=publish.tick()=> {
                // termina quando stream mudou/encerrou
                let valid={
                    let snap=state.snapshot.read().await;
                    snap.active.get(&module).map(|x|x.key==key && x.ip==ip).unwrap_or(false)
                };
                if !valid { break; }

                if state.bus.receiver_count()==0 {
                    idle_secs+=1;
                    if idle_secs>=30 { break; }
                    continue;
                } else { idle_secs=0; }

                if let Some(mut result)=mtr_result(&mut hops,&ip,&mut history) {
                    if let Some(obj)=result.as_object_mut() {
                        obj.insert("gateway".into(),json!(gateway));
                    }
                    let _=state.bus.send(json!({
                        "type":"mtr",
                        "module":module,
                        "network_mtr":result
                    }).to_string());
                }
            }
        }
    }
    let _=child.kill().await;
}

async fn sync_mtr_tasks(state: &AppState) {
    let active=state.snapshot.read().await.active.clone();
    let mut tasks=state.mtr_tasks.lock().await;

    let stale:Vec<String>=tasks.iter()
        .filter(|(m,t)| t.handle.is_finished() || active.get(*m).map(|x|x.key.as_str()!=t.key.as_str()).unwrap_or(true))
        .map(|(m,_)|m.clone()).collect();
    for m in stale {
        if let Some(t)=tasks.remove(&m){t.handle.abort();}
    }

    if state.bus.receiver_count()==0 { return; }

    for (module,tx) in active {
        if tasks.contains_key(&module) || !public_ipv4(&tx.ip) {continue}
        let st=state.clone();
        let m=module.clone();
        let k=tx.key.clone();
        let ip=tx.ip.clone();
        let gw=tx.gateway.clone();
        let handle=tokio::spawn(run_mtr_task(st,m.clone(),k.clone(),ip,gw));
        tasks.insert(module,MtrTask{key:k,handle});
    }
}

async fn health(State(state): State<AppState>) -> Json<Value> {
    let snap = state.snapshot.read().await;
    Json(json!({
        "ok": true,
        "engine": "xlx026-live-core-v2",
        "version": env!("CARGO_PKG_VERSION"),
        "generated_at": snap.generated_at,
        "active_count": snap.active_count,
        "ws_receivers": state.bus.receiver_count(),
        "transport": "websocket",
        "critical_path_php": false,
        "engine_mode": "inode-safe-coalesced"
    }))
}

async fn snapshot(State(state): State<AppState>) -> Json<Value> {
    let snap = state.snapshot.read().await.clone();
    Json(json!(snap))
}

async fn ws_handler(ws: WebSocketUpgrade, State(state): State<AppState>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| ws_client(socket, state))
}

async fn ws_client(socket: WebSocket, state: AppState) {
    let (mut sender, mut receiver) = socket.split();
    let hello = {
        let snap = state.snapshot.read().await;
        json!({"type":"hello","data":&*snap}).to_string()
    };
    sync_mtr_tasks(&state).await;
    if sender.send(Message::Text(hello.into())).await.is_err() { return; }

    let mut rx = state.bus.subscribe();
    let mut send_task = tokio::spawn(async move {
        while let Ok(msg) = rx.recv().await {
            if sender.send(Message::Text(msg.into())).await.is_err() { break; }
        }
    });

    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = receiver.next().await {
            match msg {
                Message::Close(_) => break,
                Message::Ping(_) | Message::Pong(_) | Message::Text(_) | Message::Binary(_) => {}
            }
        }
    });

    tokio::select! {
        _ = &mut send_task => recv_task.abort(),
        _ = &mut recv_task => send_task.abort(),
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let (bus, _) = broadcast::channel::<String>(256);
    let state = AppState {
        snapshot: Arc::new(RwLock::new(Snapshot { ok:true, generated_at:now_s(), ..Default::default() })),
        bus,
        mtr_tasks: Arc::new(Mutex::new(HashMap::new())),
    };
    let rules = ParserRules::new()?;
    let offset = bootstrap_from_log(&state, &rules).await?;
    eprintln!("bootstrap active={} offset={}", state.snapshot.read().await.active_count, offset);

    let lt_state = state.clone();
    let lt_rules = rules.clone();
    tokio::spawn(async move {
        if let Err(e) = log_task(lt_state, lt_rules, offset).await { eprintln!("log_task: {e:#}"); }
    });

    let st_state = state.clone();
    tokio::spawn(async move {
        if let Err(e) = status_task(st_state).await { eprintln!("status_task: {e:#}"); }
    });

    let vu_state = state.clone();
    tokio::spawn(async move {
        if let Err(e) = vu_task(vu_state).await { eprintln!("vu_task: {e:#}"); }
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/snapshot", get(snapshot))
        .route("/ws", get(ws_handler))
        .with_state(state);

    let bind = std::env::var("XLX026_BIND").unwrap_or_else(|_| "127.0.0.1:8092".to_string());
    let addr: SocketAddr = bind.parse().context("invalid XLX026_BIND")?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    eprintln!("XLX026 Live Core V2 listening on {}", addr);
    axum::serve(listener, app).await?;
    Ok(())
}

#[cfg(test)]
mod radioid_alias_tests {
    use super::*;
    #[test]
    fn verified_alias_updates_first_dmr_frame_and_gateway() {
        let mut tx = Tx { callsign: "PU2UJY".into(), protocol: "DMR".into(), gateway: "PU2UJY".into(), ..Default::default() };
        apply_verified_radioid_alias(&mut tx);
        assert_eq!(tx.callsign, "PY2UYY");
        assert_eq!(tx.gateway, "PY2UYY");
        assert_eq!(tx.network_callsign, "PU2UJY");
        assert!(!tx.name.is_empty());
    }
    #[test]
    fn preserves_unrelated_or_non_dmr_identity() {
        for (call, protocol) in [("PU2UJY", "D-STAR"), ("PU2PNY", "DMR")] {
            let mut tx = Tx { callsign: call.into(), protocol: protocol.into(), ..Default::default() };
            apply_verified_radioid_alias(&mut tx);
            assert_eq!(tx.callsign, call);
        }
    }
}
