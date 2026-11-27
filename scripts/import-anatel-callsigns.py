#!/usr/bin/env python3
"""Import only the public lookup fields from Anatel's Radioamador CSV/ZIP.

No raw registry, CPF/CNPJ, Fistel or station identifiers enter the database.
The output is installed atomically; callers retain their previous snapshot.
"""
import argparse
import csv
import datetime
import hashlib
import gzip
import io
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import unicodedata
import zipfile

FIELDS = ['Indicativo', 'Nome da Entidade', 'COER', 'Tipo de Estação',
          'Município da Estação', 'UF da Estação', 'UF da Entidade',
          'Data do Último Licenciamento', 'Data de Validade da Estação', 'Status da Validade']
UFS = set('AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO'.split())


def clean(value):
    value = (value or '').strip()
    return '' if value.upper() in ('N/I', 'N/A', 'NI', 'NA', 'NULL') else value


def normalized(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', value) if not unicodedata.combining(c)).upper()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source', type=Path)
    ap.add_argument('output', type=Path)
    ap.add_argument('--original-source-sha256', default='')
    args = ap.parse_args()
    archive_date = ''
    if zipfile.is_zipfile(args.source):
        with zipfile.ZipFile(args.source) as archive:
            info = archive.getinfo('Estacoes_Radioamador.csv')
            if info.file_size > 100_000_000:
                raise ValueError('Radioamador CSV exceeds 100 MB limit')
            raw = archive.read(info)
            archive_date = datetime.datetime(*info.date_time).isoformat()
    else:
        if args.source.stat().st_size > 100_000_000:
            raise ValueError('CSV exceeds 100 MB limit')
        if args.source.suffix == '.gz':
            with gzip.open(args.source, 'rb') as stream:
                raw = stream.read(100_000_001)
            if len(raw) > 100_000_000:
                raise ValueError('Decompressed CSV exceeds 100 MB limit')
        else:
            raw = args.source.read_bytes()
    reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')), delimiter=';')
    if not set(FIELDS).issubset(reader.fieldnames or []):
        raise ValueError('Unexpected Anatel Radioamador schema')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.callsigns-', suffix='.sqlite', dir=args.output.parent)
    os.close(fd)
    try:
        db = sqlite3.connect(tmp)
        db.execute('CREATE TABLE stations (callsign TEXT NOT NULL, holder TEXT, class TEXT, type TEXT, city TEXT, station_uf TEXT, holder_uf TEXT, licensed TEXT, expires TEXT, validity TEXT, search TEXT)')
        count = 0
        for row in reader:
            if row.get('Serviço') != 'Radioamador':
                raise ValueError('Unexpected service')
            values = [clean(row[k]) for k in FIELDS]
            values[0] = values[0].upper()
            if len(values[0]) > 32:
                raise ValueError('Invalid callsign')
            for idx in (5, 6):
                values[idx] = values[idx].upper()
                if values[idx] not in UFS:
                    values[idx] = ''
            values.append(normalized(' '.join(values[:5])))
            db.execute('INSERT INTO stations VALUES (?,?,?,?,?,?,?,?,?,?,?)', values)
            count += 1
        if count == 0:
            raise ValueError('Empty registry rejected')
        db.execute("CREATE INDEX station_callsign ON stations((callsign=''),callsign,type,city)")
        db.execute('CREATE INDEX station_holder_uf ON stations(holder_uf,callsign)')
        db.execute('CREATE INDEX station_class ON stations(class,callsign)')
        db.execute('CREATE INDEX station_type ON stations(type,callsign)')
        distinct = db.execute("SELECT COUNT(DISTINCT callsign) FROM stations WHERE callsign<>''").fetchone()[0]
        meta = dict(schema_version=1, rows=count, callsigns=distinct,
                    missing_callsigns=db.execute("SELECT COUNT(*) FROM stations WHERE callsign=''").fetchone()[0],
                    imported_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    archive_member_timestamp=archive_date,
                    source_filename='Estacoes_Radioamador.csv', source_sha256=hashlib.sha256(raw).hexdigest(),
                    original_source_sha256=args.original_source_sha256,
                    source_url='https://informacoes.anatel.gov.br/paineis/outorga-e-licenciamento/estacoes-radioamador')
        db.execute('CREATE TABLE metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL)')
        db.executemany('INSERT INTO metadata VALUES (?,?)', [(k, str(v)) for k, v in meta.items()])
        db.commit()
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        db.close()
        os.chmod(tmp, 0o640)
        os.replace(tmp, args.output)
        print(json.dumps(meta, ensure_ascii=False))
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


if __name__ == '__main__':
    main()
