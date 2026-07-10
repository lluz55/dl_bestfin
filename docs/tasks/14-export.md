# Tarefa 14 — Export e Backup

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🟢 Média
> **Estimativa:** Média
> **Última atualização:** 2026-07-09 (versionamento de backups)

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

## Correções (2026-07-09)

 - [x] Exports falhavam no Linux desktop: `share_plus` não implementa `shareXFiles` fora de Android/iOS. Agora o desktop usa diálogo "Salvar como" (`FilePicker.saveFile`); share permanece no mobile.
 - [x] CSV/PDF falhavam em qualquer plataforma: `compute()` recebia closure capturando o `AppDatabase` (handles nativos do SQLite não são enviáveis a isolates). Exports CSV/PDF agora executam no isolate principal; o stringify do JSON (dados puros) continua em isolate.
 - [x] Erros de export/import agora são logados no terminal via `debugPrint` (antes só apareciam no snackbar).
 - [x] Teste `test/features/backup/export_pdf_test.dart` cobrindo período multi-mês, mês único e período vazio.
 - [x] `zenity` adicionado ao devShell do `flake.nix`: o `file_picker` no Linux depende dele para os diálogos de abrir/salvar arquivo (afetava exports e imports).
 - [x] Os 5 providers de use case de backup capturavam o banco com `ref.read(databaseProvider)` — após um `invalidate` (clear-all, restore), ficavam presos a uma instância fechada e o restore/export seguinte falhava ou não persistia. Trocados para `ref.watch` (idioma do restante do projeto). Testes de persistência do ciclo restore→close→reopen em `restore_reopen_test.dart`.
 - [x] `restoreBackup` era destrutivo: deletava o banco ativo **antes** de copiar o backup — selecionar o próprio `bestfin.sqlite` como origem destruía o banco (delete apagava a origem e o copy falhava). Agora: rejeita o banco ativo como origem (paths canonicalizados), copia para `.restore-tmp` e faz `rename` atômico por cima, cria o diretório pai se faltar e remove journals WAL/SHM órfãos. Testes em `backup_database_test.dart`.

## Versionamento & integridade de backup (2026-07-09)

 - [x] Fonte única `domain/backup_version.dart`: `kBackupFormatVersion`, `kMinSupportedBackupFormatVersion` e `BackupIncompatibleException`.
 - [x] JSON grava `schema_version` (schema Drift dos dados) além do `version` do formato. `import_data.dart` valida compatibilidade em `previewJson` e `restoreJson` (rejeita formato/schema mais novo que a build; revalida antes de apagar o banco). Diálogo de restauração mostra "Versão dos dados".
 - [x] Restore SQLite lê `user_version` do header (offset 60) e rejeita backup de schema mais novo (`BackupIncompatibleException`) — evita erro obscuro do Drift ao reabrir.
 - [x] **Bug corrigido**: backup do banco travava/falhava com `PathNotFoundException` (`bestfin.sqlite` inexistente) após clear-all — no desktop copiava o arquivo sem checar existência. Além disso, copiar em modo WAL sem checkpoint gerava backup desatualizado. `_prepareBackupSource` agora roda `PRAGMA wal_checkpoint(TRUNCATE)` (mescla WAL + força abertura do `LazyDatabase`, criando o arquivo) e valida existência; `shareBackup` e o novo `saveBackupTo` passam por ele.
 - [x] Testes de compatibilidade (schema novo/antigo, formato novo) em `backup_database_test.dart` e `import_data_test.dart`.

## Notas e Considerações

- **UTF-8 BOM**: O CSV precisa do BOM (`\uFEFF`) no início para que o Excel interprete acentos corretamente. Separador padrão: `;` (padrão brasileiro) com opção de `,`.
- **Isolates**: Export de PDF e processamento de import devem rodar em `Isolate.run()` ou `compute()` para não bloquear a UI. Mostrar progress indicator.
- **PDF layout**: Usar `package:pdf` (não confundir com `printing`). Criar um template reutilizável com header, footer com paginação, e estilos consistentes.
- **Import com validação**: Ao importar CSV/JSON, validar campos obrigatórios, formatos de data e valores numéricos. Mostrar preview antes de confirmar.
- **Backup incremental**: Na v1, fazer backup completo (cópia do arquivo SQLite). Backup incremental pode ser considerado futuramente.
- **Segurança**: Considerar oferecer opção de criptografar o backup com senha do usuário.
- **Tamanho**: Para bancos grandes, o export pode demorar. Sempre mostrar progresso e permitir cancelamento.
