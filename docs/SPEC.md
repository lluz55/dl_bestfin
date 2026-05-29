# BestFin — Especificação Técnica Completa

> App de finanças pessoais multiplataforma (Android, Linux, Web) com Material Design 3 Expressive, contabilidade de partida dobrada e captura automática de transações.

---

## 1. Visão Geral

### 1.1 Objetivo
Oferecer ao usuário controle completo sobre suas finanças pessoais com uma experiência visual premium, automação inteligente e insights acionáveis.

### 1.2 Plataformas
- **Android** (primário)
- **Linux Desktop** (secundário)
- **Web** (terciário)

### 1.3 Moeda
- BRL (Real Brasileiro) — única moeda suportada inicialmente

### 1.4 Idioma
- Português Brasileiro (pt-BR) — com estrutura i18n-ready para futura internacionalização

---

## 2. Stack Técnico

### 2.1 Framework & Linguagem
| Item | Tecnologia |
|------|-----------|
| Framework | Flutter (stable channel) |
| Linguagem | Dart |
| Build Environment | Nix Flake (com Android SDK compartilhado) |

### 2.2 Dependências Core
| Camada | Package | Versão | Propósito |
|--------|---------|--------|-----------|
| Database | `drift` | ^2.33.0 | SQLite type-safe com migrations |
| Database | `sqlite3_flutter_libs` | latest | Bindings SQLite nativos |
| State | `flutter_riverpod` | ^3.3.1 | State management reativo |
| State | `riverpod_annotation` | ^2.0.0 | Code generation para providers |
| Routing | `go_router` | latest | Navegação declarativa |
| Charts | `fl_chart` | ^1.2.0 | Gráficos customizáveis |
| PDF | `pdf` | ^3.12.0 | Geração de relatórios PDF |
| PDF | `printing` | ^5.14.3 | Preview/impressão de PDFs |
| CSV | `csv` | ^8.0.0 | Export/import CSV |
| Auth | `local_auth` | ^3.0.1 | Biometria/PIN |
| Auth | `flutter_secure_storage` | ^10.2.0 | Storage seguro |
| Notif Android | `notification_listener_service` | ^0.3.5 | Captura de notificações |
| D-Bus Linux | `dbus` | ^0.7.12 | Notificações Linux |
| Arquivos | `file_picker` | ^11.0.2 | Seleção de arquivos |
| Arquivos | `image_picker` | ^1.2.2 | Câmera/galeria |
| Animações | `flutter_animate` | ^4.5.2 | Micro-interações |
| Animações | `lottie` | ^3.3.3 | Animações vetoriais |
| Share | `share_plus` | ^13.1.0 | Compartilhamento |
| Path | `path_provider` | ^2.1.5 | Diretórios do sistema |

### 2.3 Dev Dependencies
| Package | Propósito |
|---------|-----------|
| `drift_dev` | Code generation para Drift |
| `build_runner` | Runner de code generation |
| `riverpod_generator` | Code generation para Riverpod |
| `flutter_lints` | Regras de lint |

---

## 3. Arquitetura

### 3.1 Padrão
**Feature-First + Clean Architecture Leve**

Cada feature contém 3 camadas:
- **Presentation**: Screens, Widgets, Providers (Riverpod)
- **Domain**: Models/Entities, Use Cases (lógica de negócio)
- **Data**: Repositories, DAOs (acesso a dados via Drift)

### 3.2 Estrutura de Pastas

```
lib/
├── main.dart                         # Entry point
├── app.dart                          # MaterialApp config
├── core/
│   ├── database/
│   │   ├── app_database.dart         # Drift database principal
│   │   ├── app_database.g.dart       # Gerado
│   │   ├── tables/                   # Definições de tabelas
│   │   │   ├── accounts_table.dart
│   │   │   ├── transactions_table.dart
│   │   │   ├── entries_table.dart
│   │   │   ├── categories_table.dart
│   │   │   ├── entities_table.dart
│   │   │   ├── credit_cards_table.dart
│   │   │   ├── invoices_table.dart
│   │   │   ├── installment_plans_table.dart
│   │   │   ├── recurring_rules_table.dart
│   │   │   ├── goals_table.dart
│   │   │   ├── investments_table.dart
│   │   │   ├── financings_table.dart
│   │   │   ├── financing_installments_table.dart
│   │   │   ├── attachments_table.dart
│   │   │   ├── notification_patterns_table.dart
│   │   │   └── holidays_table.dart
│   │   └── daos/
│   │       ├── accounts_dao.dart
│   │       ├── transactions_dao.dart
│   │       ├── categories_dao.dart
│   │       ├── entities_dao.dart
│   │       ├── credit_cards_dao.dart
│   │       ├── invoices_dao.dart
│   │       ├── goals_dao.dart
│   │       ├── investments_dao.dart
│   │       ├── financings_dao.dart
│   │       └── notification_patterns_dao.dart
│   ├── theme/
│   │   ├── app_theme.dart            # ThemeData + extensions
│   │   ├── color_schemes.dart        # Light/Dark schemes
│   │   ├── typography.dart           # Tipografia expressiva
│   │   ├── shapes.dart               # Shapes M3 Expressive
│   │   └── motion.dart               # Spring configs
│   ├── widgets/                      # Widgets reutilizáveis
│   │   ├── animated_card.dart
│   │   ├── amount_display.dart
│   │   ├── account_selector.dart
│   │   ├── category_icon.dart
│   │   ├── category_picker.dart
│   │   ├── entity_autocomplete.dart
│   │   ├── sentiment_selector.dart
│   │   ├── icon_picker.dart
│   │   ├── color_picker.dart
│   │   ├── numeric_keypad.dart
│   │   ├── empty_state.dart
│   │   ├── confirmation_dialog.dart
│   │   └── loading_indicator.dart
│   ├── extensions/
│   │   ├── context_extensions.dart
│   │   ├── date_extensions.dart
│   │   ├── number_extensions.dart
│   │   └── string_extensions.dart
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── date_formatter.dart
│   │   ├── validators.dart
│   │   └── notification_parser.dart
│   └── constants/
│       ├── app_constants.dart
│       ├── account_types.dart
│       ├── transaction_types.dart
│       ├── sentiment_types.dart
│       └── default_categories.dart
├── features/
│   ├── onboarding/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── onboarding_screen.dart
│   │       ├── widgets/
│   │       │   ├── welcome_step.dart
│   │       │   ├── create_account_step.dart
│   │       │   ├── select_categories_step.dart
│   │       │   └── notification_permission_step.dart
│   │       └── providers/
│   │           └── onboarding_provider.dart
│   ├── dashboard/
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── dashboard_data.dart
│   │   │   └── usecases/
│   │   │       └── get_dashboard_data.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── dashboard_screen.dart
│   │       ├── widgets/
│   │       │   ├── balance_card.dart
│   │       │   ├── free_to_spend_card.dart
│   │       │   ├── spending_donut.dart
│   │       │   ├── income_expense_bar.dart
│   │       │   ├── upcoming_bills.dart
│   │       │   ├── goals_progress.dart
│   │       │   └── insight_card.dart
│   │       └── providers/
│   │           └── dashboard_provider.dart
│   ├── accounts/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── account_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── account.dart
│   │   │   └── usecases/
│   │   │       ├── create_account.dart
│   │   │       ├── update_account.dart
│   │   │       ├── delete_account.dart
│   │   │       └── get_account_balance.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── accounts_list_screen.dart
│   │       │   ├── account_detail_screen.dart
│   │       │   └── account_form_screen.dart
│   │       ├── widgets/
│   │       │   └── account_card.dart
│   │       └── providers/
│   │           └── accounts_provider.dart
│   ├── transactions/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── transaction_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── transaction.dart
│   │   │   │   └── entry.dart
│   │   │   └── usecases/
│   │   │       ├── create_transaction.dart
│   │   │       ├── update_transaction.dart
│   │   │       ├── delete_transaction.dart
│   │   │       └── get_transactions.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── transactions_list_screen.dart
│   │       │   └── transaction_form_screen.dart
│   │       ├── widgets/
│   │       │   ├── transaction_tile.dart
│   │       │   ├── transaction_type_tabs.dart
│   │       │   ├── amount_input.dart
│   │       │   └── transaction_filters.dart
│   │       └── providers/
│   │           └── transactions_provider.dart
│   ├── categories/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── category_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── category.dart
│   │   │   └── usecases/
│   │   │       ├── create_category.dart
│   │   │       ├── update_category.dart
│   │   │       ├── delete_category.dart
│   │   │       └── get_categories_tree.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── categories_screen.dart
│   │       │   └── category_form_screen.dart
│   │       ├── widgets/
│   │       │   ├── category_tree.dart
│   │       │   └── category_tile.dart
│   │       └── providers/
│   │           └── categories_provider.dart
│   ├── credit_cards/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       ├── credit_card_repository.dart
│   │   │       └── invoice_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── credit_card.dart
│   │   │   │   └── invoice.dart
│   │   │   └── usecases/
│   │   │       ├── create_credit_card.dart
│   │   │       ├── close_invoice.dart
│   │   │       ├── pay_invoice.dart
│   │   │       ├── get_current_invoice.dart
│   │   │       └── calculate_closing_date.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── credit_cards_screen.dart
│   │       │   ├── credit_card_form_screen.dart
│   │       │   ├── credit_card_detail_screen.dart
│   │       │   └── invoice_detail_screen.dart
│   │       ├── widgets/
│   │       │   ├── credit_card_widget.dart
│   │       │   ├── invoice_summary.dart
│   │       │   └── future_invoices_timeline.dart
│   │       └── providers/
│   │           ├── credit_cards_provider.dart
│   │           └── invoices_provider.dart
│   ├── recurring/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── recurring_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── recurring_rule.dart
│   │   │   └── usecases/
│   │   │       ├── create_recurring_rule.dart
│   │   │       ├── generate_pending_transactions.dart
│   │   │       └── detect_price_changes.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── recurring_list_screen.dart
│   │       │   └── recurring_form_screen.dart
│   │       ├── widgets/
│   │       │   └── recurring_tile.dart
│   │       └── providers/
│   │           └── recurring_provider.dart
│   ├── installments/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── installment_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── installment_plan.dart
│   │   │   └── usecases/
│   │   │       ├── create_installment_plan.dart
│   │   │       └── get_future_commitments.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── installments_screen.dart
│   │       │   └── installment_wizard_screen.dart
│   │       ├── widgets/
│   │       │   ├── installment_progress.dart
│   │       │   └── commitment_timeline.dart
│   │       └── providers/
│   │           └── installments_provider.dart
│   ├── goals/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── goal_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── goal.dart
│   │   │   └── usecases/
│   │   │       ├── create_goal.dart
│   │   │       ├── add_contribution.dart
│   │   │       └── calculate_monthly_target.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── goals_screen.dart
│   │       │   └── goal_form_screen.dart
│   │       ├── widgets/
│   │       │   ├── goal_card.dart
│   │       │   ├── goal_progress_ring.dart
│   │       │   └── goal_simulator.dart
│   │       └── providers/
│   │           └── goals_provider.dart
│   ├── investments/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── investment_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   └── investment.dart
│   │   │   └── usecases/
│   │   │       ├── create_investment.dart
│   │   │       ├── update_investment_value.dart
│   │   │       └── calculate_returns.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── investments_screen.dart
│   │       │   ├── investment_form_screen.dart
│   │       │   └── investment_detail_screen.dart
│   │       ├── widgets/
│   │       │   ├── portfolio_overview.dart
│   │       │   ├── investment_card.dart
│   │       │   └── returns_chart.dart
│   │       └── providers/
│   │           └── investments_provider.dart
│   ├── financing/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── financing_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── financing.dart
│   │   │   │   └── financing_installment.dart
│   │   │   └── usecases/
│   │   │       ├── create_financing.dart
│   │   │       ├── generate_amortization_table.dart
│   │   │       └── simulate_extra_payment.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── financings_screen.dart
│   │       │   ├── financing_form_screen.dart
│   │       │   └── financing_detail_screen.dart
│   │       ├── widgets/
│   │       │   ├── amortization_table.dart
│   │       │   ├── financing_progress.dart
│   │       │   └── extra_payment_simulator.dart
│   │       └── providers/
│   │           └── financings_provider.dart
│   ├── reports/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── generate_category_report.dart
│   │   │       ├── generate_monthly_report.dart
│   │   │       ├── generate_cash_flow.dart
│   │   │       └── generate_net_worth.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── reports_screen.dart
│   │       ├── widgets/
│   │       │   ├── donut_chart_widget.dart
│   │       │   ├── bar_chart_widget.dart
│   │       │   ├── line_chart_widget.dart
│   │       │   ├── waterfall_chart_widget.dart
│   │       │   ├── heatmap_widget.dart
│   │       │   ├── treemap_widget.dart
│   │       │   ├── sankey_widget.dart
│   │       │   └── report_filters.dart
│   │       └── providers/
│   │           └── reports_provider.dart
│   ├── notifications/
│   │   ├── data/
│   │   │   ├── services/
│   │   │   │   ├── android_notification_service.dart
│   │   │   │   └── linux_notification_service.dart
│   │   │   └── repositories/
│   │   │       └── notification_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── notification_pattern.dart
│   │   │   │   └── suggested_transaction.dart
│   │   │   └── usecases/
│   │   │       ├── parse_notification.dart
│   │   │       └── confirm_suggestion.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── notification_settings_screen.dart
│   │       │   └── review_queue_screen.dart
│   │       ├── widgets/
│   │       │   ├── pattern_editor.dart
│   │       │   └── suggestion_card.dart
│   │       └── providers/
│   │           └── notifications_provider.dart
│   ├── settings/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── settings_screen.dart
│   │       │   ├── theme_settings_screen.dart
│   │       │   ├── security_settings_screen.dart
│   │       │   └── holidays_screen.dart
│   │       └── providers/
│   │           └── settings_provider.dart
│   └── backup/
│       ├── domain/
│       │   └── usecases/
│       │       ├── export_csv.dart
│       │       ├── export_json.dart
│       │       ├── export_pdf.dart
│       │       ├── import_data.dart
│       │       └── backup_database.dart
│       └── presentation/
│           ├── screens/
│           │   └── backup_screen.dart
│           └── providers/
│               └── backup_provider.dart
```

### 3.3 Princípios Arquiteturais

1. **Single Source of Truth**: Drift database é a fonte única de verdade
2. **Reactive Streams**: Providers observam o DB via streams do Drift (`.watch()`)
3. **Imutabilidade**: Models são immutable (freezed-like, via Drift data classes)
4. **Separação de Concerns**: UI nunca acessa o DB diretamente
5. **Fail-Safe**: Transações financeiras usam `transaction()` do Drift para atomicidade
6. **Valores Monetários**: Sempre armazenados em centavos (INTEGER) para evitar floating-point

---

## 4. Modelo de Dados

### 4.1 Princípio: Contabilidade de Partida Dobrada

Cada transação gera **dois lançamentos** (entries) que sempre se equilibram:
- `SUM(débitos) == SUM(créditos)` para cada transação

**Exemplos:**

| Operação | Débito (saída de) | Crédito (entrada em) |
|----------|-------------------|---------------------|
| Despesa R$50 Mercado | Despesas:Alimentação | Conta Corrente |
| Salário R$5000 | Conta Corrente | Receitas:Salário |
| Transferência R$1000 | Conta Poupança | Conta Corrente |
| Compra cartão R$200 | Despesas:Lazer | Fatura Cartão (passivo) |
| Pagar fatura R$2000 | Fatura Cartão | Conta Corrente |

### 4.2 Tabelas

#### 4.2.1 `accounts` — Contas

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | Identificador |
| name | TEXT | NOT NULL | Nome da conta |
| type | TEXT | NOT NULL, ENUM | `checking`, `savings`, `wallet`, `investment`, `reserve`, `credit_card_bill` |
| icon | TEXT | NOT NULL, DEFAULT 'account_balance' | Nome do ícone Material |
| color | INTEGER | NOT NULL | Cor ARGB (ex: 0xFF4CAF50) |
| initial_balance | INTEGER | NOT NULL, DEFAULT 0 | Saldo inicial em centavos |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | 1=ativa, 0=inativa |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | Ordem de exibição |
| created_at | INTEGER | NOT NULL | Unix timestamp ms |
| updated_at | INTEGER | NOT NULL | Unix timestamp ms |

**Regras de negócio:**
- Deve existir pelo menos 1 conta ativa para o app funcionar
- Contas do tipo `credit_card_bill` são criadas automaticamente ao vincular um cartão de crédito
- Saldo atual = `initial_balance + SUM(entries.credit) - SUM(entries.debit)` para a conta
- Conta não pode ser deletada se tiver transações vinculadas (apenas inativada)

#### 4.2.2 `transactions` — Transações

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| description | TEXT | NOT NULL | Descrição da transação |
| amount | INTEGER | NOT NULL | Valor em centavos (sempre positivo) |
| type | TEXT | NOT NULL, ENUM | `income`, `expense`, `transfer` |
| date | INTEGER | NOT NULL | Data (Unix timestamp ms, midnight) |
| time | TEXT | NULLABLE | Hora "HH:mm" (opcional) |
| category_id | INTEGER | FK → categories | |
| entity_id | INTEGER | FK → entities, NULLABLE | Pagador/Recebedor |
| from_account_id | INTEGER | FK → accounts, NULLABLE | Conta de origem (para transferências e despesas) |
| to_account_id | INTEGER | FK → accounts, NULLABLE | Conta de destino (para transferências e receitas) |
| credit_card_id | INTEGER | FK → credit_cards, NULLABLE | Cartão utilizado |
| invoice_id | INTEGER | FK → invoices, NULLABLE | Fatura associada |
| installment_plan_id | INTEGER | FK → installment_plans, NULLABLE | |
| installment_number | INTEGER | NULLABLE | Número da parcela (ex: 3 de 12) |
| recurring_rule_id | INTEGER | FK → recurring_rules, NULLABLE | Regra que gerou |
| sentiment | INTEGER | NULLABLE, CHECK 1-5 | Avaliação: 1=Péssima, 2=Ruim, 3=Neutra, 4=Boa, 5=Ótima |
| notes | TEXT | NULLABLE | Observações livres |
| is_confirmed | INTEGER | NOT NULL, DEFAULT 1 | 1=confirmada, 0=pendente/sugerida |
| source | TEXT | NOT NULL, DEFAULT 'manual' | `manual`, `notification`, `recurring`, `import` |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |

**Regras de negócio:**
- Para `expense`: `from_account_id` é obrigatório (ou `credit_card_id`)
- Para `income`: `to_account_id` é obrigatório
- Para `transfer`: ambos `from_account_id` e `to_account_id` são obrigatórios
- Ao criar transação, entries são gerados automaticamente
- Ao usar cartão de crédito, a despesa debita a fatura do cartão (não a conta diretamente)

**Campo `sentiment` — Avaliação da Transação:**

O usuário pode avaliar cada transação com um sentimento de 1 a 5:

| Valor | Rótulo | Emoji | Cor |
|-------|--------|-------|-----|
| 1 | Péssima | 😡 | Vermelho escuro |
| 2 | Ruim | 😞 | Laranja |
| 3 | Neutra | 😐 | Cinza |
| 4 | Boa | 🙂 | Verde claro |
| 5 | Ótima | 😄 | Verde |
| null | Não avaliada | — | — |

**Uso futuro do sentiment:**
- Insights: "Suas compras avaliadas como 'Péssima' representam R$X/mês — considere eliminá-las"
- AI: correlacionar sentimento com categorias, horários, dias da semana
- Relatórios: filtrar por sentimento, gráfico de satisfação por categoria
- Gamificação: "Parabéns! 80% das suas transações este mês foram positivas!"

#### 4.2.3 `entries` — Lançamentos (Partida Dobrada)

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| transaction_id | INTEGER | FK → transactions, NOT NULL | |
| account_id | INTEGER | FK → accounts, NOT NULL | |
| type | TEXT | NOT NULL, ENUM | `debit`, `credit` |
| amount | INTEGER | NOT NULL | Valor em centavos |

**Regras:**
- Cada transação tem exatamente 2 entries (1 debit + 1 credit)
- `SUM(debit amounts) == SUM(credit amounts)` por transação
- Entries são criados/deletados atomicamente com a transação

#### 4.2.4 `categories` — Categorias Hierárquicas

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| name | TEXT | NOT NULL | Nome da categoria |
| parent_id | INTEGER | FK → categories, NULLABLE | Pai (null = raiz) |
| icon | TEXT | NOT NULL | Nome do ícone Material |
| color | INTEGER | NOT NULL | Cor ARGB |
| type | TEXT | NOT NULL, ENUM | `income`, `expense`, `both` |
| is_system | INTEGER | NOT NULL, DEFAULT 0 | Categoria padrão do sistema |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | |
| created_at | INTEGER | NOT NULL | |

**Regras:**
- Máximo 2 níveis de hierarquia (categoria → subcategoria)
- Categorias `is_system=1` não podem ser deletadas
- Ao deletar categoria com transações, solicitar reclassificação

**Categorias padrão de despesas:**

| Categoria | Ícone | Cor | Subcategorias |
|-----------|-------|-----|---------------|
| Alimentação | restaurant | #FF9800 | Restaurantes, Supermercado, Delivery, Lanches, Padaria |
| Moradia | home | #795548 | Aluguel, Condomínio, IPTU, Manutenção, Mobília |
| Transporte | directions_car | #2196F3 | Combustível, Estacionamento, App (Uber/99), Manutenção, IPVA, Seguro, Transporte Público |
| Saúde | medical_services | #F44336 | Plano de Saúde, Medicamentos, Consultas, Exames, Dentista |
| Educação | school | #9C27B0 | Mensalidade, Cursos Online, Livros, Material |
| Lazer | sports_esports | #E91E63 | Streaming, Jogos, Cinema, Viagens, Hobbies, Festas |
| Vestuário | checkroom | #00BCD4 | Roupas, Calçados, Acessórios |
| Contas Fixas | receipt_long | #607D8B | Energia, Água, Internet, Telefone, Gás |
| Pets | pets | #8BC34A | Ração, Veterinário, Acessórios, Banho/Tosa |
| Presentes | card_giftcard | #FF5722 | Presentes, Doações, Caridade |
| Pessoal | face | #673AB7 | Beleza, Higiene, Academia, Bem-estar |
| Assinaturas | subscriptions | #3F51B5 | Apps, Serviços, Clubes, Revistas |
| Taxas/Juros | account_balance | #9E9E9E | Tarifas Bancárias, Juros, IOF, Multas |
| Outros | help_outline | #BDBDBD | Sem categoria |

**Categorias padrão de receitas:**

| Categoria | Ícone | Cor | Subcategorias |
|-----------|-------|-----|---------------|
| Salário | payments | #4CAF50 | CLT, PJ, Freelance, Bônus |
| Investimentos | trending_up | #00C853 | Dividendos, Juros, Rendimentos, Aluguéis (FIIs) |
| Presentes | redeem | #FF9800 | Presentes Recebidos |
| Reembolsos | replay | #2196F3 | Estornos, Devoluções |
| Aluguéis | real_estate_agent | #795548 | Aluguel Recebido |
| Vendas | sell | #9C27B0 | Vendas de Itens |
| Outros | help_outline | #BDBDBD | Sem categoria |

#### 4.2.5 `entities` — Pagadores/Recebedores

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| name | TEXT | NOT NULL, UNIQUE | Nome (case-insensitive) |
| type | TEXT | NOT NULL, DEFAULT 'both' | `payee`, `payer`, `both` |
| default_category_id | INTEGER | FK → categories, NULLABLE | Sugestão automática |
| use_count | INTEGER | NOT NULL, DEFAULT 0 | Para ranking no autocomplete |
| created_at | INTEGER | NOT NULL | |

**Regras:**
- Criadas automaticamente ao preencher o campo "de/para" com nome novo
- Autocomplete ordena por `use_count` DESC
- O campo "de/para" da transação também oferece contas como opção (para transferências)
- `use_count` incrementa a cada uso
- Se uma entity tem `default_category_id`, a categoria é pré-selecionada ao escolher a entity

#### 4.2.6 `credit_cards` — Cartões de Crédito

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| name | TEXT | NOT NULL | Nome do cartão |
| account_id | INTEGER | FK → accounts, NOT NULL | Conta vinculada para pagamento |
| bill_account_id | INTEGER | FK → accounts, NOT NULL | Conta de fatura (tipo credit_card_bill, auto-criada) |
| icon | TEXT | NOT NULL, DEFAULT 'credit_card' | |
| color | INTEGER | NOT NULL | |
| closing_day | INTEGER | NOT NULL, CHECK 1-31 | Dia do fechamento |
| due_day | INTEGER | NOT NULL, CHECK 1-31 | Dia do vencimento |
| closing_anticipates_weekend | INTEGER | NOT NULL, DEFAULT 1 | Antecipa em fim de semana |
| closing_anticipates_holiday | INTEGER | NOT NULL, DEFAULT 0 | Antecipa em feriado |
| credit_limit | INTEGER | NOT NULL | Limite em centavos |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |

**Regras:**
- Ao criar cartão, uma conta do tipo `credit_card_bill` é criada automaticamente
- O `account_id` é a conta de onde sairá o pagamento da fatura
- O `bill_account_id` é a conta virtual que acumula as compras do cartão

**Lógica de fechamento:**
1. Calcular data de fechamento do mês
2. Se cai em sábado/domingo e `closing_anticipates_weekend=true`: antecipar para sexta-feira anterior
3. Se cai em feriado e `closing_anticipates_holiday=true`: antecipar para dia útil anterior
4. Feriados consultados da tabela `holidays`

#### 4.2.7 `invoices` — Faturas do Cartão

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| credit_card_id | INTEGER | FK → credit_cards, NOT NULL | |
| reference_month | INTEGER | NOT NULL | Mês de referência (YYYYMM, ex: 202607) |
| closing_date | INTEGER | NOT NULL | Data efetiva do fechamento |
| due_date | INTEGER | NOT NULL | Data efetiva do vencimento |
| total_amount | INTEGER | NOT NULL, DEFAULT 0 | Total da fatura em centavos |
| paid_amount | INTEGER | NOT NULL, DEFAULT 0 | Valor pago |
| status | TEXT | NOT NULL, DEFAULT 'open' | `open`, `closed`, `paid`, `partial`, `overdue` |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |

**Regras:**
- Faturas são criadas automaticamente conforme transações são adicionadas
- `total_amount` é calculado como SUM das transações na fatura
- Fatura `open`: pode receber novas transações
- Fatura `closed`: fechada, aguardando pagamento
- Ao pagar fatura, gera transferência: conta vinculada → conta da fatura
- Suportar pagamento parcial (status `partial`)

#### 4.2.8 `installment_plans` — Planos de Parcelamento

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| description | TEXT | NOT NULL | Descrição da compra |
| total_amount | INTEGER | NOT NULL | Valor total em centavos |
| num_installments | INTEGER | NOT NULL, CHECK >= 2 | Número total de parcelas |
| installment_amount | INTEGER | NOT NULL | Valor de cada parcela |
| start_date | INTEGER | NOT NULL | Data da primeira parcela |
| credit_card_id | INTEGER | FK → credit_cards, NULLABLE | Cartão (se parcelado no cartão) |
| account_id | INTEGER | FK → accounts, NULLABLE | Conta (se parcelado sem cartão) |
| category_id | INTEGER | FK → categories | |
| entity_id | INTEGER | FK → entities, NULLABLE | |
| status | TEXT | NOT NULL, DEFAULT 'active' | `active`, `completed`, `cancelled` |
| created_at | INTEGER | NOT NULL | |

**Regras:**
- `installment_amount = ceil(total_amount / num_installments)` (última parcela ajusta centavos)
- Ao criar plano, gera N transações futuras automaticamente (uma por mês/fatura)
- Se no cartão: cada parcela vai para a fatura do mês correspondente
- Se em conta: cada parcela debita a conta no dia especificado
- Status muda para `completed` quando todas as parcelas forem confirmadas

#### 4.2.9 `recurring_rules` — Regras de Recorrência

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| description | TEXT | NOT NULL | |
| amount | INTEGER | NOT NULL | Valor em centavos |
| type | TEXT | NOT NULL | `income`, `expense` |
| frequency | TEXT | NOT NULL | `daily`, `weekly`, `biweekly`, `monthly`, `yearly` |
| day_of_month | INTEGER | NULLABLE, CHECK 1-31 | Para `monthly` |
| day_of_week | INTEGER | NULLABLE, CHECK 1-7 | Para `weekly`/`biweekly` |
| month_of_year | INTEGER | NULLABLE, CHECK 1-12 | Para `yearly` |
| start_date | INTEGER | NOT NULL | |
| end_date | INTEGER | NULLABLE | null = infinito |
| account_id | INTEGER | FK → accounts | |
| category_id | INTEGER | FK → categories | |
| entity_id | INTEGER | FK → entities, NULLABLE | |
| auto_confirm | INTEGER | NOT NULL, DEFAULT 0 | Confirmar automaticamente |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | |
| last_generated_date | INTEGER | NULLABLE | Última data gerada |
| created_at | INTEGER | NOT NULL | |

**Regras:**
- O app gera transações pendentes para o período atual (ao abrir ou em background)
- Se `auto_confirm=true`, transações são geradas como confirmadas
- Se `auto_confirm=false`, transações são geradas como pendentes (notificação ao usuário)
- Detecção de mudança de valor: se o valor real difere do recorrente, notificar

#### 4.2.10 `goals` — Objetivos Financeiros

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| name | TEXT | NOT NULL | |
| target_amount | INTEGER | NOT NULL | Valor alvo em centavos |
| current_amount | INTEGER | NOT NULL, DEFAULT 0 | Acumulado |
| deadline | INTEGER | NULLABLE | Prazo (null = sem prazo) |
| account_id | INTEGER | FK → accounts | Conta vinculada |
| icon | TEXT | NOT NULL | |
| color | INTEGER | NOT NULL | |
| is_recurring | INTEGER | NOT NULL, DEFAULT 0 | |
| recurring_amount | INTEGER | NULLABLE | Valor recorrente (centavos) |
| recurring_frequency | TEXT | NULLABLE | `weekly`, `monthly`, `yearly` |
| status | TEXT | NOT NULL, DEFAULT 'active' | `active`, `completed`, `cancelled` |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |

**Regras:**
- Contribuições são registradas como transações (transferência para a conta do objetivo)
- `current_amount` é computado a partir das transações (não armazenado redundantemente)
- Ao atingir `target_amount`, status muda para `completed` + celebração
- Simulador: `(target_amount - current_amount) / meses_até_deadline = valor_mensal`

#### 4.2.11 `investments` — Investimentos

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| name | TEXT | NOT NULL | |
| type | TEXT | NOT NULL | `fixed_income`, `stocks`, `fiis`, `crypto`, `savings`, `cdb`, `tesouro_direto`, `other` |
| account_id | INTEGER | FK → accounts | Conta de investimento |
| initial_amount | INTEGER | NOT NULL | Valor investido (centavos) |
| current_amount | INTEGER | NOT NULL | Valor atual (centavos) |
| purchase_date | INTEGER | NOT NULL | |
| maturity_date | INTEGER | NULLABLE | Vencimento |
| annual_rate | REAL | NULLABLE | Taxa anual (%) |
| benchmark | TEXT | NULLABLE | CDI, IPCA, Ibovespa, etc. |
| icon | TEXT | NOT NULL, DEFAULT 'show_chart' | |
| color | INTEGER | NOT NULL | |
| notes | TEXT | NULLABLE | |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |

#### 4.2.12 `financings` — Financiamentos

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| name | TEXT | NOT NULL | |
| total_amount | INTEGER | NOT NULL | Valor total financiado |
| remaining_amount | INTEGER | NOT NULL | Saldo devedor |
| num_installments | INTEGER | NOT NULL | Total de parcelas |
| paid_installments | INTEGER | NOT NULL, DEFAULT 0 | Parcelas pagas |
| interest_rate | REAL | NOT NULL | Taxa de juros mensal (%) |
| type | TEXT | NOT NULL | `sac`, `price`, `other` |
| start_date | INTEGER | NOT NULL | |
| account_id | INTEGER | FK → accounts | Conta de débito |
| icon | TEXT | NOT NULL, DEFAULT 'real_estate_agent' | |
| color | INTEGER | NOT NULL | |
| notes | TEXT | NULLABLE | |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |

#### 4.2.13 `financing_installments` — Parcelas de Financiamento

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| financing_id | INTEGER | FK → financings, NOT NULL | |
| installment_number | INTEGER | NOT NULL | |
| due_date | INTEGER | NOT NULL | |
| principal | INTEGER | NOT NULL | Amortização (centavos) |
| interest | INTEGER | NOT NULL | Juros (centavos) |
| total | INTEGER | NOT NULL | Total da parcela |
| extra_payment | INTEGER | NOT NULL, DEFAULT 0 | Amortização extra |
| status | TEXT | NOT NULL, DEFAULT 'pending' | `pending`, `paid`, `overdue` |
| paid_date | INTEGER | NULLABLE | |

#### 4.2.14 `attachments` — Anexos

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| transaction_id | INTEGER | FK → transactions, NOT NULL | |
| file_path | TEXT | NOT NULL | Caminho relativo ao app dir |
| file_name | TEXT | NOT NULL | Nome original |
| mime_type | TEXT | NOT NULL | |
| size | INTEGER | NOT NULL | Bytes |
| created_at | INTEGER | NOT NULL | |

**Regras:**
- Arquivos são copiados para o diretório do app (não referenciados externamente)
- Suporta: imagens (jpg, png), PDFs, documentos
- Tamanho máximo: 10MB por arquivo
- Ao deletar transação, deletar anexos do filesystem

#### 4.2.15 `notification_patterns` — Padrões de Notificação

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| bank_name | TEXT | NOT NULL | Nome do banco |
| package_name | TEXT | NOT NULL | Package Android |
| pattern | TEXT | NOT NULL | Regex com named groups |
| sample_text | TEXT | NULLABLE | Exemplo para teste |
| is_system | INTEGER | NOT NULL, DEFAULT 0 | Padrão do sistema |
| is_active | INTEGER | NOT NULL, DEFAULT 1 | |
| created_at | INTEGER | NOT NULL | |

**Named groups esperados no regex:**
- `(?P<amount>...)` — valor
- `(?P<description>...)` — descrição (opcional)
- `(?P<merchant>...)` — estabelecimento (opcional)

**Padrões pré-cadastrados:**

| Banco | Package | Exemplo de Notificação |
|-------|---------|----------------------|
| Nubank | com.nu.production | "Compra aprovada - R$ 45,90 em MERCADO X" |
| Inter | br.com.intermedium | "Compra no débito de R$ 32,50 - FARMACIA Y" |
| Itaú | com.itau | "Compra aprovada R$120,00 LOJA Z" |
| Bradesco | com.bradesco | "Transação de R$ 85,00 aprovada" |
| Banco do Brasil | br.com.bb.android | "Compra cartão final 1234 R$67,90" |
| C6 Bank | com.c6bank.app | "Compra de R$ 55,00 aprovada em RESTAURANTE W" |
| PicPay | com.picpay | "Pagamento de R$ 25,00 realizado" |

#### 4.2.16 `holidays` — Feriados

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| id | INTEGER | PK, AUTO | |
| date | INTEGER | NOT NULL | Data do feriado |
| name | TEXT | NOT NULL | |
| is_national | INTEGER | NOT NULL, DEFAULT 0 | Feriado nacional |
| is_recurring | INTEGER | NOT NULL, DEFAULT 0 | Repete anualmente |
| recurring_month | INTEGER | NULLABLE | Mês (1-12) |
| recurring_day | INTEGER | NULLABLE | Dia (1-31) |

**Feriados nacionais pré-cadastrados:**
- 01/01 Ano Novo
- 21/04 Tiradentes
- 01/05 Dia do Trabalho
- 07/09 Independência
- 12/10 Nossa Sra. Aparecida
- 02/11 Finados
- 15/11 Proclamação da República
- 25/12 Natal
- (Carnaval, Sexta-feira Santa, Corpus Christi — móveis, calculados anualmente)

#### 4.2.17 `app_settings` — Configurações

| Campo | Tipo | Constraints | Descrição |
|-------|------|------------|-----------|
| key | TEXT | PK | Chave da configuração |
| value | TEXT | NOT NULL | Valor serializado |

**Chaves:**
- `theme_mode`: `light`, `dark`, `system`
- `security_enabled`: `true`, `false`
- `security_type`: `biometric`, `pin`
- `security_pin_hash`: hash do PIN
- `onboarding_completed`: `true`, `false`
- `last_backup_date`: Unix timestamp
- `notification_capture_enabled`: `true`, `false`

---

## 5. Design System — Material Design 3 Expressive

### 5.1 Implementação

Implementação **manual** via `ThemeExtension` para controle total sobre shapes, motion e tipografia expressiva. Não depende de pacotes da comunidade para o design system core.

### 5.2 Color System

**Abordagem:** `ColorScheme.fromSeed()` com cores vibrantes no estilo M3 Expressive.

```
Seed primário: Deep Purple (#6750A4)
Light mode: Superfícies claras, tons vibrantes
Dark mode: Superfícies escuras profundas, tons luminosos
```

**Cores funcionais (fixas, não geradas pelo seed):**

| Função | Light Mode | Dark Mode | Uso |
|--------|-----------|-----------|-----|
| Positivo/Receita | #2E7D32 | #66BB6A | Receitas, saldo positivo, metas atingidas |
| Negativo/Despesa | #C62828 | #EF5350 | Despesas, saldo negativo, alertas |
| Transferência | #1565C0 | #42A5F5 | Transferências entre contas |
| Aviso | #F57F17 | #FFD54F | Faturas próximas, orçamento apertado |
| Investimento | #6A1B9A | #AB47BC | Investimentos, rendimentos |

**Suporte a temas:** Light, Dark, e "Seguir sistema"

### 5.3 Shape System

**Escala de cantos com 10 níveis (0-9):**

| Nível | Radius | Uso |
|-------|--------|-----|
| 0 | 0dp | Sharp corners (botões de toolbar) |
| 1 | 4dp | Chips, badges |
| 2 | 8dp | Cards pequenos, inputs |
| 3 | 12dp | Cards médios |
| 4 | 16dp | Cards grandes, dialogs |
| 5 | 20dp | Bottom sheets |
| 6 | 24dp | Cards expressivos |
| 7 | 28dp | FABs, navigation bar |
| 8 | 32dp | Containers expressivos grandes |
| 9 | FULL | Pill shapes (chips arredondados, avatares) |

**Shapes expressivas (cantos assimétricos):**
- Card de transação: `tl:16, tr:16, bl:4, br:4`
- Card de saldo: `tl:28, tr:8, bl:8, br:28` (visual tension)
- FAB: morphing entre circle e rounded square ao scrollar

### 5.4 Motion System (Spring-Based)

**Duas categorias de springs:**

1. **Spatial** (posição, escala, rotação, shape): bounce/overshoot
2. **Effects** (cor, opacidade): smooth, sem bounce

**Três velocidades:**

| Velocidade | Spatial (bounce) | Effects (smooth) |
|------------|-----------------|-----------------|
| Fast | mass:1, stiff:400, damp:15 | mass:1, stiff:500, damp:35 |
| Default | mass:1, stiff:200, damp:10 | mass:1, stiff:300, damp:30 |
| Slow | mass:1, stiff:120, damp:8 | mass:1, stiff:200, damp:25 |

### 5.5 Typography

**Font principal:** Inter (Google Fonts)
**Font de valores monetários:** JetBrains Mono ou Roboto Mono (tabular figures)

**Variações expressivas adicionais:**
- `displayLargeEmphasized`: peso extra-bold para saldos grandes
- `headlineMediumEmphasized`: para títulos de seção
- `titleLargeEmphasized`: para nomes de conta/cartão

### 5.6 Iconografia

Usar **Material Symbols** (versão mais recente dos Material Icons) com estilo `Outlined` e peso variável.

### 5.7 Micro-Animações

| Contexto | Tipo | Spring |
|----------|------|--------|
| Card aparece na lista | Slide up + fade in (staggered) | Spatial Default |
| Valor de saldo atualiza | Number counter (tween) | Effects Default |
| Categoria selecionada | Scale up + color change | Spatial Fast + Effects Fast |
| Progress ring de objetivo | Fill animation com overshoot | Spatial Slow |
| Swipe para deletar | Drag + reveal actions | Spatial Fast |
| Transição entre telas | Container transform | Spatial Default |
| FAB ao scrollar | Shape morph (circle → rounded rect) | Spatial Default |
| Tab selecionada | Indicator slide + bounce | Spatial Fast |
| Empty state | Lottie loop | — |
| Sucesso (meta atingida, etc) | Lottie celebration | — |
| Donut chart aparece | Segments animate in (staggered) | Spatial Slow |
| Número negativo | Shake animation | Spatial Fast |

---

## 6. Telas e Fluxos

### 6.1 Navegação Principal

**Bottom Navigation Bar** com 4 itens:
1. 🏠 **Dashboard** — Visão geral
2. 💸 **Transações** — Lista e filtros
3. 📊 **Relatórios** — Gráficos e análises
4. ☰ **Mais** — Menu com todas as features

**FAB flutuante global**: "+" para nova transação (sempre visível)

### 6.2 Onboarding (Wizard)

**Tela 1 — Boas-vindas:**
- Logo + animação Lottie
- Breve descrição do app
- Botão "Começar"

**Tela 2 — Criar primeira conta:**
- Nome da conta (sugestão: "Conta Principal")
- Tipo (Corrente selecionado por padrão)
- Saldo inicial
- Ícone e cor

**Tela 3 — Categorias:**
- Mostrar categorias padrão pré-selecionadas
- Permitir desmarcar/marcar
- Opção "Personalizar depois"

**Tela 4 — Notificações (Android apenas):**
- Explicar o que faz
- Solicitar permissão `NotificationListenerService`
- Opção "Configurar depois"

**Tela 5 — Segurança:**
- Configurar biometria ou PIN
- Opção "Pular"

### 6.3 Dashboard

```
┌──────────────────────────────────┐
│  Saldo Total         R$ 12.450  │  ← Animated counter
│  ────────────────────────────── │
│  Livre p/ gastar     R$ 3.200   │  ← Saldo - comprometido
├──────────────────────────────────┤
│  ┌─────────┐  ┌────────────────┐│
│  │ Receitas │  │   Despesas     ││
│  │ R$8.000  │  │   R$4.800      ││  ← Mini bar chart
│  └─────────┘  └────────────────┘│
├──────────────────────────────────┤
│  Gastos por Categoria            │
│  ┌──────────────────┐           │
│  │   🍩 Donut Chart  │           │  ← Top 5 + Outros
│  └──────────────────┘           │
├──────────────────────────────────┤
│  Próximas Contas                 │
│  📅 Energia    05/jul   R$180   │
│  📅 Internet   10/jul   R$120   │
│  📅 Fatura Nu  15/jul   R$2.300 │
├──────────────────────────────────┤
│  Meus Objetivos                  │
│  🎯 Viagem ████████░░ 80%      │  ← Progress ring
│  🎯 Carro  ███░░░░░░░ 30%      │
├──────────────────────────────────┤
│  💡 Insight                      │
│  "Alimentação 30% acima da      │
│   média este mês"               │
└──────────────────────────────────┘
        [➕ FAB]
```

### 6.4 Lista de Transações

```
┌──────────────────────────────────┐
│ 🔍 Buscar...          🔽 Filtros│
├──────────────────────────────────┤
│ Hoje, 27 de Maio                 │
│ ┌──────────────────────────────┐ │
│ │ 🍔 Mercado BH      -R$245   │ │  ← Swipe: editar/deletar
│ │    Alimentação  😐  14:30    │ │  ← Sentiment emoji
│ ├──────────────────────────────┤ │
│ │ 🚗 Uber            -R$32    │ │
│ │    Transporte   😞  09:15    │ │
│ └──────────────────────────────┘ │
│ Ontem, 26 de Maio                │
│ ┌──────────────────────────────┐ │
│ │ 💰 Salário         +R$5.000 │ │
│ │    Salário      😄  08:00    │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```

### 6.5 Formulário de Transação

```
┌──────────────────────────────────┐
│  [Despesa] [Receita] [Transfer.] │  ← Tabs
├──────────────────────────────────┤
│                                  │
│         R$ 0,00                  │  ← Display grande
│                                  │
│  [7] [8] [9]                     │
│  [4] [5] [6]                     │  ← Teclado numérico custom
│  [1] [2] [3]                     │
│  [,] [0] [⌫]                    │
├──────────────────────────────────┤
│  📝 Descrição                    │
│  🏷️ Categoria  [grid de ícones] │
│  👤 De/Para    [autocomplete]    │
│  🏦 Conta      [selector]       │
│  💳 Cartão     [selector]       │
│  📅 Data       27/05/2026       │
│  ⏰ Hora       14:30            │
├──────────────────────────────────┤
│  Como você avalia esta compra?   │
│  [😡] [😞] [😐] [🙂] [😄]      │  ← Sentiment selector
├──────────────────────────────────┤
│  ➕ Parcelamento                 │
│  🔄 Recorrência                 │
│  📎 Anexar comprovante          │
│  📝 Notas                       │
├──────────────────────────────────┤
│         [  Salvar  ]             │
└──────────────────────────────────┘
```

### 6.6 Cartão de Crédito — Detalhe

```
┌──────────────────────────────────┐
│  💳 Nubank Platinum              │
│  ████████████░░░░  R$2.300/5.000│  ← Limite usado/total
├──────────────────────────────────┤
│  Fatura Atual (Jun/2026)         │
│  Status: Aberta                  │
│  Fecha: 05/Jun  Vence: 15/Jun   │
│  Total: R$ 2.300,00             │
├──────────────────────────────────┤
│  Transações da Fatura            │
│  🍔 Restaurante X    R$85,00    │
│  👕 Loja Y           R$120,00   │
│  📱 3/12 iPhone      R$416,00   │  ← Parcela
│  ...                             │
├──────────────────────────────────┤
│  Próximas Faturas                │
│  Jul/2026  R$1.200 (projeção)   │  ← Parcelas futuras
│  Ago/2026  R$  800 (projeção)   │
├──────────────────────────────────┤
│  [Pagar Fatura]                  │
└──────────────────────────────────┘
```

### 6.7 Relatórios

**Tipos de gráficos disponíveis:**

| Gráfico | Descrição | Implementação |
|---------|-----------|--------------|
| Donut/Ring | Gastos por categoria (top N + outros) | fl_chart PieChart |
| Bar horizontal | Ranking de categorias por valor | fl_chart BarChart |
| Bar vertical | Receita vs Despesa por mês | fl_chart BarChart |
| Line | Evolução do saldo / net worth ao longo do tempo | fl_chart LineChart |
| Waterfall | Income → Expenses → Bottom Line mensal | Custom com fl_chart |
| Heatmap | Intensidade de gastos por dia da semana / hora | Custom widget |
| Treemap | Drill-down hierárquico (categoria → sub → entity) | Custom widget |
| Sankey | Fluxo: receita → categorias → destinos (Fase 2) | Custom widget |
| Radar/Polar | "Score" de saúde financeira | Custom widget |

**Filtros globais:** Período, Contas, Categorias, Tipo

**Comparações:** Mês atual vs anterior, Planejado vs Real

### 6.8 Mais (Menu)

```
┌──────────────────────────────────┐
│  🏦 Contas                       │
│  💳 Cartões de Crédito           │
│  🏷️ Categorias                  │
│  🔄 Recorrentes                  │
│  📦 Parcelamentos                │
│  🎯 Objetivos                    │
│  📈 Investimentos                │
│  🏠 Financiamentos               │
│  🔔 Notificações                 │
│  💾 Backup & Export              │
│  ⚙️ Configurações               │
└──────────────────────────────────┘
```

---

## 7. Fluxos de Negócio

### 7.1 Criar Transação — Despesa

1. Usuário abre formulário (FAB ou lista)
2. Seleciona tab "Despesa"
3. Digita valor no teclado numérico
4. Preenche descrição
5. Seleciona categoria (grid de ícones ou busca)
6. Preenche "De/Para" (autocomplete de entities + contas)
   - Se nome novo: entity criada automaticamente
   - Se entity tem `default_category_id`: categoria pré-selecionada
7. Seleciona conta de origem OU cartão de crédito
8. (Opcional) Avalia sentimento: 😡😞😐🙂😄
9. (Opcional) Configura parcelamento: total + nº parcelas
10. (Opcional) Configura recorrência
11. (Opcional) Anexa comprovante
12. Salva
13. **Backend:**
    - Se simples: cria transaction + 2 entries (debit na despesa, credit na conta)
    - Se parcelada: cria installment_plan + N transactions futuras
    - Se recorrente: cria recurring_rule (futuras transações geradas automaticamente)
    - Se cartão: entries debitam a fatura, não a conta diretamente

### 7.2 Criar Transação — Receita

Similar à despesa, mas:
- Conta é destino (crédito na conta)
- Não permite cartão de crédito
- Categorias filtradas por tipo `income`

### 7.3 Transferência entre Contas

1. Seleciona tab "Transferência"
2. Digita valor
3. Seleciona conta de **origem** e **destino**
4. Salva
5. **Backend:** cria 2 entries: debit na origem, credit no destino

### 7.4 Fluxo do Cartão de Crédito

1. **Compra:** Transação debita a fatura do cartão (conta `credit_card_bill`)
2. **Fechamento:** No dia de fechamento (ajustado por feriados/finais de semana):
   - Fatura muda status para `closed`
   - Total é calculado
   - Nova fatura `open` é criada para o próximo ciclo
3. **Pagamento:** Usuário clica "Pagar Fatura"
   - Gera transferência: conta vinculada → conta da fatura
   - Suporta pagamento total ou parcial
   - Fatura muda para `paid` ou `partial`
4. **Atraso:** Se passa do vencimento sem pagamento: status `overdue`

### 7.5 Captura de Notificações (Android)

1. App registra `NotificationListenerService`
2. Notificação de app bancário chega
3. Service extrai: packageName, title, text
4. Compara com `notification_patterns` ativos
5. Se match: extrai amount, description, merchant via regex
6. Cria transação com `is_confirmed=false`, `source='notification'`
7. Sugestão aparece na fila de revisão (e notificação in-app)
8. Usuário revisa: confirma (com ajustes opcionais) ou descarta

### 7.6 Geração de Recorrentes

1. Ao abrir o app (ou em background):
2. Para cada `recurring_rule` ativa:
3. Calcular próximas datas desde `last_generated_date` até hoje
4. Para cada data: gerar transação pendente
5. Se `auto_confirm=true`: marcar como confirmada
6. Atualizar `last_generated_date`

---

## 8. Nix Flake

```nix
{
  description = "BestFin - Personal Finance App";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs = {
      url = "github:nickcao/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, android-nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          platform-tools
          build-tools-34-0-0
          platforms-android-34
          emulator
        ]);
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter
            jdk17
            androidSdk
            # Linux desktop deps
            pkg-config
            gtk3
            pcre2
            epoxy
          ];

          env = {
            ANDROID_HOME = "${androidSdk}/share/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdk}/share/android-sdk";
            JAVA_HOME = "${pkgs.jdk17}";
          };

          shellHook = ''
            export GRADLE_USER_HOME="$HOME/.gradle"
            export PATH="$HOME/.pub-cache/bin:$PATH"
            echo "🏦 BestFin dev environment ready"
          '';
        };
      });
}
```

---

## 9. Fases de Entrega

### Fase 1 — Fundação (MVP)
- Setup: flake.nix, projeto Flutter, estrutura de pastas
- Design system M3 Expressive completo (tema, cores, shapes, motion)
- Database Drift (tabelas core)
- Onboarding wizard
- CRUD Contas (com tipos, ícones, cores)
- CRUD Categorias (hierárquicas, ícones, cores, padrões)
- CRUD Transações (despesa, receita, transferência, partida dobrada)
- Autocomplete de entities
- Sentiment selector nas transações
- Dashboard (saldo, gastos, donut chart, mini bars)
- Navegação (bottom nav + FAB)
- Segurança (biometria/PIN)

### Fase 2 — Recursos Financeiros
- Cartões de crédito + faturas + fechamento inteligente
- Compras parceladas (wizard)
- Transações recorrentes
- Objetivos financeiros (progresso visual)
- Relatórios avançados (todos os gráficos)
- Export CSV/JSON/PDF
- "Livre para gastar"
- Calendário de contas

### Fase 3 — Automação & Avançado
- Notificações Android (NotificationListenerService)
- Notificações Linux (D-Bus)
- Fila de revisão
- Padrões customizáveis
- Investimentos
- Financiamentos (SAC/Price)
- Gamificação
- Insights no dashboard

### Fase 4 — AI & Sync
- AI categorização
- OCR de comprovantes
- Cash flow forecasting
- Detecção de anomalias
- Sync multi-dispositivo
- Colaboração

---

## 10. Testes

### Unit Tests
- Models: serialização, cálculos
- Use Cases: lógica de negócio (partida dobrada, fechamento de fatura, parcelamento)
- DAOs: queries do Drift
- Utils: formatters, validators, parsers

### Widget Tests
- Formulários: validação, interação
- Listas: rendering, swipe actions
- Charts: dados corretos
- Widgets custom: sentiment selector, numeric keypad

### Integration Tests
- Fluxo completo: onboarding → criar conta → transação → dashboard
- Cartão: compra → fatura → pagamento
- Parcelamento: criar → verificar futuras
- Backup: export → import → verificar dados

### Comandos
```bash
nix develop -c flutter test                    # Unit + widget
nix develop -c flutter test integration_test/  # Integration
nix develop -c flutter analyze                 # Static analysis
```
