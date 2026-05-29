# Tarefa 12 — Objetivos Financeiros

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🟡 Alta
> **Estimativa:** Média
> **Última atualização:** 2026-05-27

## Descrição

Implementar objetivos financeiros com progresso visual (ring animado), recorrência, simulador e celebração ao atingir meta.

Objetivos são motivadores — o usuário define uma meta (ex.: "viagem de férias R$5.000") e acompanha visualmente o progresso. Contribuições são registradas como transferências para a conta vinculada ao objetivo.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [04-accounts](./04-accounts.md) | Contas e saldos | ⬜ Pendente |
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### Modelos e Repositórios

 - [x] Criar `lib/features/goals/domain/models/goal.dart`
 - [x] Criar `lib/features/goals/data/repositories/goal_repository.dart`

### Use Cases

 - [x] Criar use case `create_goal`
 - [x] Criar use case `add_contribution` (registra transferência para conta do objetivo)
 - [x] Criar use case `calculate_monthly_target` (quanto poupar por mês para atingir meta no prazo)

### Telas e UI

 - [x] Criar tela de lista de objetivos com cards de progresso (ring animation com overshoot)
 - [x] Criar form de objetivo: nome, valor alvo, prazo, conta vinculada, ícone, cor, recorrência
 - [x] Criar widget de progress ring com animação spring
 - [x] Criar simulador: "Quanto preciso poupar por mês?"
 - [x] Criar celebração (Lottie) ao atingir meta

### Lógica

 - [x] Status auto-update: `active` → `completed` quando `current >= target`
 - [x] Objetivos recorrentes: ex. "poupar R$500/mês" (reseta a cada período)

## Critérios de Aceitação

 - [x] CRUD de objetivos funcional
 - [x] Progress ring com animação spring (overshoot visual ao atualizar)
 - [x] Contribuições registradas como transferências reais para a conta vinculada
 - [x] Simulador calcula corretamente o valor mensal necessário
 - [x] Celebração visual (animação Lottie) ao completar o objetivo
 - [x] Recorrência funcional (objetivo reseta conforme período configurado)

## Arquivos Principais

```
lib/features/goals/
├── domain/
│   ├── models/
│   │   └── goal.dart
│   └── usecases/
│       ├── create_goal.dart
│       ├── add_contribution.dart
│       └── calculate_monthly_target.dart
├── data/
│   └── repositories/
│       └── goal_repository.dart
└── presentation/
    ├── screens/
    │   ├── goals_list_screen.dart
    │   └── goal_form_screen.dart
    └── widgets/
        ├── progress_ring_widget.dart
        ├── goal_card.dart
        ├── monthly_simulator_widget.dart
        └── goal_celebration_widget.dart
```

## Notas e Considerações

- **Progress ring**: Usar `CustomPainter` com `AnimationController` e `SpringSimulation` para efeito de overshoot quando o progresso atualiza. Curva suave e satisfatória.
- **Lottie**: Usar animação de celebração (confetti/fireworks). Considerar ter um asset local incluído no app e opcionalmente permitir customização.
- **Contribuição = transferência**: Cada contribuição gera uma transação real de transferência. Isso garante que o saldo da conta de destino reflete o progresso.
- **Simulador**: Fórmula simples: `(target - current) / meses_restantes`. Considerar mostrar cenários (pessimista, otimista, ideal).
- **Objetivos recorrentes**: Exemplo: "Reserva de emergência mensal". Ao completar o período, o progresso reseta mas o histórico é mantido.
- **Acessibilidade**: O progress ring deve ter label acessível informando a porcentagem atual.
