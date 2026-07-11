# Changelog

## v1.0.9 (2026-07-11)

### Adicionado
- Layouts responsivos para tablet e desktop em telas de Transações, Relatórios e Mais
- Transições de página adaptativas: NoTransitionPage em telas médias+ (tablet/desktop)

### Melhorado
- Widgets de gráfico ajustados para layouts grandes (constrained width, responsive design)
- Experiência de navegação em telas wide screen otimizada

### Corrigido
- Ajustes de UI para telas grandes (Task 47)

## v1.0.8 (2026-07-10)

### Adicionado
- Versão do app exibida em Configurações › Sobre
- Carrossel de cartões na Home com indicadores de página
- Drill-down de categoria nos gráficos da Dashboard (toque para filtrar)
- Categoria pai/filho exibida em gráficos e componentes

### Melhorado
- Agregação do dashboard em isolate (Task 50)
- Badges sem full-scan da história de transações
- Ação principal no AppBar (FAB principal)
- Remoção de FABs secundários

### Segurança
- Notificações de atualização via Nostr (Task 48)

## v1.0.7 (2026-07-09)

### Adicionado
- Criptografia em repouso com SQLCipher (Android/iOS)
- Backup cifrado no formato .bfenc
- Script de release automatizado (scripts/release.sh)
- Notificações de atualização via Nostr

### Segurança
- allowBackup=false
- Regras de backup excluindo DB, arquivos e preferências
- Hardening de sync/backup

## v1.0.6 (2026-07-08)

### Melhorado
- Período global na Home
- Otimizações na camada de dados (Tasks 44, 45)