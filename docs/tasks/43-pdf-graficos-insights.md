# Tarefa 43 — Gráficos e Insights no Export PDF

> **Fase:** 3 — Refinamentos
> **Prioridade:** 🟢 Média
> **Estimativa:** Pequena
> **Última atualização:** 2026-07-09

## Descrição

Evoluir o relatório PDF (Tarefas 14 e 40) com gráficos nativos do package `pdf` e uma seção de insights textuais calculados a partir dos dados no momento da exportação.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [14-export](./14-export.md) | Export e Backup | ✅ Concluída |
| [40-relatorio-mensal-export](./40-relatorio-mensal-export.md) | Relatório mensal (evolução mensal + presets) | ✅ Concluída |

## Subtarefas

### PDF (`export_pdf.dart`)

 - [x] Gráfico de barras receitas x despesas por mês (`pw.Chart` + `pw.BarDataSet`) na seção "Evolução Mensal" (2+ meses), com eixo Y de passos "redondos" (`_niceStep`) e legenda manual
 - [x] Gráfico de pizza (`pw.PieGrid` + `pw.PieDataSet`) das despesas por categoria: top 5 + fatia "Outros", cores das categorias com fallback, legenda com % e valor
 - [x] Seção "Insights do Período" (`_buildInsights`): taxa de poupança (ou estouro sobre receitas), categoria dominante, gasto médio diário, maior despesa individual, mês de pico vs. média mensal, variação do último mês vs. anterior, quantidade de despesas e ticket médio
 - [x] Cada insight/gráfico só é renderizado quando há dados que o sustentem (períodos vazios continuam gerando PDF válido)

## Critérios de Aceitação

 - [x] `flutter analyze` sem novos avisos nos arquivos alterados
 - [x] Testes de `test/features/backup/` passando (21/21)
 - [x] Verificação visual dos PDFs gerados (multi-mês e mês único)

## Arquivos Principais

```
lib/features/backup/
└── domain/usecases/export_pdf.dart   # gráficos (barras/pizza) + _buildInsights
```

## Notas e Considerações

- Textos usam apenas caracteres WinAnsi (Helvetica não renderiza U+2014 etc.).
- Possíveis próximos passos: narrativa via LLM on-device (Task 25 — Narrador de Relatório), gráfico de linha do saldo acumulado.
