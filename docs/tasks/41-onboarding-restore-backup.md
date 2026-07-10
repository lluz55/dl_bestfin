# Tarefa 41 — Restaurar Backup no Onboarding

> **Fase:** 3 — Refinamentos
> **Prioridade:** 🟢 Média
> **Estimativa:** Pequena
> **Última atualização:** 2026-07-09

## Descrição

Permitir que o usuário restaure um backup do BestFin (arquivo `.sqlite` ou `.json`) logo no início do onboarding, sem precisar completar o wizard e navegar até Export & Backup.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [14-export](./14-export.md) | Export e Backup (use cases de restore) | ✅ Concluída |
| [33-onboarding-tutorial](./33-onboarding-tutorial.md) | Onboarding wizard | ✅ Concluída |

## Subtarefas

 - [x] Botão "Restaurar de um backup" no `WelcomeStep` (abaixo de "Sincronizar com dispositivo existente")
 - [x] `OnboardingScreen._restoreFromBackup()`: file picker (`.sqlite`/`.json`), dispatch por extensão
   - [x] `.sqlite` → `BackupDatabaseUseCase.restoreBackup` (valida header SQLite)
   - [x] `.json` → `previewJson` (validação de formato) + `restoreJson`
 - [x] Invalidar `databaseProvider` após restore (fechando a conexão antiga no caso JSON)
 - [x] Concluir onboarding via `OnboardingActions.complete(ref)` direto (sem `_finish()` — não cria a conta do rascunho)
 - [x] Tela de progresso "Restaurando seu backup..." durante a operação
 - [x] Erros logados via `debugPrint` + snackbar

## Critérios de Aceitação

 - [x] `flutter analyze` sem novos avisos
 - [x] Testes de `test/features/backup/` e `test/features/security/` passando

## Arquivos Principais

```
lib/features/onboarding/presentation/
├── screens/onboarding_screen.dart   # _restoreFromBackup + tela de progresso
└── widgets/welcome_step.dart        # botão "Restaurar de um backup"
```

## Notas e Considerações

- A restauração no welcome conclui o onboarding imediatamente — o backup já contém contas, categorias e configurações; refazer o wizard sobrescreveria dados restaurados.
- `biometrics_enabled` do backup não é reaplicado ao SharedPreferences local; o usuário reativa a biometria em Configurações (evita travar o usuário atrás de um PIN de outro dispositivo).
- No Linux, o file picker exige `zenity` (já no devShell — ver correções da Tarefa 14).
