---
type: Task
id: "39"
title: "Perfil do Usuário (Nome e Foto)"
status: done
timestamp: 2026-07-09T00:00:00Z
---

# Perfil do Usuário (Nome e Foto)

Permite ao usuário definir opcionalmente um nome e uma foto de perfil,
exibidos no header do Dashboard (saudação "Bom dia, Nome" + avatar) e
editáveis nas Configurações. Também disponível como step opcional no
onboarding, logo após o Welcome. A foto é copiada para o diretório de
documentos do app; nome e caminho persistem em SharedPreferences com seed
síncrono antes do `runApp()`.

## Subtarefas

- [x] Criar `userProfileProvider` (`lib/core/providers/user_profile_provider.dart`)
- [x] Seed síncrono em `main.dart` (`initialUserName`/`initialUserPhotoPath`)
- [x] Widget `ProfileAvatar` (foto → iniciais → ícone genérico)
- [x] Widget `ProfileEditor` (image_picker + campo de nome, aplica direto no provider)
- [x] Step opcional `ProfileStep` no onboarding (índice 1, wizard passa a 6 steps)
- [x] Header do Dashboard: saudação com primeiro nome + avatar no lugar do ícone do app
- [x] Seção "Perfil" nas Configurações (sheet em compacto, painel de detalhe em telas largas)
- [x] "Limpar todos os dados" reseta perfil e apaga o arquivo da foto
- [x] Testes unitários (`test/core/user_profile_test.dart`)
- [x] Atualizar docs OKF (`docs/okf/features/onboarding.md`, `docs/okf/features/dashboard.md`)
