# Tarefa 19 — Sync Multi-Dispositivo e Colaboração

**Fase:** 4 — AI & Sync
**Prioridade:** 🔵 Futura
**Pré-requisitos:** Todas as tarefas anteriores

Descrição: Implementar sincronização entre dispositivos e funcionalidades de colaboração para casais/famílias.

Subtarefas:
- [ ] **Sync multi-dispositivo:**
  - Escolher backend: Firebase, Supabase, ou self-hosted
  - Implementar autenticação (email/senha, Google, Apple)
  - Implementar sync incremental do Drift database
  - Resolver conflitos (last-write-wins ou merge strategies)
  - Sync de attachments (comprovantes/fotos)
  - Funcionar offline-first com queue de sync
- [ ] **Colaboração:**
  - Contas compartilhadas entre parceiros
  - Permissões: visualizar, editar, admin
  - Notificações: "Parceiro adicionou despesa de R$X"
  - Dashboard consolidado (individual + casal)
  - Objetivos compartilhados

Aceitação:
- Sync funcional entre 2+ dispositivos
- Offline-first com resolução de conflitos
- Colaboração: contas compartilhadas funcionais
- Dados sincronizados em < 5 segundos
