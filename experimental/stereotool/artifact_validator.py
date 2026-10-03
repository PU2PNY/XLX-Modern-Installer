#!/usr/bin/env python3
"""Static validator for administrator-supplied Stereo Tool Linux artifacts.

LAB-ONLY foundation. The validator never dlopen()s or executes the supplied
library. It inspects ZIP structure and ELF metadata, and returns JSON.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

MAX_PACKAGE_BYTES = 256 * 1024 * 1024
MAX_UNPACKED_BYTES = 1024 * 1024 * 1024
MAX_FILES = 2000
REQUIRED_SYMBOLS = (
    "stereoTool_GetSoftwareVersion",
    "stereoTool_GetApiVersion",
)
MIN_GLIBC = (2, 27)
EXPECTED_MACHINES = {
    "x86_64": "Advanced Micro Devices X86-64",
    "amd64": "Advanced Micro Devices X86-64",
    "aarch64": "AArch64",
    "arm64": "AArch64",
}


class ValidationError(RuntimeError):
    pass


def run_checked(args: list[str]) -> str:
    try:
        proc = subprocess.run(
            args,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        raise ValidationError(f"required inspection tool failed: {args[0]}: {exc}") from exc
    if proc.returncode != 0:
        msg = (proc.stderr or proc.stdout).strip().splitlines()[:3]
        raise ValidationError(f"{' '.join(args)} failed: {' | '.join(msg)}")
    return proc.stdout


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_glibc_version(text: str) -> tuple[int, int]:
    match = re.search(r"glibc\s+(\d+)\.(\d+)", text, re.IGNORECASE)
    if not match:
        raise ValidationError("could not determine host glibc version")
    return int(match.group(1)), int(match.group(2))


def host_glibc() -> tuple[int, int]:
    return parse_glibc_version(run_checked(["getconf", "GNU_LIBC_VERSION"]))


def max_required_glibc(version_info: str) -> tuple[int, int] | None:
    versions = {
        (int(a), int(b))
        for a, b in re.findall(r"GLIBC_(\d+)\.(\d+)", version_info)
    }
    return max(versions) if versions else None


def parse_elf_header(header: str) -> tuple[str, str]:
    elf_class = ""
    machine = ""
    for raw in header.splitlines():
        line = raw.strip()
        if line.startswith("Class:"):
            elf_class = line.split(":", 1)[1].strip()
        elif line.startswith("Machine:"):
            machine = line.split(":", 1)[1].strip()
    if not elf_class or not machine:
        raise ValidationError("incomplete ELF header")
    return elf_class, machine


def inspect_elf(path: Path, expected_arch: str | None = None) -> dict[str, Any]:
    if not path.is_file() or path.is_symlink():
        raise ValidationError("ELF candidate must be a regular non-symlink file")
    if path.stat().st_size > MAX_PACKAGE_BYTES:
        raise ValidationError("ELF candidate exceeds package size limit")

    header = run_checked(["readelf", "-h", str(path)])
    version_info = run_checked(["readelf", "-V", str(path)])
    symbols = run_checked(["readelf", "-Ws", str(path)])
    elf_class, machine = parse_elf_header(header)

    if elf_class != "ELF64":
        raise ValidationError(f"unsupported ELF class: {elf_class}")

    arch = (expected_arch or platform.machine()).lower()
    expected_machine = EXPECTED_MACHINES.get(arch)
    if expected_machine is None:
        raise ValidationError(f"unsupported host/expected architecture: {arch}")
    if machine != expected_machine:
        raise ValidationError(f"architecture mismatch: expected {expected_machine}, got {machine}")

    missing = [name for name in REQUIRED_SYMBOLS if name not in symbols]
    if missing:
        raise ValidationError("missing required identity symbol(s): " + ", ".join(missing))

    host_version = host_glibc()
    if host_version < MIN_GLIBC:
        raise ValidationError(
            f"host glibc {host_version[0]}.{host_version[1]} is below required minimum 2.27"
        )
    required = max_required_glibc(version_info)
    if required is not None and required > host_version:
        raise ValidationError(
            "artifact requires GLIBC_"
            f"{required[0]}.{required[1]}, host provides {host_version[0]}.{host_version[1]}"
        )

    return {
        "sha256": sha256_file(path),
        "size_bytes": path.stat().st_size,
        "elf_class": elf_class,
        "machine": machine,
        "host_arch": arch,
        "host_glibc": f"{host_version[0]}.{host_version[1]}",
        "max_required_glibc": (
            f"{required[0]}.{required[1]}" if required is not None else None
        ),
        "required_identity_symbols": list(REQUIRED_SYMBOLS),
    }


def validate_zip_member(info: zipfile.ZipInfo) -> None:
    name = info.filename.replace("\\", "/")
    pure = PurePosixPath(name)
    if pure.is_absolute() or ".." in pure.parts:
        raise ValidationError(f"unsafe ZIP path: {name}")
    if not pure.parts or pure.parts[0] in ("", "."):
        raise ValidationError(f"invalid ZIP path: {name}")

    mode = (info.external_attr >> 16) & 0xFFFF
    if mode:
        file_type = stat.S_IFMT(mode)
        if file_type == stat.S_IFLNK:
            raise ValidationError(f"ZIP symlink is not allowed: {name}")
        if file_type in {
            stat.S_IFCHR,
            stat.S_IFBLK,
            stat.S_IFIFO,
            stat.S_IFSOCK,
        }:
            raise ValidationError(f"ZIP special file is not allowed: {name}")


def safe_extract_zip(package: Path, destination: Path) -> list[Path]:
    try:
        archive = zipfile.ZipFile(package)
    except zipfile.BadZipFile as exc:
        raise ValidationError("invalid ZIP package") from exc

    with archive:
        infos = archive.infolist()
        if len(infos) > MAX_FILES:
            raise ValidationError(f"ZIP contains too many entries: {len(infos)} > {MAX_FILES}")
        total = sum(info.file_size for info in infos)
        if total > MAX_UNPACKED_BYTES:
            raise ValidationError(
                f"ZIP uncompressed size exceeds limit: {total} > {MAX_UNPACKED_BYTES}"
            )
        for info in infos:
            validate_zip_member(info)

        extracted: list[Path] = []
        root = destination.resolve()
        for info in infos:
            if info.is_dir():
                continue
            rel = PurePosixPath(info.filename.replace("\\", "/"))
            out = destination.joinpath(*rel.parts)
            out.parent.mkdir(parents=True, exist_ok=True)
            resolved_parent = out.parent.resolve()
            if os.path.commonpath([str(root), str(resolved_parent)]) != str(root):
                raise ValidationError(f"ZIP extraction escaped quarantine: {info.filename}")
            with archive.open(info, "r") as src, out.open("wb") as dst:
                shutil.copyfileobj(src, dst, length=1024 * 1024)
            os.chmod(out, 0o600)
            extracted.append(out)
        return extracted


def validate_artifact(path: Path, expected_arch: str | None) -> dict[str, Any]:
    if not path.exists() or not path.is_file() or path.is_symlink():
        raise ValidationError("artifact must be an existing regular non-symlink file")
    if path.stat().st_size > MAX_PACKAGE_BYTES:
        raise ValidationError(
            f"package exceeds {MAX_PACKAGE_BYTES // (1024 * 1024)} MiB limit"
        )

    package_sha = sha256_file(path)
    if zipfile.is_zipfile(path):
        with tempfile.TemporaryDirectory(prefix="xlx-stereotool-quarantine-") as tmp:
            files = safe_extract_zip(path, Path(tmp))
            candidates = [p for p in files if ".so" in p.name]
            valid: list[tuple[Path, dict[str, Any]]] = []
            errors: list[str] = []
            for candidate in candidates:
                try:
                    valid.append((candidate, inspect_elf(candidate, expected_arch)))
                except ValidationError as exc:
                    errors.append(f"{candidate.name}: {exc}")
            if len(valid) != 1:
                detail = "; ".join(errors[:8]) if errors else "no shared-library candidates"
                raise ValidationError(
                    f"expected exactly one valid Stereo Tool library, found {len(valid)}; {detail}"
                )
            candidate, elf = valid[0]
            return {
                "status": "READY_FOR_SANDBOX",
                "artifact_kind": "zip",
                "package_sha256": package_sha,
                "candidate_basename": candidate.name,
                "elf": elf,
            }

    elf = inspect_elf(path, expected_arch)
    return {
        "status": "READY_FOR_SANDBOX",
        "artifact_kind": "shared_library",
        "package_sha256": package_sha,
        "candidate_basename": path.name,
        "elf": elf,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument(
        "--expected-arch",
        choices=("x86_64", "aarch64"),
        default=None,
        help="override host architecture for static validation",
    )
    args = parser.parse_args()

    try:
        result = validate_artifact(args.artifact, args.expected_arch)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except ValidationError as exc:
        print(
            json.dumps(
                {"status": "REJECTED", "reason": str(exc)},
                indent=2,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
