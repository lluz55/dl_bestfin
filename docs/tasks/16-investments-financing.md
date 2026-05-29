# Tarefa 16 — Investimentos e Financiamentos

> **Fase:** 3 — Automação & Avançado
> **Prioridade:** 🟢 Média
> **Estimativa:** Grande
> **Última atualização:** 2026-05-27

## Descrição

Implementar tracking de investimentos (manual, por tipo) e financiamentos (SAC/Price) com tabela de amortização e simulação de pagamento extra.

Módulo avançado que cobre dois lados: ativos (investimentos) e passivos (financiamentos). Permite ao usuário ter uma visão completa do seu patrimônio líquido (net worth).

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [04-accounts](./04-accounts.md) | Contas e saldos | ⬜ Pendente |
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### 📈 Investimentos

#### Modelos e Repositórios

 - [x] Criar `lib/features/investments/domain/models/investment.dart`
 - [x] Criar repositório e use cases: `create`, `update_value`, `calculate_returns`

#### Telas e UI

 - [x] Criar tela de portfolio: valor total, rendimento, breakdown por tipo
 - [x] Criar form de investimento:
   - [x] Nome
   - [x] Tipo: Renda Fixa, Ações, FIIs, Crypto, Poupança, CDB, Tesouro Direto
   - [x] Valor aplicado
   - [x] Taxa / rendimento esperado
   - [x] Benchmark (CDI, IPCA, Ibovespa)
 - [x] Criar tela de detalhe: valor aplicado vs atual, rendimento %, gráfico de evolução
 - [x] Criar timeline de vencimentos futuros
 - [x] Donut chart de alocação por tipo de investimento

### 🏠 Financiamentos

#### Modelos e Repositórios

 - [x] Criar `lib/features/financing/domain/models/financing.dart`
 - [x] Criar `lib/features/financing/domain/models/financing_installment.dart`
 - [x] Criar repositório e use cases: `create`, `generate_amortization_table`, `simulate_extra_payment`

#### Lógica

 - [x] Implementar cálculo de tabela SAC (Sistema de Amortização Constante)
 - [x] Implementar cálculo de tabela Price (parcelas fixas)

#### Telas e UI

 - [x] Criar tela de lista de financiamentos
 - [x] Criar form de financiamento:
   - [x] Nome
   - [x] Valor total financiado
   - [x] Número de parcelas
   - [x] Taxa de juros (% ao mês)
   - [x] Tipo: SAC ou Price
   - [x] Conta vinculada
 - [x] Criar tela de detalhe com tabela de amortização (principal + juros separados)
 - [x] Criar simulador de amortização extra ("Se eu pagar R$X extra, economizo quanto?")
 - [x] Criar widget de progresso (parcelas pagas / total)

## Critérios de Aceitação

### Investimentos

 - [x] CRUD de investimentos funcional
 - [x] Portfolio overview com valor total e rendimento
 - [x] Gráfico de evolução do valor ao longo do tempo
 - [x] Donut chart de alocação por tipo

### Financiamentos

 - [x] Tabela SAC calculada corretamente (amortização constante, juros decrescentes)
 - [x] Tabela Price calculada corretamente (parcela fixa, composição juros/principal muda)
 - [x] Simulação de amortização extra calcula corretamente a economia de juros
 - [x] Progresso visual de parcelas (pagas vs restantes)

### Integração

 - [x] Dados de investimentos e financiamentos integrados no net worth do dashboard

## Arquivos Principais

```
lib/features/investments/
├── domain/
│   ├── models/
│   │   └── investment.dart
│   └── usecases/
│       ├── create_investment.dart
│       ├── update_investment_value.dart
│       └── calculate_returns.dart
├── data/
│   └── repositories/
│       └── investment_repository.dart
└── presentation/
    ├── screens/
    │   ├── portfolio_screen.dart
    │   ├── investment_form_screen.dart
    │   └── investment_detail_screen.dart
    └── widgets/
        ├── allocation_donut_chart.dart
        ├── performance_line_chart.dart
        └── maturity_timeline.dart

lib/features/financing/
├── domain/
│   ├── models/
│   │   ├── financing.dart
│   │   └── financing_installment.dart
│   └── usecases/
│       ├── create_financing.dart
│       ├── generate_amortization_table.dart
│       └── simulate_extra_payment.dart
├── data/
│   └── repositories/
│       └── financing_repository.dart
└── presentation/
    ├── screens/
    │   ├── financing_list_screen.dart
    │   ├── financing_form_screen.dart
    │   └── financing_detail_screen.dart
    └── widgets/
        ├── amortization_table_widget.dart
        ├── extra_payment_simulator.dart
        └── financing_progress_widget.dart
```

## Notas e Considerações

### Investimentos

- **Atualização manual**: Na v1, o usuário atualiza o valor manualmente. Integração com APIs de cotação pode vir futuramente.
- **Rendimento**: Calcular rendimento como `(valor_atual - valor_aplicado) / valor_aplicado * 100`. Mostrar em % e em R$.
- **Benchmark**: Se o investimento tem benchmark CDI, mostrar comparação "rendeu X% do CDI".
- **Tipos brasileiros**: Os tipos de investimento refletem o mercado brasileiro. Manter extensível para adicionar novos tipos.

### Financiamentos

- **SAC vs Price**:
  - **SAC**: Amortização constante = `valor_financiado / n_parcelas`. Juros = `saldo_devedor * taxa`. Parcela = amortização + juros (decrescente).
  - **Price**: Parcela fixa = `valor * (taxa * (1+taxa)^n) / ((1+taxa)^n - 1)`. Composição juros/principal muda ao longo do tempo.
- **Amortização extra**: Simular redução do saldo devedor e recalcular parcelas restantes. Mostrar economia total de juros.
- **Precisão**: Usar aritmética com 2 casas decimais (centavos). Cuidado com arredondamentos acumulados na tabela.
- **Net worth**: Investimentos são ativos (+), financiamentos são passivos (-). A integração com o dashboard deve somar/subtrair corretamente para calcular patrimônio líquido.
