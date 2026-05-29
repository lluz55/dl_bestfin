# Tarefa 15 — Captura de Notificações

> **Fase:** 3 — Automação
> **Prioridade:** 🟡 Alta
> **Estimativa:** Grande
> **Última atualização:** 2026-05-27

## Descrição

Implementar captura e parsing de notificações bancárias no Android (NotificationListenerService) e Linux (D-Bus), com fila de revisão e padrões customizáveis.

Este é um diferencial competitivo do app — capturar notificações de bancos automaticamente e sugerir transações para o usuário confirmar. Tudo processado localmente, garantindo privacidade total.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### Android — NotificationListenerService

 - [x] Configurar `notification_listener_service` no Android:
   - [x] Manifest: declarar serviço e permissão `BIND_NOTIFICATION_LISTENER_SERVICE`
   - [x] Permissões: solicitar acesso às notificações
   - [x] Foreground service para processamento contínuo
 - [x] Criar `lib/features/notifications/data/services/android_notification_service.dart`: stream de notificações, filtragem por package

### Parser de Notificações

 - [x] Criar `lib/core/utils/notification_parser.dart`: parse com regex patterns (named groups: `amount`, `description`, `merchant`)
 - [x] Cadastrar padrões de notificação para bancos brasileiros:
   - [x] Nubank
   - [x] Inter
   - [x] Itaú
   - [x] Bradesco
   - [x] Banco do Brasil
   - [x] C6 Bank
   - [x] PicPay

### Fluxo de Sugestão

 - [x] Criar fluxo: notificação capturada → parse → transação sugerida (`is_confirmed=false`, `source='notification'`)
 - [x] Batch review: digest diário de transações sugeridas

### Telas e UI

 - [x] Criar `lib/features/notifications/presentation/screens/review_queue_screen.dart`: fila de transações sugeridas para confirmar/editar/descartar
 - [x] Criar `lib/features/notifications/presentation/screens/notification_settings_screen.dart`: config de bancos monitorados, gerenciar patterns
 - [x] Criar `lib/features/notifications/presentation/widgets/suggestion_card.dart`: card de sugestão com quick confirm
 - [x] Criar `lib/features/notifications/presentation/widgets/pattern_editor.dart`: editor de regex pattern com test de exemplo

### Linux — D-Bus

 - [x] Implementar approach para Linux (D-Bus): script helper ou notification server

### Privacidade

 - [x] Processamento on-device (privacidade): nunca enviar dados brutos para cloud

## Critérios de Aceitação

 - [x] Android: notificações bancárias capturadas e parseadas corretamente
 - [x] Transações sugeridas aparecem na fila de revisão
 - [x] Quick confirm em < 3 toques (confirmar transação sugerida rapidamente)
 - [x] Padrões de regex customizáveis pelo usuário
 - [x] Processamento 100% local (nenhum dado sai do dispositivo)
 - [x] Linux: pelo menos um approach funcional para captura de notificações

## Arquivos Principais

```
lib/features/notifications/
├── data/
│   └── services/
│       ├── android_notification_service.dart
│       └── linux_notification_service.dart
├── domain/
│   └── models/
│       ├── notification_pattern.dart
│       └── transaction_suggestion.dart
├── core/
│   └── utils/
│       └── notification_parser.dart
└── presentation/
    ├── screens/
    │   ├── review_queue_screen.dart
    │   └── notification_settings_screen.dart
    └── widgets/
        ├── suggestion_card.dart
        └── pattern_editor.dart
```

## Notas e Considerações

- **NotificationListenerService**: Requer permissão especial do usuário (abre settings do Android). Deve ter onboarding claro explicando por quê.
- **Padrões de regex**: Bancos mudam o formato das notificações sem aviso. O sistema de patterns customizáveis permite que o usuário corrija sem precisar de update do app.
- **Named groups**: Usar regex com named groups (`(?P<amount>\d+[.,]\d{2})`) para extrair valores estruturados da notificação.
- **Bancos brasileiros**: Cada banco tem formato diferente. Ex.: Nubank "Compra aprovada de R$XX,XX em LOJA", Inter "Débito R$ XX,XX - DESCRIÇÃO". Manter lista de patterns atualizável.
- **Privacidade**: Este é um ponto crítico. Deixar explícito na UI que nenhum dado é enviado para servidores. Todo processamento é local.
- **Linux D-Bus**: No Linux, usar `org.freedesktop.Notifications` via D-Bus para interceptar notificações. Approach alternativo: notification daemon custom.
- **Batch review**: Além do review individual, oferecer "digest" — uma tela que mostra todas as sugestões do dia para revisar de uma vez.
- **Falsos positivos**: O parse pode errar. Sempre gerar como sugestão (não confirmada) e deixar o usuário decidir.
