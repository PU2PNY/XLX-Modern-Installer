#!/usr/bin/env python3
"""Private recovery archive. Never publish its output in a source repository."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tarfile
import tempfile
import time

STATIC = ['/xlxd', '/var/www/html', '/etc/nginx', '/etc/php',
          '/etc/letsencrypt', '/etc/systemd/system', '/etc/cron.d',
          '/etc/crontab', '/etc/logrotate.d', '/etc/ufw', '/etc/nftables.conf',
          '/etc/passwd', '/etc/group',
          '/usr/src/xlxd', '/usr/local/lib/xlx-modern']
PATTERNS = {'/etc': ['xlx*', 'helix*'], '/var/lib': ['xlx*', 'helix*'],
            '/opt': ['xlx*', 'helix-voice'],
            '/usr/local/bin': ['xlx*', 'xuv*'],
            '/usr/local/sbin': ['xlx*'], '/usr/local/lib': ['xlx*']}
EXCLUDE_PARTS = {'backups', '.git', '__pycache__', 'node_modules', 'target'}
EXCLUDE_SUFFIXES = ('.pcap', '.pcapng', '.bak', '.tgz', '.tar.gz', '-wal', '-shm')

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()

def discover(root):
    roots = [root / p.lstrip('/') for p in STATIC]
    for directory, patterns in PATTERNS.items():
        for pattern in patterns: roots.extend((root / directory.lstrip('/')).glob(pattern))
    files = {}
    def visit(p):
        rel = p.relative_to(root).as_posix()
        if (any(x in EXCLUDE_PARTS or 'backup' in x.lower() or '.old.' in x
                or '-lab' in x or '-stage' in x or '-export' in x for x in p.relative_to(root).parts)
                or p.name.endswith(EXCLUDE_SUFFIXES)): return
        if p.is_symlink(): files[rel] = p
        elif p.is_dir():
            files[rel] = p
            for item in sorted(p.iterdir()): visit(item)
        elif p.is_file(): files[rel] = p
    for p in roots:
        if p.exists() or p.is_symlink(): visit(p)
    return files

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--root', default='/', type=Path, help='fixture root; defaults to this server')
    args = parser.parse_args()
    os.umask(0o077)
    root = args.root.resolve()
    if root == Path('/') and os.geteuid() != 0: parser.error('root privileges required')
    output = args.output.resolve()
    if output.exists(): parser.error('output already exists; refusing overwrite')
    output.parent.mkdir(parents=True, exist_ok=True)
    files = discover(root)
    if not any(p.endswith('xlxd') for p in files): parser.error('XLXD binary absent')
    manifest = {'format': 1, 'created_at': int(time.time()), 'files': {}, 'running': []}
    snapshots = []
    with tempfile.TemporaryDirectory(prefix='xlx-recovery-') as temp:
        with tarfile.open(output, 'x:gz') as tar:
            for rel, p in sorted(files.items()):
                source = p
                if p.is_file() and not p.is_symlink():
                    with p.open('rb') as f: sqlite = f.read(16) == b'SQLite format 3\x00'
                    if sqlite:
                        source = Path(temp) / str(len(snapshots))
                        with sqlite3.connect(p.as_uri() + '?mode=ro', uri=True, timeout=5) as db:
                            with sqlite3.connect(source) as dst:
                                db.backup(dst, pages=256, sleep=0.05)
                                if dst.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                                    raise RuntimeError('SQLite integrity check failed')
                        snapshots.append(rel)
                    manifest['files'][rel] = {'sha256': sha(source), 'mode': p.stat().st_mode & 0o7777}
                elif p.is_symlink(): manifest['files'][rel] = {'link': os.readlink(p)}
                info = tar.gettarinfo(str(p), arcname=rel)
                if p.is_file() and not p.is_symlink():
                    info.size = source.stat().st_size
                    with source.open('rb') as stream: tar.addfile(info, stream)
                else: tar.addfile(info)
            # /usr/src may be stale. Preserve the ELF actually executing, even
            # when it was replaced/unlinked, without restarting any service.
            if root == Path('/'):
                for proc in Path('/proc').glob('[0-9]*'):
                    try:
                        name = (proc / 'comm').read_text().strip()
                        if not (name.startswith(('xlx', 'xuv', 'helix'))): continue
                        exe = proc / 'exe'
                        original = os.readlink(exe).removesuffix(' (deleted)')
                        rel = 'recovery-running/' + name + '-' + proc.name
                        info = tar.gettarinfo(str(exe), arcname=rel)
                        info.type = tarfile.REGTYPE; info.linkname = ''; info.size = exe.stat().st_size
                        with exe.open('rb') as stream: tar.addfile(info, stream)
                        manifest['files'][rel] = {'sha256': sha(exe), 'mode': 0o755}
                        manifest['running'].append({'name': name, 'pid': int(proc.name),
                                                    'install_path': original, 'archive_path': rel})
                    except (FileNotFoundError, ProcessLookupError): continue
            manifest['sqlite_snapshots'] = snapshots
            data = json.dumps(manifest, ensure_ascii=False, indent=2).encode()
            info = tarfile.TarInfo('recovery-manifest.json'); info.size = len(data); info.mode = 0o600
            tar.addfile(info, io.BytesIO(data))
    output.chmod(0o600)
    digest = sha(output)
    output.with_name(output.name + '.sha256').write_text(digest + '  ' + output.name + '\n')
    print(json.dumps({'archive': str(output), 'sha256': digest,
                      'files': len(manifest['files']), 'sqlite_snapshots': len(snapshots),
                      'running_binaries': len(manifest['running'])}))

if __name__ == '__main__': main()
