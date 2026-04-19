#!/usr/bin/env bash
set -euo pipefail

info="$(glxinfo -B)"
printf '%s\n' "$info"

if grep -qi "llvmpipe" <<<"$info"; then
  printf 'GPU check failed: software renderer detected (llvmpipe).\n' >&2
  exit 1
fi

printf 'GPU check passed.\n'

