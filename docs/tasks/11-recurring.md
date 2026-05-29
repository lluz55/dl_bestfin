# Tarefa 11 — Transações Recorrentes

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🟡 Alta
> **Estimativa:** Média
> **Última atualização:** 2026-05-27

## Descrição

Implementar regras de recorrência com geração automática de transações pendentes, auto-confirm, e detecção de mudança de valor.

Recorrências cobrem assinaturas (Netflix, Spotify), contas fixas (aluguel, internet) e qualquer despesa/receita que se repete. O sistema deve gerar transações automaticamente e alertar quando valores mudam.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### Modelos e Repositórios

 - [x] Criar `lib/features/recurring/domain/models/recurring_rule.dart`
 - [x] Criar `lib/features/recurring/data/repositories/recurring_repository.dart`

### Lógica de Recorrência

 - [x] Implementar geração automática de transações pendentes (ao abrir app ou em background)
 - [x] Suportar frequências:
   - [x] `daily` — diária
   - [x] `weekly` — semanal
   - [x] `biweekly` — quinzenal
   - [x] `monthly` — mensal
   - [x] `yearly` — anual
 - [x] Implementar `auto_confirm`: se `true`, transações geradas já vêm como confirmadas
 - [x] Implementar detecção de mudança de valor (notificar usuário quando valor real difere do esperado)

### Telas e UI

 - [x] Criar tela de lista de recorrentes (ativas, pausadas, finalizadas)
 - [x] Criar form de recorrência (frequência, valor, conta, categoria, data início/fim)
 - [x] Criar hub de assinaturas: visão centralizada de recorrentes com total mensal

### Integração

 - [x] Integrar com form de transação: opção de marcar como recorrente

## Critérios de Aceitação

 - [x] Regras de recorrência geram transações corretas nas datas certas
 - [x] `auto_confirm` funcional (transações geradas já confirmadas quando habilitado)
 - [x] Lista de recorrentes com status visual (ativa/pausada/finalizada)
 - [x] Integração com form de transação (criar recorrência a partir de transação)

## Arquivos Principais

```
lib/features/recurring/
├── domain/
│   └── models/
│       └── recurring_rule.dart
├── data/
│   └── repositories/
│       └── recurring_repository.dart
└── presentation/
    ├── screens/
    │   ├── recurring_list_screen.dart
    │   ├── recurring_form_screen.dart
    │   └── subscriptions_hub_screen.dart
    └── widgets/
        ├── recurring_card.dart
        └── frequency_selector.dart
```

## Notas e Considerações

- **Geração on-demand**: As transações devem ser geradas quando o app abre (ou via background task). Gerar até X dias no futuro (configurável, ex.: 30 dias).
- **Detecção de mudança**: Se uma transação recorrente for confirmada com valor diferente do cadastrado, perguntar ao usuário se quer atualizar a regra.
- **Pausa vs cancelamento**: Pausar mantém a regra mas para de gerar; cancelar (end_date = hoje) encerra a regra.
- **Hub de assinaturas**: Mostrar total mensal gasto em recorrentes, com breakdown por categoria. Útil para o usuário identificar gastos fixos que pode cortar.
- **Conflito com parcelas**: Recorrente ≠ parcelado. Recorrente não tem número fixo de repetições (exceto se `end_date` definido). Garantir que a UI deixe essa distinção clara.
