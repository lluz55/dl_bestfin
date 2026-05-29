# Tarefa 09 — Cartões de Crédito e Faturas

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🔴 Crítica
> **Estimativa:** Grande (múltiplas sprints)
> **Última atualização:** 2026-05-27

## Descrição

Implementar cartões de crédito com faturas, fechamento inteligente (feriados/finais de semana), pagamento de fatura e timeline de faturas futuras.

O cartão de crédito é um dos pilares do app financeiro — a maioria dos brasileiros utiliza cartão como principal meio de pagamento. O sistema precisa ser robusto o suficiente para lidar com fechamento de fatura em dias úteis, geração automática de faturas e pagamento total ou parcial.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### Modelos e Repositórios

 - [x] Criar `lib/features/credit_cards/domain/models/credit_card.dart`
 - [x] Criar `lib/features/credit_cards/domain/models/invoice.dart`
 - [x] Criar `lib/features/credit_cards/data/repositories/credit_card_repository.dart`
 - [x] Criar `lib/features/credit_cards/data/repositories/invoice_repository.dart`

### Lógica de Fechamento Inteligente

 - [x] Implementar lógica de fechamento inteligente:
   - [x] Calcular data de fechamento do mês
   - [x] Se fim de semana + `closing_anticipates_weekend`: antecipar para sexta
   - [x] Se feriado + `closing_anticipates_holiday`: antecipar para dia útil anterior
   - [x] Consultar tabela `holidays` para feriados nacionais/regionais

### Automações

 - [x] Implementar criação automática de conta `credit_card_bill` ao criar cartão
 - [x] Implementar criação automática de fatura ao adicionar transação no cartão
 - [x] Implementar fechamento de fatura: mudar status, calcular total, criar nova fatura aberta
 - [x] Implementar pagamento de fatura: transferência conta vinculada → conta da fatura
 - [x] Suportar pagamento parcial (com tracking do saldo restante)

### Telas e UI

 - [x] Criar tela de lista de cartões
 - [x] Criar tela de formulário de cartão (criação/edição)
 - [x] Criar tela de detalhe do cartão (resumo, fatura atual, limite)
 - [x] Criar tela de detalhe da fatura (transações, total, status)
 - [x] Criar widget de cartão visual (design de cartão de crédito estilizado)
 - [x] Criar timeline de faturas futuras (com parcelas projetadas)
 - [x] Criar widget de barra de limite usado/disponível

### Integração

 - [x] Integrar com transações: ao selecionar cartão no form de transação, debitar fatura correspondente

## Critérios de Aceitação

 - [x] Cartão cria conta de fatura automaticamente ao ser cadastrado
 - [x] Transações no cartão debitam a fatura correta (baseada na data e dia de fechamento)
 - [x] Fechamento respeita feriados e finais de semana (antecipa para dia útil)
 - [x] Pagamento total e parcial funcionam corretamente
 - [x] Timeline mostra faturas futuras com projeção de parcelas
 - [x] Limite usado/disponível calculado corretamente em tempo real

## Arquivos Principais

```
lib/features/credit_cards/
├── domain/
│   └── models/
│       ├── credit_card.dart
│       └── invoice.dart
├── data/
│   └── repositories/
│       ├── credit_card_repository.dart
│       └── invoice_repository.dart
└── presentation/
    ├── screens/
    │   ├── credit_cards_list_screen.dart
    │   ├── credit_card_form_screen.dart
    │   ├── credit_card_detail_screen.dart
    │   └── invoice_detail_screen.dart
    └── widgets/
        ├── credit_card_visual_widget.dart
        ├── invoice_timeline_widget.dart
        └── limit_bar_widget.dart
```

## Notas e Considerações

- **Fechamento inteligente**: A lógica de antecipação deve considerar tanto feriados nacionais quanto regionais (se configurados). Usar a tabela `holidays` do banco.
- **Conta de fatura**: Cada cartão gera uma conta do tipo `credit_card_bill` que funciona como passivo. O saldo dessa conta representa o valor devido.
- **Pagamento parcial**: Registrar o valor pago e manter o saldo restante na fatura. Considerar flag para mínimo da fatura.
- **Performance**: Cálculos de limite devem considerar faturas abertas + fatura futura em andamento.
- **Acessibilidade**: O widget visual do cartão deve ter labels acessíveis mesmo que tenha design decorativo.
