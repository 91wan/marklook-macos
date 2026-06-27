#!/usr/bin/env bash
set -euo pipefail

qlmanage -r
qlmanage -r cache
killall Finder || true
