# Tarefa 14 — Export e Backup

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🟢 Média
> **Estimativa:** Média
> **Última atualização:** 2026-05-27

## Descrição

Implementar export de dados em CSV, JSON e PDF, além de backup/restore do banco SQLite.

Dados financeiros são sensíveis e valiosos. O usuário precisa de formas de exportar seus dados para análise externa, gerar relatórios em PDF para compartilhar, e fazer backup completo do banco para segurança.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [06-transactions](./06-transactions.md) | Transações e categorização | ⬜ Pendente |

## Subtarefas

### Use Cases de Export

 - [x] Criar `lib/features/backup/domain/usecases/export_csv.dart`: exportar transações filtradas para CSV
 - [x] Criar `lib/features/backup/domain/usecases/export_json.dart`: exportar dados completos para JSON
 - [x] Criar `lib/features/backup/domain/usecases/export_pdf.dart`: gerar relatório PDF com gráficos, tabelas e resumo

### Use Cases de Import/Backup

 - [x] Criar `lib/features/backup/domain/usecases/import_data.dart`: importar de CSV/JSON
 - [x] Criar `lib/features/backup/domain/usecases/backup_database.dart`: copiar arquivo `.sqlite` para location escolhida

### Telas e UI

 - [x] Criar tela de backup: botões de export (CSV/JSON/PDF), backup SQLite, import, restore

### Funcionalidades Específicas

 - [x] Implementar share via `share_plus` para compartilhar arquivos gerados
 - [x] PDF: usar package `pdf` com layout de relatório:
   - [x] Cabeçalho com nome do app e período
   - [x] Tabelas de transações por categoria
   - [x] Resumo com valores totais (receita, despesa, saldo)
   - [x] Gráficos simplificados (pizza de categorias)
 - [x] Rodar operações pesadas em isolates para não travar UI

## Critérios de Aceitação

 - [x] CSV com transações exporta corretamente (encoding UTF-8 com BOM para Excel)
 - [x] JSON com estrutura completa do banco (todas as tabelas)
 - [x] PDF com layout profissional e dados corretos
 - [x] Backup SQLite cria cópia funcional do banco
 - [x] Import restaura dados corretamente (CSV e JSON)
 - [x] Share funcional em todos os formatos

## Arquivos Principais

```
lib/features/backup/
├── domain/
│   └── usecases/
│       ├── export_csv.dart
│       ├── export_json.dart
│       ├── export_pdf.dart
│       ├── import_data.dart
│       └── backup_database.dart
└── presentation/
    ├── screens/
    │   └── backup_screen.dart
    └── widgets/
        ├── export_button.dart
        └── import_progress_widget.dart
```

## Notas e Considerações

- **UTF-8 BOM**: O CSV precisa do BOM (`\uFEFF`) no início para que o Excel interprete acentos corretamente. Separador padrão: `;` (padrão brasileiro) com opção de `,`.
- **Isolates**: Export de PDF e processamento de import devem rodar em `Isolate.run()` ou `compute()` para não bloquear a UI. Mostrar progress indicator.
- **PDF layout**: Usar `package:pdf` (não confundir com `printing`). Criar um template reutilizável com header, footer com paginação, e estilos consistentes.
- **Import com validação**: Ao importar CSV/JSON, validar campos obrigatórios, formatos de data e valores numéricos. Mostrar preview antes de confirmar.
- **Backup incremental**: Na v1, fazer backup completo (cópia do arquivo SQLite). Backup incremental pode ser considerado futuramente.
- **Segurança**: Considerar oferecer opção de criptografar o backup com senha do usuário.
- **Tamanho**: Para bancos grandes, o export pode demorar. Sempre mostrar progresso e permitir cancelamento.
