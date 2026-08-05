#!/usr/bin/env bash
die(){ printf '\033[31m%s:\033[0m %s\n' "${MSG_ERROR:-ERROR}" "$*" >&2; exit 1; }
warn(){ printf '\033[33m%s:\033[0m %s\n' "${MSG_WARNING:-WARNING}" "$*"; }
success(){ printf '\033[32m%s:\033[0m %s\n' "${MSG_OK:-OK}" "$*"; }
require_root(){ [ "$(id -u)" -eq 0 ] || die "${MSG_ROOT_REQUIRED:-Root privileges are required.}"; }
development_lock(){ warn "${MSG_DEVELOPMENT_LOCK:-This module is disabled during development.}"; return 20; }
