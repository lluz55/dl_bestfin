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
#                         Ou use "patch", "minor" ou "major" para bump incremental
#                         (lê a versão atual de pubspec.yaml)
#
# Opções:
#   --changelog <texto>      Notas de release (sobrepõe o CHANGELOG.md)
#   --changelog-file <path>  Lê notas de release de um arquivo (sobrepõe o CHANGELOG.md)
#
#   Sem essas opções, as notas são extraídas automaticamente do CHANGELOG.md:
#     1. Da seção "## vX.Y.Z", se existir; senão
#     2. Da seção "## Unreleased" — nesse caso o cabeçalho é renomeado para
#        "## vX.Y.Z (data)" e o CHANGELOG.md entra no commit de bump.
#   O release falha se nenhuma das duas seções existir, então escreva as
#   notas no CHANGELOG.md (e faça commit) antes de rodar o script.
#   A seção Unreleased combina bem com --auto-bump: escreva as notas sem
#   se preocupar com o número da versão.
#   --critical               Marca como atualização crítica (banner vermelho no app)
#   --nostr-key-file <path>  Lê a chave Nostr (hex) do arquivo em vez da env var
#   --skip-build             Pula a compilação (útil se os binários já existem)
#   --skip-nostr             Pula a publicação Nostr
#   --dry-run                Imprime os passos sem executar nada destrutivo
#   --auto-bump              Se a versão for "patch|minor|major", faz bump automático
#
# Pré-requisitos:
#   - BESTFIN_DEV_NOSTR_PRIVKEY exportada no ambiente (hex, nsec ou caminho de
#     arquivo contendo a chave), ou use --nostr-key-file / --skip-nostr
#   - android/key.properties e android/bestfin-release.jks presentes (APK assinado)
#   - gh CLI autenticado (gh auth login)
#   - git configurado com acesso de push
#
# Exemplo:
#   BESTFIN_DEV_NOSTR_PRIVKEY=abc123 ./scripts/release.sh 1.1.0 \
#     --changelog "Melhoria de performance e correções de bugs"
#
# Ou usando um arquivo de changelog:
#   BESTFIN_DEV_NOSTR_PRIVKEY=abc123 ./scripts/release.sh 1.1.0 \
#     --changelog-file RELEASE_NOTES.md
#
# Ou bump automático de versão (patch, minor, major):
#   BESTFIN_DEV_NOSTR_PRIVKEY=abc123 ./scripts/release.sh minor \
#     --auto-bump --changelog "Novas funcionalidades menores"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo "[release] $*"; }
ok()    { echo "[release] ✓ $*"; }
err()   { echo "[release] ✗ $*" >&2; exit 1; }
step()  { echo; echo "══ $* ══"; }

# ── Load .env (secrets, nunca commitado) ──────────────────────────────────────
# Se existir, carrega as variáveis exportando-as automaticamente.
if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
  info "Variáveis carregadas de .env"
fi

dry_run=false
auto_bump=false
run() {
  if $dry_run; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# Função para bump automático de versão
# Se VERSION for "patch", "minor" ou "major", calcula a nova versão
compute_auto_bump() {
  local current_version
  current_version=$(grep '^version:' pubspec.yaml | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
  
  local major minor patch
  IFS='.' read -r major minor patch <<< "$current_version"
  
  case "$VERSION" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    major) major=$((major + 1)); minor=0; patch=0 ;;
    *) return 1 ;;
  esac
  
  echo "${major}.${minor}.${patch}"
}

# ── Parse arguments ───────────────────────────────────────────────────────────

VERSION=""
CHANGELOG=""
CHANGELOG_FILE=""
CRITICAL=false
SKIP_BUILD=false
SKIP_NOSTR=false
NOSTR_KEY_FILE=""
AUTO_BUMP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changelog)      CHANGELOG="$2";      shift 2 ;;
    --changelog-file) CHANGELOG_FILE="$2"; shift 2 ;;
    --critical)       CRITICAL=true;       shift ;;
    --nostr-key-file) NOSTR_KEY_FILE="$2"; shift 2 ;;
    --skip-build)     SKIP_BUILD=true;     shift ;;
    --skip-nostr)     SKIP_NOSTR=true;     shift ;;
    --dry-run)        dry_run=true;        shift ;;
    --auto-bump)      AUTO_BUMP=true;      shift ;;
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

# Processa bump automático se habilitado
if $AUTO_BUMP && [[ "$VERSION" =~ ^(patch|minor|major)$ ]]; then
  NEW_VERSION=$(compute_auto_bump)
  if [[ $? -ne 0 ]]; then
    err "Falha ao calcular bump automático para '$VERSION'"
  fi
  VERSION="$NEW_VERSION"
  info "Bump automático: versão → $VERSION"
fi

[[ -n "$VERSION" ]] || err "Uso: $0 <versão> [opções]  (ex: $0 1.1.0 --changelog 'Novas funcionalidades')"

# Valida formato X.Y.Z
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "Versão inválida '$VERSION'. Use o formato X.Y.Z"

# Extrai uma seção do CHANGELOG.md (do cabeçalho "## <token>" até a próxima
# seção "## "), sem os cabeçalhos e sem linhas em branco nas pontas.
# O token é comparado com o segundo campo do cabeçalho, então funciona para
# "## v1.2.3", "## v1.2.3 (data)" e "## Unreleased".
extract_changelog_section() {
  local file="$1" target="$2"
  awk -v target="$target" '
    /^## / {
      if (found) exit
      if ($2 == target) { found = 1; next }
    }
    found { print }
  ' "$file" | sed -e '/./,$!d' | sed -e ':a' -e '/^[[:space:]]*$/{$d;N;ba' -e '}'
}

# Processa changelog: prioridade --changelog > --changelog-file > CHANGELOG.md
RENAME_UNRELEASED=false
if [[ -n "$CHANGELOG" ]]; then
  : # já está em CHANGELOG
elif [[ -n "$CHANGELOG_FILE" ]]; then
  [[ -f "$CHANGELOG_FILE" ]] \
    || err "Arquivo de changelog não encontrado: $CHANGELOG_FILE"
  CHANGELOG="$(cat "$CHANGELOG_FILE")"
else
  CHANGELOG_MD="$PROJECT_DIR/CHANGELOG.md"
  [[ -f "$CHANGELOG_MD" ]] || err "CHANGELOG.md não encontrado em $PROJECT_DIR"
  CHANGELOG="$(extract_changelog_section "$CHANGELOG_MD" "v${VERSION}")"
  if [[ -n "$CHANGELOG" ]]; then
    info "Notas de release extraídas do CHANGELOG.md (seção v${VERSION})"
  else
    CHANGELOG="$(extract_changelog_section "$CHANGELOG_MD" "Unreleased")"
    [[ -n "$CHANGELOG" ]] \
      || err "Nenhuma seção '## v${VERSION}' nem '## Unreleased' com conteúdo no CHANGELOG.md. Escreva as notas da versão antes do release, ou use --changelog/--changelog-file."
    RENAME_UNRELEASED=true
    info "Notas de release extraídas do CHANGELOG.md (seção Unreleased → v${VERSION})"
  fi
fi

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

# Se a env var BESTFIN_DEV_NOSTR_PUBKEY foi definida (via .env ou ambiente),
# atualiza a pubkey embutida no app para bater com a chave usada no release.
CURRENT_PUBKEY=$(grep -oP "kDeveloperNostrPubkey = '\\K[^']+" lib/core/constants/app_info.dart)
PUBKEY="${BESTFIN_DEV_NOSTR_PUBKEY:-}"
if [[ -n "$PUBKEY" && "$CURRENT_PUBKEY" != "$PUBKEY" ]]; then
  # Se for caminho de arquivo, lê o conteúdo
  if [[ -f "$PUBKEY" ]]; then
    info "Lendo pubkey do arquivo: $PUBKEY"
    PUBKEY=$(tr -d '[:space:]' < "$PUBKEY")
  fi
  # Converte npub → hex automaticamente
  if [[ "$PUBKEY" == npub1* ]]; then
    info "Convertendo npub → hex..."
    PUBKEY=$(nix develop -c dart run scripts/publish_update.dart --to-hex "$PUBKEY" 2>/dev/null)
  fi
  info "app_info.dart: kDeveloperNostrPubkey → '${PUBKEY}'"
  run sed -i "s/const String kDeveloperNostrPubkey = '.*'/const String kDeveloperNostrPubkey = '${PUBKEY}'/" \
    lib/core/constants/app_info.dart
fi

BUMP_FILES=(pubspec.yaml lib/core/constants/app_info.dart)

if $RENAME_UNRELEASED; then
  RELEASE_DATE="$(date +%F)"
  info "CHANGELOG.md: ## Unreleased → ## v${VERSION} (${RELEASE_DATE})"
  run sed -i "0,/^## Unreleased.*/s//## v${VERSION} (${RELEASE_DATE})/" CHANGELOG.md
  BUMP_FILES+=(CHANGELOG.md)
fi

ok "Versão atualizada"

# ── Commit + tag ──────────────────────────────────────────────────────────────

step "Commit e tag v${VERSION}"

run git add "${BUMP_FILES[@]}"
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
