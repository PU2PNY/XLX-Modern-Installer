#!/usr/bin/env python3
"""Persist one externally verified RadioID record without rebuilding all users.

Uses the same lock as the administrative helper. The caller verifies the API
identity; this module rejects conflicting local identities and empty fields.
Real registries and backup contents must never be committed to Git.
"""
import csv
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import tempfile
import time
import unicodedata

CSV = '/xlxd/users_db/users_base.csv'
DB = '/xlxd/users_db/users.db'
LOCK = '/run/lock/xlx026-radioid-control.lock'
BACKUPS = '/root/backups-xlx026/radioid-control/delta'


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as source:
        for chunk in iter(lambda: source.read(262144), b''):
            h.update(chunk)
    return h.hexdigest()


def _copy_atomic(source, target, stat):
    fd, tmp = tempfile.mkstemp(prefix='.radioid-restore-', dir=Path(target).parent)
    os.close(fd)
    try:
        shutil.copyfile(source, tmp)
        os.chmod(tmp, stat.st_mode & 0o777)
        os.chown(tmp, stat.st_uid, stat.st_gid)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def location(city, state):
    names = ['Acre','Alagoas','Amapa','Amazonas','Bahia','Ceara','Distrito Federal',
             'Espirito Santo','Goias','Maranhao','Mato Grosso','Mato Grosso do Sul',
             'Minas Gerais','Para','Paraiba','Parana','Pernambuco','Piaui',
             'Rio de Janeiro','Rio Grande do Norte','Rio Grande do Sul','Rondonia',
             'Roraima','Santa Catarina','Sao Paulo','Sergipe','Tocantins']
    codes = 'AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO'.split()
    normalized = ''.join(c for c in unicodedata.normalize('NFKD', state) if not unicodedata.combining(c))
    state = dict(zip(names, codes)).get(normalized, state)
    return city + ', ' + state


def save_verified(row, csv_path=CSV, db_path=DB, lock_path=LOCK, backup_dir=BACKUPS):
    rid = str(row.get('radio_id', row.get('id', '')))
    call = str(row.get('callsign', '')).strip().upper()
    if not re.fullmatch(r'\d{7}', rid) or not re.fullmatch(r'[A-Z0-9]{3,8}', call):
        raise ValueError('invalid verified identity')
    values = [str(row.get(k) or '').strip() for k in ('fname','surname','city','state','country')]
    values[0] = values[0] or str(row.get('name') or '').strip()
    if not all(values[i] for i in (0, 2, 3, 4)):
        raise ValueError('required RadioID fields unavailable')
    if any(len(v) > 80 or any(c in v for c in ',\r\n') for v in values):
        raise ValueError('invalid RadioID text')
    csv_path, db_path = Path(csv_path), Path(db_path)
    with open(lock_path, 'a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        csv_stat, db_stat = csv_path.stat(), db_path.stat()
        hashes = {'csv': digest(csv_path), 'db': digest(db_path)}
        os.makedirs(backup_dir, mode=0o700, exist_ok=True)
        backup = Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%d_%H%M%S_'), dir=backup_dir))
        os.chmod(backup, 0o700)
        shutil.copy2(csv_path, backup/'users_base.csv.before')
        shutil.copy2(db_path, backup/'users.db.before')
        if digest(backup/'users_base.csv.before') != hashes['csv'] or digest(backup/'users.db.before') != hashes['db']:
            raise RuntimeError('backup verification failed')
        manifest = {'before': hashes, 'status': 'prepared'}
        (backup/'manifest.json').write_text(json.dumps(manifest))
        csv_tmp = db_tmp = None
        touched = False
        try:
            fd, csv_tmp = tempfile.mkstemp(prefix='.radioid-delta-', dir=csv_path.parent)
            found_id = 0
            with os.fdopen(fd, 'w', encoding='utf-8', newline='') as target, open(csv_path, encoding='utf-8', newline='') as source:
                header = source.readline()
                if not header:
                    raise ValueError('empty registry')
                newline = '\r\n' if header.endswith('\r\n') else '\n'
                buffer = io.StringIO(newline='')
                csv.writer(buffer, lineterminator=newline).writerow([rid, call, *values])
                target.write(header)
                last_line = header
                for line in source:
                    parsed = next(csv.reader([line]))
                    if len(parsed) >= 7 and parsed[0].strip() == rid:
                        if parsed[1].strip().upper() != call:
                            raise ValueError('ID belongs to a different local callsign')
                        found_id += 1
                        target.write(buffer.getvalue())
                    else:
                        target.write(line)
                    last_line = line
                if found_id > 1:
                    raise ValueError('duplicate RadioID rows')
                if not found_id:
                    if not last_line.endswith(('\n', '\r')):
                        target.write(newline)
                    target.write(buffer.getvalue())
                target.flush()
                os.fsync(target.fileno())
            fd, db_tmp = tempfile.mkstemp(prefix='.radioid-db-', dir=db_path.parent)
            os.close(fd)
            shutil.copyfile(backup/'users.db.before', db_tmp)
            with sqlite3.connect(db_tmp, timeout=2) as db:
                if db.execute('PRAGMA journal_mode').fetchone()[0] != 'delete':
                    raise RuntimeError('unsupported registry journal mode')
                if [r[1] for r in db.execute('PRAGMA table_info(users)')] != ['callsign', 'name', 'city_state']:
                    raise RuntimeError('unexpected users schema')
                count = db.execute('SELECT COUNT(*) FROM users').fetchone()[0]
                existed = db.execute('SELECT 1 FROM users WHERE callsign=?', (call,)).fetchone() is not None
                db.execute('INSERT INTO users(callsign,name,city_state) VALUES(?,?,?) '
                           'ON CONFLICT(callsign) DO UPDATE SET name=excluded.name,city_state=excluded.city_state',
                           (call, ' '.join(v for v in values[:2] if v), location(values[2], values[3])))
                db.commit()
                if db.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
                    raise RuntimeError('candidate integrity failed')
                if db.execute('SELECT COUNT(*) FROM users').fetchone()[0] != count + (not existed):
                    raise RuntimeError('unexpected row count')
            if digest(csv_path) != hashes['csv'] or digest(db_path) != hashes['db']:
                raise RuntimeError('registry changed during staging')
            for tmp, stat in ((csv_tmp, csv_stat), (db_tmp, db_stat)):
                os.chmod(tmp, stat.st_mode & 0o777)
                os.chown(tmp, stat.st_uid, stat.st_gid)
                with open(tmp, 'rb') as prepared:
                    os.fsync(prepared.fileno())
            touched = True
            os.replace(csv_tmp, csv_path)
            os.replace(db_tmp, db_path)
            manifest.update(status='committed', after={'csv': digest(csv_path), 'db': digest(db_path)})
            (backup/'manifest.json').write_text(json.dumps(manifest))
            # Cap only this helper's private backup subdirectory.
            snapshots = sorted(p for p in Path(backup_dir).iterdir() if p.is_dir() and re.fullmatch(r'\d{8}_\d{6}_.+', p.name))
            for old in snapshots[:-16]:
                try:
                    shutil.rmtree(old)
                except OSError:
                    pass  # Retention failure must not undo a verified registry save.
            return {'ok': True, 'callsign': call, 'radio_id': rid, 'backup': str(backup)}
        except BaseException:
            if touched:
                _copy_atomic(backup/'users_base.csv.before', csv_path, csv_stat)
                _copy_atomic(backup/'users.db.before', db_path, db_stat)
                manifest['status'] = 'rolled_back'
                (backup/'manifest.json').write_text(json.dumps(manifest))
            raise
        finally:
            for tmp in (csv_tmp, db_tmp):
                if tmp and os.path.exists(tmp):
                    os.unlink(tmp)
