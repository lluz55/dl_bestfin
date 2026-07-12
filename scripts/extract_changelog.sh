#!/usr/bin/env bash
# extract_changelog.sh — Extrai uma seção do CHANGELOG.md pelo header "## <target>".
#
# Usado por scripts/release.sh (localmente, antes do commit) e pelo job
# `release` do workflow .github/workflows/release.yml (no runner, já que o
# CHANGELOG.md no commit taggeado sempre tem a seção "## vX.Y.Z" — o rename
# de "## Unreleased" já aconteceu localmente antes do push).
#
# Uso:
#   ./scripts/extract_changelog.sh <target> [changelog-file]
#
# <target> é o segundo campo do header (ex: "v1.0.10" ou "Unreleased"),
# ignorando o resto da linha (ex: a data entre parênteses).
#
# Saída: conteúdo da seção (stdout), sem linhas em branco no início/fim.
# Sai com status 1 (sem saída) se a seção não existir ou estiver vazia.

set -euo pipefail

target="${1:?Uso: $0 <target> [changelog-file]}"
file="${2:-CHANGELOG.md}"

[[ -f "$file" ]] || { echo "extract_changelog.sh: arquivo não encontrado: $file" >&2; exit 1; }

section=$(awk -v target="$target" '
  /^## / {
    if (found) exit
    if ($2 == target) { found = 1; next }
  }
  found { print }
' "$file" | sed -e '/./,$!d' | sed -e ':a' -e '/^[[:space:]]*$/{$d;N;ba' -e '}')

[[ -n "$section" ]] || exit 1

printf '%s\n' "$section"
