# Tarefa 10 — Compras Parceladas

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🔴 Crítica
> **Estimativa:** Média-Grande
> **Última atualização:** 2026-05-27

## Descrição

Implementar sistema de parcelamento: wizard de criação, geração automática de parcelas futuras, vinculação com faturas de cartão, e visão de compromissos futuros.

Parcelamento é essencial no contexto brasileiro — praticamente toda compra pode ser dividida. O sistema precisa gerar as parcelas automaticamente, distribuí-las nas faturas corretas e oferecer uma visão consolidada dos compromissos futuros.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [09-credit-cards](./09-credit-cards.md) | Cartões de crédito e faturas | ⬜ Pendente |

## Subtarefas

### Modelos e Repositórios

 - [x] Criar `lib/features/installments/domain/models/installment_plan.dart`
 - [x] Criar `lib/features/installments/data/repositories/installment_repository.dart`

### Lógica de Parcelamento

 - [x] Implementar wizard de parcelamento:
   - [x] Valor total → nº parcelas → auto-calcula valor de cada parcela
   - [x] Última parcela ajusta centavos (ex.: R$100,00 em 3x = R$33,33 + R$33,33 + R$33,34)
 - [x] Gerar N transações futuras automaticamente (uma por mês/fatura)
 - [x] Se no cartão: cada parcela vai para a fatura do mês correspondente
 - [x] Se em conta: cada parcela debita a conta no dia especificado
 - [x] Status `completed` quando todas as parcelas forem confirmadas

### Telas e UI

 - [x] Criar tela de lista de parcelamentos (ativos e concluídos)
 - [x] Criar widget de progresso do parcelamento (x/N parcelas)
 - [x] Criar timeline de compromissos futuros (todas as parcelas futuras por mês)

### Integração

 - [x] Integrar com form de transação: opção de parcelamento (toggle + nº parcelas)

## Critérios de Aceitação

 - [x] Wizard funcional com cálculo correto de parcelas
 - [x] Parcelas geradas e distribuídas corretamente nas faturas do cartão
 - [x] Última parcela ajusta centavos para bater o total exato
 - [x] Visão de compromissos futuros consolidada por mês
 - [x] Status do parcelamento atualizado automaticamente para `completed`

## Arquivos Principais

```
lib/features/installments/
├── domain/
│   └── models/
│       └── installment_plan.dart
├── data/
│   └── repositories/
│       └── installment_repository.dart
└── presentation/
    ├── screens/
    │   ├── installments_list_screen.dart
    │   └── installment_wizard_screen.dart
    └── widgets/
        ├── installment_progress_widget.dart
        └── future_commitments_timeline.dart
```

## Notas e Considerações

- **Ajuste de centavos**: Sempre calcular `valor_parcela = (total / n).truncate(2)` e colocar a diferença na última parcela. Nunca arredondar para cima em todas.
- **Cartão vs conta**: O comportamento muda conforme o destino. No cartão, as parcelas devem ser associadas à fatura correta baseada na data. Em conta corrente, viram transações agendadas.
- **Cancelamento**: Considerar o que acontece ao cancelar um parcelamento — parcelas futuras não confirmadas devem ser removidas.
- **Identificação visual**: No form de transação, parcelas devem ter label "(x/N)" no título para fácil identificação.
- **Performance**: A geração de N transações deve ser atômica (transaction no banco) para evitar inconsistências.
