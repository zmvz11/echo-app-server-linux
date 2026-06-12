#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/release"
rm -f "$ROOT/release"/*
tar --exclude='./node_modules' --exclude='./dist' --exclude='./release' --exclude='./data' --exclude='./.git' --exclude='./.env' \
  -czf "$ROOT/release/Echo-App-Server-Linux-Source.tar.gz" -C "$ROOT" .
echo "Created $ROOT/release/Echo-App-Server-Linux-Source.tar.gz"
