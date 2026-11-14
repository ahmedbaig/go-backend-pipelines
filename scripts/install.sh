#!/usr/bin/env bash
set -euo pipefail

REF="${PIPELINES_REF:-main}"
BASE="${PIPELINES_BASE:-https://raw.githubusercontent.com/ahmedbaig/go-backend-pipelines/$REF}"
TARGET="${1:-.}"
FORCE="${FORCE:-0}"

fetch() {
  local src="$1" dst="$2"
  if [ -e "$TARGET/$dst" ] && [ "$FORCE" != 1 ]; then
    echo "skip  $dst (exists, FORCE=1 to overwrite)"
    return
  fi
  mkdir -p "$(dirname "$TARGET/$dst")"
  local here
  here="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd || true)"
  if [ -n "$here" ] && [ -f "$here/$src" ] && [ -z "${PIPELINES_REMOTE:-}" ]; then
    cp "$here/$src" "$TARGET/$dst"
  else
    curl -fsSL "$BASE/$src" -o "$TARGET/$dst"
  fi
  echo "wrote $dst"
}

fetch docker/Dockerfile.go Dockerfile
fetch make/go.mk make/go.mk
fetch scripts/deploy.sh deploy.sh
chmod +x "$TARGET/deploy.sh"

if [ ! -f "$TARGET/.gitlab-ci.yml" ]; then
  cat > "$TARGET/.gitlab-ci.yml" <<EOF
include:
  - remote: '$BASE/gitlab/go.gitlab-ci.yml'
EOF
  echo "wrote .gitlab-ci.yml"
fi

if [ ! -f "$TARGET/.github/workflows/ci.yml" ]; then
  mkdir -p "$TARGET/.github/workflows"
  cat > "$TARGET/.github/workflows/ci.yml" <<EOF
name: ci
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
jobs:
  test:
    uses: ahmedbaig/go-backend-pipelines/.github/workflows/go-ci.yml@$REF
  docker:
    needs: test
    if: github.event_name == 'push'
    uses: ahmedbaig/go-backend-pipelines/.github/workflows/docker.yml@$REF
    permissions:
      contents: read
      packages: write
EOF
  echo "wrote .github/workflows/ci.yml"
fi
