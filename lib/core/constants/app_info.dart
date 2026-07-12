/// Metadados de exibição do aplicativo.
///
/// [kAppVersion] é a fonte única da versão mostrada dentro do app (ex.: tela
/// de Configurações › Sobre). **DEVE ser atualizada a cada release**, junto com
/// o `version:` do `pubspec.yaml` e a tag `vX.Y.Z` — ver o fluxo de release em
/// AGENTS.md (§6) e docs/okf/development/releases.md.
const String kAppVersion = '1.0.13';

/// Nostr public key (hex) da identidade do desenvolvedor usada para transmitir
/// notificações de nova versão do app via Nostr. A chave privada correspondente
/// é mantida apenas no pipeline de CI (secret `BESTFIN_DEV_NOSTR_PRIVKEY`).
/// Eventos publicados sob essa chave são lidos em plain JSON — sem cifração
/// com masterKey do usuário, pois são anúncios públicos destinados a todos.
const String kDeveloperNostrPubkey =
    'Running build hooks...Running build hooks...6367ef0de375537d3a23bee4c2234c073c3013a12e36410a80f5d1ece57ab7c7';
