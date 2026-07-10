---
type: Domain Model
title: Transaction (Transação)
description: Entidade raiz de uma operação financeira; contém metadados e agrega Entries.
tags: [domínio, transação, double-entry]
timestamp: 2026-06-29T00:00:00Z
---

## Definição

`Transaction` é a entidade raiz de uma operação financeira. Ela não carrega valor monetário diretamente — o valor está distribuído entre seus [lançamentos (Entry)](entry.md).

## Campos Principais

| Campo | Tipo | Descrição |
|---|---|---|
| `uuid` | String | Identificador único (UUID v4) |
| `date` | DateTime | Data da transação |
| `description` | String | Descrição legível pelo usuário |
| `type` | TransactionType | `expense` \| `income` \| `transfer` |
| `categoryId` | String? | FK para [Categoria](category.md) |
| `entityName` | String? | Nome do estabelecimento/pessoa |
| `isRecurring` | bool | Gerada por regra recorrente? |
| `recurringRuleId` | String? | FK para RecurringRule |
| `groupId` | String? | Agrupa lançamentos de um lote "Inserir vários" em um bloco exibido como um só |
| `sentiment` | SentimentType? | `happy` \| `neutral` \| `regret` |
| `attachmentPath` | String? | Caminho de arquivo anexado |

## Tipos de Transação

- `expense` — despesa; débita uma conta de despesa, credita a conta de pagamento
- `income` — receita; debita a conta de destino, credita a fonte de renda
- `transfer` — transferência entre contas; não afeta categorias de despesa/receita

## Arquivos

- `lib/features/transactions/domain/models/transaction.dart` — modelo de domínio
- `lib/core/database/tables/transactions.dart` — tabela Drift
- `lib/core/database/daos/transactions_dao.dart` — DAO
- `lib/features/transactions/data/repositories/transaction_repository.dart`
- `lib/features/transactions/domain/usecases/create_transaction.dart`

## Relações

- Uma `Transaction` tem 2+ [Entry](entry.md) que devem balancear (débito = crédito).
- Pertence a zero ou uma [Categoria](category.md).
- Pode ser originada por uma `RecurringRule` (veja [Recorrências](../features/recurring.md)).
- Em cartão de crédito, pode estar associada a uma `Invoice` (veja [Cartões](../features/credit-cards.md)).

# Citations

[1] [Contabilidade de Partida Dobrada](../architecture/double-entry.md)
