#!/usr/bin/env bash
# release.sh — Automatiza o fluxo completo de release do BestFin.
#
# O que faz:
#   1. Valida pré-condições (git limpo, env vars presentes)
#   2. Faz bump de versão em pubspec.yaml e app_info.dart
#   3. Cria commit + tag vX.Y.Z e faz push
#   4. Compila APK Android e bundle Linux via nix develop
#   5. Empacota o bundle Linux em .tar.gz
#   6. Cria o GitHub Release e anexa os binários
#   7. Publica o evento de atualização nos relays Nostr
#
# Uso:
#   BESTFIN_DEV_NOSTR_PRIVKEY=<hex> ./scripts/release.sh <versão> [opções]
#
# Argumentos:
#   <versão>              Versão no formato X.Y.Z (obrigatório)
#
# Opções:
#   --changelog <texto>      Notas de release (padrão: "Release vX.Y.Z")
#   --critical               Marca como atualização crítica (banner vermelho no app)
#   --nostr-key-file <path>  Lê a chave Nostr (hex) do arquivo em vez da env var
#   --skip-build             Pula a compilação (útil se os binários já existem)
#   --skip-nostr             Pula a publicação Nostr
#   --dry-run                Imprime os passos sem executar nada destrutivo
#
# Pré-requisitos:
#   - BESTFIN_DEV_NOSTR_PRIVKEY exportada no ambiente (valor hex ou caminho de
#     arquivo contendo a chave), ou use --nostr-key-file / --skip-nostr
#   - android/key.properties e android/bestfin-release.jks presentes (APK assinado)
#   - gh CLI autenticado (gh auth login)
#   - git configurado com acesso de push
#
# Exemplo:
#   BESTFIN_DEV_NOSTR_PRIVKEY=abc123 ./scripts/release.sh 1.1.0 \
#     --changelog "Melhoria de performance e correções de bugs"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo "[release] $*"; }
ok()    { echo "[release] ✓ $*"; }
err()   { echo "[release] ✗ $*" >&2; exit 1; }
step()  { echo; echo "══ $* ══"; }

dry_run=false
run() {
  if $dry_run; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# ── Parse arguments ───────────────────────────────────────────────────────────

VERSION=""
CHANGELOG=""
CRITICAL=false
SKIP_BUILD=false
SKIP_NOSTR=false
NOSTR_KEY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changelog)      CHANGELOG="$2";      shift 2 ;;
    --critical)       CRITICAL=true;       shift ;;
    --nostr-key-file) NOSTR_KEY_FILE="$2"; shift 2 ;;
    --skip-build)     SKIP_BUILD=true;     shift ;;
    --skip-nostr)     SKIP_NOSTR=true;     shift ;;
    --dry-run)        dry_run=true;        shift ;;
    -*)            err "Opção desconhecida: $1" ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"; shift
      else
        err "Argumento inesperado: $1"
      fi
      ;;
  esac
done

[[ -n "$VERSION" ]] || err "Uso: $0 <versão> [opções]  (ex: $0 1.1.0 --changelog 'Novas funcionalidades')"

# Valida formato X.Y.Z
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "Versão inválida '$VERSION'. Use o formato X.Y.Z"

[[ -z "$CHANGELOG" ]] && CHANGELOG="Release v${VERSION}"

DOWNLOAD_URL="https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'owner/bestfin')/releases/tag/v${VERSION}"

APK_NAME="bestfin-v${VERSION}-android.apk"
LINUX_ARCHIVE="bestfin-v${VERSION}-linux-x64.tar.gz"
APK_SRC="build/app/outputs/flutter-apk/app-release.apk"

# ── Validações ────────────────────────────────────────────────────────────────

step "Validando pré-condições"

cd "$PROJECT_DIR"

# Git limpo
if ! $dry_run && [[ -n "$(git status --porcelain)" ]]; then
  err "Working tree sujo. Faça commit ou stash das alterações antes do release."
fi

# Chave Nostr do desenvolvedor
if ! $SKIP_NOSTR; then
  # Prioridade: --nostr-key-file > env var apontando para arquivo > env var literal
  if [[ -n "$NOSTR_KEY_FILE" ]]; then
    [[ -f "$NOSTR_KEY_FILE" ]] \
      || err "Arquivo da chave Nostr não encontrado: $NOSTR_KEY_FILE"
    BESTFIN_DEV_NOSTR_PRIVKEY="$(tr -d '[:space:]' < "$NOSTR_KEY_FILE")"
  elif [[ -f "${BESTFIN_DEV_NOSTR_PRIVKEY:-}" ]]; then
    # A env var contém um caminho de arquivo — lê a chave de dentro dele
    BESTFIN_DEV_NOSTR_PRIVKEY="$(tr -d '[:space:]' < "$BESTFIN_DEV_NOSTR_PRIVKEY")"
  fi
  export BESTFIN_DEV_NOSTR_PRIVKEY

  [[ -n "${BESTFIN_DEV_NOSTR_PRIVKEY:-}" ]] \
    || err "Chave Nostr não definida. Exporte BESTFIN_DEV_NOSTR_PRIVKEY (hex ou arquivo), use --nostr-key-file ou --skip-nostr."
fi

# Credenciais de assinatura Android
if ! $SKIP_BUILD; then
  [[ -f "android/key.properties" ]] \
    || err "android/key.properties não encontrado. Necessário para assinar o APK."
fi

# gh CLI
if ! command -v gh &>/dev/null; then
  err "gh CLI não encontrado. Instale em https://cli.github.com."
fi

ok "Pré-condições OK"

# ── Bump de versão ────────────────────────────────────────────────────────────

step "Atualizando versão para ${VERSION}"

# Lê build number atual e incrementa
CURRENT_BUILD=$(grep '^version:' pubspec.yaml | grep -oP '\+\K[0-9]+' || echo "0")
NEW_BUILD=$((CURRENT_BUILD + 1))

info "pubspec.yaml: version → ${VERSION}+${NEW_BUILD}"
run sed -i "s/^version:.*/version: ${VERSION}+${NEW_BUILD}/" pubspec.yaml

info "app_info.dart: kAppVersion → '${VERSION}'"
run sed -i "s/const String kAppVersion = '.*'/const String kAppVersion = '${VERSION}'/" \
  lib/core/constants/app_info.dart

ok "Versão atualizada"

# ── Commit + tag ──────────────────────────────────────────────────────────────

step "Commit e tag v${VERSION}"

run git add pubspec.yaml lib/core/constants/app_info.dart
run git commit -m "chore(release): bump version para v${VERSION}"
run git tag "v${VERSION}"
run git push origin HEAD "v${VERSION}"

ok "Commit e tag publicados"

# ── Build ─────────────────────────────────────────────────────────────────────

if $SKIP_BUILD; then
  info "Build pulado (--skip-build)"
  [[ -f "$APK_SRC" ]] || err "APK não encontrado em $APK_SRC. Compile antes de usar --skip-build."
else
  step "Compilando Android APK"
  run nix develop -c flutter build apk --release
  ok "APK gerado em $APK_SRC"

  step "Compilando Linux bundle"
  run nix develop -c flutter build linux --release
  ok "Bundle Linux gerado em build/linux/x64/release/bundle/"
fi

# ── Empacotar Linux ───────────────────────────────────────────────────────────

step "Empacotando bundle Linux"
run tar -czf "$LINUX_ARCHIVE" -C build/linux/x64/release/bundle .
ok "Arquivo: $LINUX_ARCHIVE"

# ── GitHub Release ───────────────────────────────────────────────────────────

step "Criando GitHub Release v${VERSION}"

CRITICAL_NOTE=""
$CRITICAL && CRITICAL_NOTE=$'\n\n> **Atualização crítica:** recomenda-se atualizar o mais breve possível.'

run gh release create "v${VERSION}" \
  --title "BestFin v${VERSION}" \
  --notes "${CHANGELOG}${CRITICAL_NOTE}" \
  "${APK_SRC}#${APK_NAME}" \
  "${LINUX_ARCHIVE}#${LINUX_ARCHIVE}"

ok "Release criado: ${DOWNLOAD_URL}"

# ── Publicar no Nostr ─────────────────────────────────────────────────────────

if $SKIP_NOSTR; then
  info "Publicação Nostr pulada (--skip-nostr)"
else
  step "Publicando notificação de atualização via Nostr"

  NOSTR_ARGS=(--version "$VERSION" --changelog "$CHANGELOG" --download-url "$DOWNLOAD_URL")
  $CRITICAL && NOSTR_ARGS+=(--critical)

  run nix develop -c dart run scripts/publish_update.dart "${NOSTR_ARGS[@]}"
  ok "Notificação Nostr publicada"
fi

# ── Concluído ─────────────────────────────────────────────────────────────────

echo
echo "══════════════════════════════════════════"
echo "  Release v${VERSION} concluído com sucesso!"
$dry_run && echo "  (simulação — nenhuma ação foi executada)"
echo "══════════════════════════════════════════"
