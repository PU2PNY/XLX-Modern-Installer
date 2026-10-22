#!/usr/bin/env python3
"""Local, bounded archive of the published RadioID user metadata.
Stores only the 17 public API fields observed 2026-10-21, never arbitrary API additions.
"""
import json
import os
import re
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from contextlib import closing

DB = '/var/lib/xlx026-identity/radioid-profiles.sqlite3'
FIELDS = (
    'account_unvalidated', 'account_validation_status', 'callsign',
    'city', 'country', 'fname', 'has_valid_callsign', 'has_valid_email',
    'id', 'lastheard', 'lastmaster', 'lastsource', 'lasttg',
    'name', 'radio_id', 'state', 'surname'
)

def normalize(row):
    if not isinstance(row, dict):
        raise ValueError('RadioID record is not an object')
    rid = str(row.get('radio_id', row.get('id', '')))
    call = str(row.get('callsign', '')).strip().upper()
    if not re.fullmatch(r'\d{7}', rid) or not re.fullmatch(r'[A-Z0-9]{3,8}', call):
        raise ValueError('invalid RadioID identity')
    out = {}
    for key in FIELDS:
        val = row.get(key)
        if val is None or isinstance(val, (str, int, bool, float)):
            out[key] = val[:512] if isinstance(val, str) else val
        else:
            out[key] = None
    out['callsign'] = call
    out['radio_id'] = rid
    return rid, call, out

def store_profile(row, db_path=DB):
    rid, call, payload = normalize(row)
    data = json.dumps(payload, ensure_ascii=False, separators=(',', ':'), sort_keys=True)
    if len(data.encode('utf-8')) > 8192:
        raise ValueError('profile exceeds storage bound')
    # The identity path already exists and is root-only.
    original_umask = os.umask(0o077)
    try:
        conn = sqlite3.connect(db_path, timeout=3)
    finally:
        os.umask(original_umask)
    try:
        conn.execute('PRAGMA busy_timeout=3000')
        with conn:
            conn.execute('CREATE TABLE IF NOT EXISTS profiles '
                         '(radio_id TEXT PRIMARY KEY, callsign TEXT NOT NULL, '
                         'metadata_json TEXT NOT NULL, fetched_at INTEGER NOT NULL, '
                         'source TEXT NOT NULL)')
            conn.execute('CREATE INDEX IF NOT EXISTS idx_profiles_callsign ON profiles(callsign)')
            conn.execute('INSERT INTO profiles(radio_id,callsign,metadata_json,fetched_at,source) '
                         'VALUES (?,?,?,?,?) ON CONFLICT(radio_id) DO UPDATE SET '
                         'callsign=excluded.callsign,metadata_json=excluded.metadata_json,'
                         'fetched_at=excluded.fetched_at,source=excluded.source',
                         (rid, call, data, int(time.time()), 'RadioID.net/api/users'))
            conn.execute('DELETE FROM profiles WHERE fetched_at < ?',
                         (int(time.time()) - 730*86400,))
        return {'ok': True, 'radio_id': rid, 'callsign': call, 'stored_fields': len(payload)}
    finally:
        conn.close()

def fetch_verified(rid, call):
    if not re.fullmatch(r'\d{7}',rid) or not re.fullmatch(r'[A-Z0-9]{3,8}',call):
        raise ValueError('invalid lookup arguments')
    params = urllib.parse.urlencode({'id':rid,'id_sel':'=','page':1,'per_page':10})
    req = urllib.request.Request('https://radioid.net/api/users?'+params,
        headers={'Accept':'application/json',
                 'User-Agent':'XLX026-RadioID-Profile/1.0 (+https://xlx026.net)'})
    with urllib.request.urlopen(req,timeout=6) as response:
        data=json.load(response)
    records=data.get('results',[])
    matching=[r for r in records if isinstance(r,dict)
              and str(r.get('radio_id',r.get('id','')))==rid
              and str(r.get('callsign','')).strip().upper()==call]
    if len(matching)!=1:
        raise ValueError('official ID/callsign pair not unique')
    return matching[0]

def main(args):
    if len(args)!=3 or args[0]!='--lookup':
        raise ValueError('expected --lookup ID CALLSIGN')
    rid=args[1];call=args[2].upper()
    result=store_profile(fetch_verified(rid,call))
    print(json.dumps(result,separators=(',',':')))
    return 0

if __name__=='__main__':
    try:raise SystemExit(main(sys.argv[1:]))
    except Exception as exc:
        print('RadioID profile save unavailable: '+type(exc).__name__,file=sys.stderr)
        raise SystemExit(1)
