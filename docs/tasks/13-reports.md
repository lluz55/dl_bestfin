# Tarefa 13 — Relatórios e Gráficos

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🟡 Alta
> **Estimativa:** Grande
> **Última atualização:** 2026-05-27

## Descrição

Implementar hub de relatórios com múltiplos tipos de gráficos, filtros e comparações.

O módulo de relatórios é onde o usuário obtém insights reais sobre suas finanças. Precisa ser visualmente atrativo, com gráficos animados e filtros poderosos para explorar os dados de diferentes ângulos.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### Use Cases

 - [x] Criar `lib/features/reports/domain/usecases/generate_category_report.dart`
 - [x] Criar `lib/features/reports/domain/usecases/generate_monthly_report.dart`
 - [x] Criar `lib/features/reports/domain/usecases/generate_cash_flow.dart`
 - [x] Criar `lib/features/reports/domain/usecases/generate_net_worth.dart`

### Tela Principal

 - [x] Criar tela principal de relatórios com navegação entre tipos (tabs ou cards)

### Gráficos

 - [x] Implementar **Donut/Ring chart**: gastos por categoria (top N + "outros") via `fl_chart` `PieChart`
 - [x] Implementar **Bar chart horizontal**: ranking de categorias por valor
 - [x] Implementar **Bar chart vertical**: receita vs despesa por mês (últimos 6-12 meses)
 - [x] Implementar **Line chart**: evolução do saldo / net worth ao longo do tempo
 - [x] Implementar **Waterfall chart**: income → expenses → bottom line (custom com `fl_chart`)
 - [x] Implementar **Heatmap**: intensidade de gastos por dia da semana (custom widget)
 - [x] Implementar **Treemap**: drill-down categoria → subcategoria → entity (custom widget)

### Filtros e Comparações

 - [x] Implementar filtros globais:
   - [x] Período: mês, trimestre, ano, custom (date range picker)
   - [x] Contas: selecionar uma ou mais
   - [x] Categorias: selecionar uma ou mais
   - [x] Tipo: receita, despesa, transferência
 - [x] Implementar comparação: mês atual vs anterior

### Dashboard

 - [x] Implementar "Livre para gastar" completo no dashboard:
   - [x] Cálculo: saldo − despesas comprometidas (recorrentes + parcelas futuras do mês)

### Animações

 - [x] Animações staggered nos gráficos (cada barra/fatia anima em sequência)

## Critérios de Aceitação

 - [x] Todos os gráficos renderizando corretamente com dados reais
 - [x] Filtros funcionais e persistentes durante navegação
 - [x] Comparação mês a mês com indicadores visuais (↑ ↓)
 - [x] Animações suaves nos gráficos ao carregar e ao mudar filtros
 - [x] Dados corretos e consistentes com as transações do banco

## Arquivos Principais

```
lib/features/reports/
├── domain/
│   └── usecases/
│       ├── generate_category_report.dart
│       ├── generate_monthly_report.dart
│       ├── generate_cash_flow.dart
│       └── generate_net_worth.dart
└── presentation/
    ├── screens/
    │   ├── reports_hub_screen.dart
    │   ├── category_report_screen.dart
    │   ├── monthly_report_screen.dart
    │   ├── cash_flow_screen.dart
    │   └── net_worth_screen.dart
    └── widgets/
        ├── donut_chart_widget.dart
        ├── bar_chart_widget.dart
        ├── line_chart_widget.dart
        ├── waterfall_chart_widget.dart
        ├── heatmap_widget.dart
        ├── treemap_widget.dart
        ├── report_filters_widget.dart
        └── comparison_indicator.dart
```

## Notas e Considerações

- **fl_chart**: Usar `fl_chart` para Donut, Bar e Line. Waterfall pode ser construído com `BarChart` customizado do fl_chart (barras empilhadas com offsets).
- **Custom widgets**: Heatmap e Treemap não têm suporte direto no fl_chart. Implementar com `CustomPainter` ou grid de containers coloridos.
- **Sankey diagram**: Fica para tarefa separada (implementação custom mais complexa com paths curvos).
- **Performance**: Relatórios com muitos dados devem usar queries otimizadas no SQLite (agregações no banco, não no Dart). Considerar cache dos resultados.
- **Filtros persistentes**: Ao navegar entre tipos de relatório, os filtros selecionados devem ser mantidos.
- **Animações staggered**: Usar `Interval` dentro de um `AnimationController` único para criar efeito cascata. Cada elemento inicia com delay proporcional ao seu índice.
- **"Livre para gastar"**: Este cálculo depende de recorrentes (tarefa 11) e parcelas (tarefa 10). Implementar versão básica (saldo total) e evoluir quando as dependências estiverem prontas.
