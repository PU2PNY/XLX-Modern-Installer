#!/usr/bin/env python3
"""Verify and restore a private archive into an empty staging directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import sqlite3
import tarfile

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--archive', required=True, type=Path)
    p.add_argument('--destination', required=True, type=Path)
    a = p.parse_args()
    os.umask(0o077)
    expected = a.archive.with_name(a.archive.name + '.sha256').read_text().split()[0]
    if digest(a.archive) != expected: p.error('archive SHA-256 mismatch')
    target = a.destination.resolve()
    if target == Path('/') or (target.exists() and any(target.iterdir())):
        p.error('destination must be empty and cannot be the running server root')
    target.mkdir(parents=True, exist_ok=True); target.chmod(0o700)
    with tarfile.open(a.archive, 'r:gz') as tar:
        members = tar.getmembers()
        seen = set()
        links = []
        for item in members:
            path = PurePosixPath(item.name)
            if path.is_absolute() or '..' in path.parts or item.name in seen:
                p.error('unsafe archive path or duplicate entry')
            seen.add(item.name)
            if not (item.isdir() or item.isfile() or item.issym()): p.error('unsupported archive member')
            if item.issym(): links.append(item)
        # Extract real data before links, so no archive symlink can redirect a write.
        for item in members:
            if item.issym(): continue
            dest = target / item.name
            if not dest.resolve().is_relative_to(target): p.error('archive escape')
            if item.isdir(): dest.mkdir(parents=True, exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                with tar.extractfile(item) as src, dest.open('xb') as out:
                    while block := src.read(1024 * 1024): out.write(block)
                dest.chmod(item.mode & 0o777)
        for item in links:
            dest = target / item.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.symlink_to(item.linkname)
    # Preserve the tar metadata required by service accounts after extraction.
    # Top-level staging stays private; member paths retain original ownership.
    for item in reversed(members):
        dest = target / item.name
        if os.geteuid() == 0:
            os.chown(dest, item.uid, item.gid, follow_symlinks=False)
        if item.isdir(): dest.chmod(item.mode & 0o777)
    manifest = json.loads((target / 'recovery-manifest.json').read_text())
    for rel, info in manifest['files'].items():
        f = target / rel
        if 'sha256' in info and digest(f) != info['sha256']: p.error('restored checksum mismatch: ' + rel)
        if 'link' in info and os.readlink(f) != info['link']: p.error('restored link mismatch')
    for rel in manifest['sqlite_snapshots']:
        with sqlite3.connect((target / rel).as_uri() + '?mode=ro', uri=True) as db:
            if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok': p.error('restored SQLite corrupt')
    print(json.dumps({'restore': 'PASS', 'destination': str(target),
                      'files_verified': len(manifest['files']),
                      'sqlite_verified': len(manifest['sqlite_snapshots'])}))

if __name__ == '__main__': main()
