# Tarefa 40 — Relatório Mensal (Export PDF)

> **Fase:** 3 — Refinamentos
> **Prioridade:** 🟢 Média
> **Estimativa:** Pequena
> **Última atualização:** 2026-07-09

## Descrição

Evoluir o export PDF (Tarefa 14) para funcionar como relatório mensal: presets de período na tela de Export & Backup e seção de evolução mês a mês no PDF gerado.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [14-export](./14-export.md) | Export e Backup | ✅ Concluída |

## Subtarefas

### Tela de Export & Backup

 - [x] Adicionar presets de período (`ChoiceChip`): Este mês, Mês anterior, Últimos 3 meses, Este ano
 - [x] Presets preenchem `_startDate`/`_endDate` (fim do período em 23:59:59); seleção manual ou limpeza desmarca o preset

### PDF (`export_pdf.dart`)

 - [x] Acumular receitas/despesas por mês (`monthlyIncomeCents`/`monthlyExpenseCents`)
 - [x] Seção "Evolução Mensal": tabela Mês | Receitas | Despesas | Saldo, com linha final de média mensal (exibida apenas quando o período cobre 2+ meses)
 - [x] Cabeçalho do período exibe o nome do mês ("Julho 2026") quando o intervalo cobre exatamente um mês-calendário

## Critérios de Aceitação

 - [x] `flutter analyze` sem novos avisos nos arquivos alterados
 - [x] Testes de `test/features/backup/` passando

## Arquivos Principais

```
lib/features/backup/
├── domain/usecases/export_pdf.dart          # seção Evolução Mensal + label de período
└── presentation/screens/backup_screen.dart  # presets de período
```

## Notas e Considerações

- Nomes de meses em pt-BR via lista estática (evita dependência de `initializeDateFormatting`).
- Possíveis próximos passos sugeridos: importação OFX (extratos bancários), backup automático agendado com retenção, backup criptografado com senha, export XLSX.
