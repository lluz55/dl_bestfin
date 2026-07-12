#!/usr/bin/env bash
# release.sh -- Compila e publica um release do BestFin, 100% local.
#
# O que faz:
#   1. Valida pré-condições (git limpo, gh CLI autenticado)
#   2. Faz bump de versão em pubspec.yaml e app_info.dart
#   3. Cria commit + tag anotada vX.Y.Z e faz push
#   4. Compila o APK Android e o bundle Linux via Nix (nix develop -c)
#   5. Cria o GitHub Release com os binários anexados
#   6. Publica a notificação de atualização nos relays Nostr
#
# Não depende do GitHub Actions -- keystore Android e chave privada Nostr são
# descriptografados localmente via SOPS ao entrar no devShell (ver
# docs/okf/development/secrets-sops.md). O workflow .github/workflows/release.yml
# continua existindo só como fallback manual (workflow_dispatch) -- use
# scripts/release-ci.sh se quiser disparar ele.
#
# Uso:
#   ./scripts/release.sh <versão> [opções]
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
#     2. Da seção "## Unreleased" -- nesse caso o cabeçalho é renomeado para
#        "## vX.Y.Z (data)" e o CHANGELOG.md entra no commit de bump.
#   O release falha se nenhuma das duas seções existir, então escreva as
#   notas no CHANGELOG.md (e faça commit) antes de rodar o script.
#   A seção Unreleased combina bem com --auto-bump: escreva as notas sem
#   se preocupar com o número da versão.
#   --critical               Marca a tag como atualização crítica -- o script
#                             lê isso na mensagem da tag e propaga para o
#                             GitHub Release (banner) e para o evento Nostr
#                             (--critical em publish_update.dart).
#   --dry-run                Imprime os passos sem executar nada destrutivo
#   --auto-bump               Se a versão for "patch|minor|major", faz bump automático
#
# Pré-requisitos:
#   - git configurado com acesso de push
#   - gh CLI autenticado (gh auth login) -- necessário para criar o GitHub Release
#   - rodando dentro do checkout com .env decifrado (nix develop já faz isso)
#     para publicar a notificação Nostr
#
# Exemplo:
#   ./scripts/release.sh 1.1.0 --changelog "Melhoria de performance e correções de bugs"
#
# Ou usando um arquivo de changelog:
#   ./scripts/release.sh 1.1.0 --changelog-file RELEASE_NOTES.md
#
# Ou bump automático de versão (patch, minor, major):
#   ./scripts/release.sh minor --auto-bump --changelog "Novas funcionalidades menores"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# -- Helpers -------------------------------------------------------------------

info()  { echo "[release] $*"; }
ok()    { echo "[release] ✓ $*"; }
err()   { echo "[release] ✗ $*" >&2; exit 1; }
step()  { echo; echo "== $* =="; }

# Trap para mostrar em qual linha o script falhou
error_trap() {
  local last_exit=$?
  local line=$1
  echo "[release] ✗ ERRO na linha ${line} (exit code: ${last_exit})" >&2
}
trap 'error_trap $LINENO' ERR

# -- Load .env (opcional, nunca commitado) -------------------------------------
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
    echo "  -> $*"
    "$@"
  fi
}

# Função para bump automático de versão
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

# -- Parse arguments -------------------------------------------------------------

VERSION=""
CHANGELOG=""
CHANGELOG_FILE=""
CRITICAL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changelog)      CHANGELOG="$2";      shift 2 ;;
    --changelog-file) CHANGELOG_FILE="$2"; shift 2 ;;
    --critical)       CRITICAL=true;       shift ;;
    --dry-run)        dry_run=true;        shift ;;
    --auto-bump)      auto_bump=true;      shift ;;
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
if $auto_bump && [[ "$VERSION" =~ ^(patch|minor|major)$ ]]; then
  NEW_VERSION=$(compute_auto_bump)
  VERSION="$NEW_VERSION"
  info "Bump automático: versão -> $VERSION"
fi

[[ -n "$VERSION" ]] || err "Uso: $0 <versão> [opções]  (ex: $0 1.1.0 --changelog 'Novas funcionalidades')"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "Versão inválida '$VERSION'. Use o formato X.Y.Z"

# Processa changelog: prioridade --changelog > --changelog-file > CHANGELOG.md
RENAME_UNRELEASED=false
CHANGELOG_MD="$PROJECT_DIR/CHANGELOG.md"
if [[ -n "$CHANGELOG" ]]; then
  : # já está em CHANGELOG
elif [[ -n "$CHANGELOG_FILE" ]]; then
  [[ -f "$CHANGELOG_FILE" ]] \
    || err "Arquivo de changelog não encontrado: $CHANGELOG_FILE"
  CHANGELOG="$(cat "$CHANGELOG_FILE")"
else
  [[ -f "$CHANGELOG_MD" ]] || err "CHANGELOG.md não encontrado em $PROJECT_DIR"
  if CHANGELOG="$("$SCRIPT_DIR/extract_changelog.sh" "v${VERSION}" "$CHANGELOG_MD")"; then
    info "Notas de release extraídas do CHANGELOG.md (seção v${VERSION})"
  else
    CHANGELOG="$("$SCRIPT_DIR/extract_changelog.sh" "Unreleased" "$CHANGELOG_MD")" \
      || err "Nenhuma seção '## v${VERSION}' nem '## Unreleased' com conteúdo no CHANGELOG.md. Escreva as notas da versão antes do release, ou use --changelog/--changelog-file."
    RENAME_UNRELEASED=true
    info "Notas de release extraídas do CHANGELOG.md (seção Unreleased -> v${VERSION})"
  fi
fi

# -- Validações ------------------------------------------------------------------

step "Validando pré-condições"

cd "$PROJECT_DIR"

# Git limpo
if ! $dry_run && [[ -n "$(git status --porcelain)" ]]; then
  err "Working tree sujo. Faça commit ou stash das alterações antes do release."
fi

# git configurado para push
if ! git remote get-url origin &>/dev/null; then
  err "Remote 'origin' não configurado."
fi
ok "Remote origin configurado"

# gh CLI (necessário para criar o GitHub Release)
if ! command -v gh &>/dev/null; then
  err "gh CLI não encontrado. Instale em https://cli.github.com."
fi
ok "gh CLI disponível"

ok "Pré-condições OK"

# -- Bump de versão ---------------------------------------------------------------

step "Atualizando versão para ${VERSION}"

CURRENT_BUILD=$(grep '^version:' pubspec.yaml | grep -oP '\+\K[0-9]+' || echo "0")
NEW_BUILD=$((CURRENT_BUILD + 1))

info "pubspec.yaml: version -> ${VERSION}+${NEW_BUILD}"
run sed -i "s/^version:.*/version: ${VERSION}+${NEW_BUILD}/" pubspec.yaml

info "app_info.dart: kAppVersion = '${VERSION}'"
run sed -i "s/const String kAppVersion = '.*'/const String kAppVersion = '${VERSION}'/" \
  lib/core/constants/app_info.dart

# Verifica se a substituição foi aplicada
$dry_run || grep -q "kAppVersion = '${VERSION}'" lib/core/constants/app_info.dart \
  || err "Falha ao atualizar kAppVersion em app_info.dart"

# Atualiza kDeveloperNostrPubkey se a env var for diferente do que está no código
# (é a chave pública -- não é sensível, só mantém o app_info.dart sincronizado)
CURRENT_PUBKEY=$(grep -oP "kDeveloperNostrPubkey = '?\K[^';]+" lib/core/constants/app_info.dart | head -1 || echo "")
PUBKEY="${BESTFIN_DEV_NOSTR_PUBKEY:-}"
if [[ -n "$PUBKEY" && "$CURRENT_PUBKEY" != "$PUBKEY" ]]; then
  if [[ -f "$PUBKEY" ]]; then
    info "Lendo pubkey do arquivo: $PUBKEY"
    PUBKEY=$(tr -d '[:space:]' < "$PUBKEY")
  fi
  if [[ "$PUBKEY" == npub1* ]]; then
    info "Convertendo npub -> hex..."
    # `dart run` pode imprimir ruído no stdout (ex: "Running build hooks...").
    # Extrai só a última ocorrência de 64 hex chars, ignorando esse ruído.
    PUBKEY_RAW=$(nix develop -c dart run scripts/publish_update.dart --to-hex "$PUBKEY" 2>/dev/null)
    PUBKEY=$(grep -oP '[0-9a-f]{64}' <<< "$PUBKEY_RAW" | tail -1)
    [[ -n "$PUBKEY" ]] || err "Falha ao converter npub para hex (saída: ${PUBKEY_RAW})"
  fi
  info "app_info.dart: kDeveloperNostrPubkey = '${PUBKEY}'"
  # A declaração está em duas linhas no código, então substituímos a linha após o =
  if grep -qP "kDeveloperNostrPubkey =$" lib/core/constants/app_info.dart; then
    run sed -i "/kDeveloperNostrPubkey =/{n;s/'[^']*'/'${PUBKEY}'/}" lib/core/constants/app_info.dart
  else
    run sed -i "s/const String kDeveloperNostrPubkey = '.*'/const String kDeveloperNostrPubkey = '${PUBKEY}'/" \
      lib/core/constants/app_info.dart
  fi
  $dry_run || grep -q "${PUBKEY}" lib/core/constants/app_info.dart \
    || err "Falha ao atualizar kDeveloperNostrPubkey em app_info.dart"
fi

BUMP_FILES=(pubspec.yaml lib/core/constants/app_info.dart)

if $RENAME_UNRELEASED; then
  RELEASE_DATE="$(date +%F)"
  info "CHANGELOG.md: ## Unreleased -> ## v${VERSION} (${RELEASE_DATE})"
  run sed -i "0,/^## Unreleased.*/s//## v${VERSION} (${RELEASE_DATE})/" CHANGELOG.md
  $dry_run || grep -q "^## v${VERSION}" CHANGELOG.md \
    || err "Falha ao renomear Unreleased para v${VERSION} no CHANGELOG.md"
  BUMP_FILES+=(CHANGELOG.md)
fi

ok "Versão atualizada"

# -- Commit + tag ------------------------------------------------------------------

step "Commit e tag v${VERSION}"

# A mensagem da tag anotada é o sinal que este script usa para saber se o
# release é crítico (banner no GitHub Release + --critical no evento Nostr).
TAG_MESSAGE="release"
$CRITICAL && TAG_MESSAGE="critical"

run git add "${BUMP_FILES[@]}"
run git commit -m "chore(release): bump version para v${VERSION}"
run git tag -a "v${VERSION}" -m "$TAG_MESSAGE"

# git push sem prompt interativo
GIT_TERMINAL_PROMPT=0 run git push origin HEAD "v${VERSION}"

ok "Commit e tag publicados (v${VERSION})"

# -- Build local -------------------------------------------------------------------

step "Compilando APK Android (release)"
run nix develop -c flutter build apk --release

step "Compilando bundle Linux (release)"
run nix develop -c flutter build linux --release

run mkdir -p dist
APK_DIST="dist/bestfin-v${VERSION}-android.apk"
LINUX_DIST="dist/bestfin-v${VERSION}-linux-x64.tar.gz"
run cp build/app/outputs/flutter-apk/app-release.apk "$APK_DIST"
run tar -czf "$LINUX_DIST" -C build/linux/x64/release/bundle .

ok "Binários empacotados em dist/"

# -- GitHub Release ----------------------------------------------------------------

step "Criando GitHub Release v${VERSION}"

FULL_NOTES="$CHANGELOG"
if $CRITICAL; then
  FULL_NOTES="${FULL_NOTES}"$'\n\n> **Atualização crítica:** recomenda-se atualizar o mais breve possível.'
fi

run gh release create "v${VERSION}" \
  --title "BestFin v${VERSION}" \
  --notes "$FULL_NOTES" \
  "$APK_DIST" "$LINUX_DIST"

ok "GitHub Release v${VERSION} publicado"

# -- Notificação Nostr --------------------------------------------------------------

step "Publicando notificação de atualização via Nostr"

REPO_SLUG="$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')"
NOSTR_ARGS=(
  --version "${VERSION}"
  --changelog "$CHANGELOG"
  --download-url "https://github.com/${REPO_SLUG}/releases/tag/v${VERSION}"
)
$CRITICAL && NOSTR_ARGS+=(--critical)

run nix develop -c dart run scripts/publish_update.dart "${NOSTR_ARGS[@]}"

ok "Notificação Nostr publicada"

# -- Concluído -----------------------------------------------------------------

echo
echo "=========================================="
echo "  Release v${VERSION} publicado com sucesso!"
echo "  Tag, binários (Android + Linux), GitHub Release"
echo "  e notificação Nostr -- tudo local, sem CI."
$dry_run && echo "  (simulação -- nenhuma ação foi executada)"
echo "=========================================="
