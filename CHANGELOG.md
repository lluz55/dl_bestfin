# Changelog

## Unreleased

### Adicionado
- Orçamento mensal com múltiplas categorias e rollover automático (Task 29)
- Modelo renovado de insights financeiros e sistema de badges (gamificação)
- Painel de detalhe de categoria com visão aprofundada
- Widget visual de conta e reformulação completa das telas de contas
- Modal informativo centralizado para páginas (info modal)
- ReportCardPair: widget que coloca cards lado a lado em telas largas
- Geração de par de chaves Nostr (scripts/generate_keypair.dart)
- Suporte a chaves bech32 (nsec/npub) nos scripts de release e notificação
- Script release.sh com auto-bump de versão (patch/minor/major)

### Melhorado
- Layouts adaptativos e refinamentos em telas grandes (tablet/desktop)
- Padronização do chrome dos modais bottom sheet em todo o app
- Refatoração dos widgets de gráfico para responsividade (bar, donut, line, heatmap, treemap, sankey, waterfall)
- Fluxo de release automatizado com extração de notas do CHANGELOG.md

### Documentação
- Protocolo OKF para agentes de IA (docs/okf/)
- Guia de performance e otimização no AGENTS.md

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

## v1.0.5 (2026-07-10)

### Adicionado
- Restauração de backup direto do onboarding (Task 41)
- Tutorial ampliado e atalhos na sidebar (Task 42)
- Agrupamento de lançamentos e exclusão em massa na lista de transações (ext. Task 38)
- Relatório em PDF com gráficos e insights (Tasks 14, 40, 43)

### Corrigido
- Correções de exportação e versionamento de backup
- Limpeza do header

## v1.0.4 (2026-07-09)

### Adicionado
- Lançamento em massa de transações (Task 38)
- Perfil de usuário (Task 39)

## v1.0.3 (2026-07-08)

### Corrigido
- "Apagar todos os dados" deixou de bloquear a interface (spinner infinito)

## v1.0.2 (2026-07-07)

### Adicionado
- Fluxo de onboarding e seleção de tema (Tasks 35-37)

### Corrigido
- Correções de UX em relatórios e no lançamento de transações

## v1.0.1 (2026-07-06)

### Adicionado
- Status pendente/confirmado em transações, com orçamento e fluxo de caixa projetados
- Valores pendentes exibidos nos gráficos de categoria, mensal e da dashboard
- Notificações locais e lembretes agendados
- Predição de categoria ao lançar transações
- Tutorial guiado no onboarding
- Fluxo de recuperação de cliente com criptografia

### Melhorado
- Padronização dos estilos visuais de botão em todo o app (Task 34)
- Agregação do fluxo de caixa e do gráfico de barras sem ordenar todo o histórico de transações
- Debounce e autodispose no autocomplete e na predição de categoria
- Layouts responsivos e modais adaptativos

### Alterado
- Sincronização migrada do backend Go para transporte serverless via Nostr

### Removido
- Funcionalidades de IA/LLM local
- Servidor backend em Go

## v1.0.0 (2026-06-04)

Primeira versão pública.

### Destaques
- Lançamentos com recorrência, parcelamento, transferências, duplicação e sugestões
- Cartões de crédito com faturas e planos de parcelamento
- Categorias hierárquicas (pai/filho com aninhamento arbitrário) e ícones personalizáveis
- Metas de economia com progresso, contribuições e metas recorrentes
- Investimentos (acompanhamento de carteira) e financiamentos (amortização SAC/Price)
- Relatórios com gráficos financeiros e importação de extratos em PDF
- Backup e restauração locais
- Gamificação: streaks, badges e sistema de XP
- Widgets personalizáveis na Home e atalhos configuráveis
- Sincronização entre dispositivos com fila offline