#!/usr/bin/env bash
# Basic checks run in CI before building the image.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

echo "== FiveStep smoke checks =="
check "index.html exists"        "[ -f '$ROOT/src/index.html' ]"
check "index.html has <html>"    "grep -qi '<html' '$ROOT/src/index.html'"
check "app title present"        "grep -q 'FiveStep' '$ROOT/src/index.html'"
check "nginx config exists"      "[ -f '$ROOT/nginx/default.conf' ]"
check "nginx listens on 8080"    "grep -q 'listen .*8080' '$ROOT/nginx/default.conf'"
check "healthz endpoint defined" "grep -q '/healthz' '$ROOT/nginx/default.conf'"
check "Dockerfile exists"        "[ -f '$ROOT/Dockerfile' ]"
echo "== done =="
exit $fail
