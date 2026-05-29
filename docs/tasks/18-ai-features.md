# Tarefa 18 — Funcionalidades de AI

**Fase:** 4 — AI & Sync
**Prioridade:** 🔵 Futura
**Pré-requisitos:** 06-transactions, 15-notifications

Descrição: Implementar funcionalidades de inteligência artificial: categorização automática, OCR de comprovantes, cash flow forecasting e detecção de anomalias.

Subtarefas:
- [ ] **Categorização automática:**
  - Treinar modelo baseado no histórico do usuário (entity → categoria)
  - Sugerir categoria ao digitar descrição/entity
  - Learning loop: correções do usuário melhoram o modelo
  - Fallback para regras simples quando modelo não tem confiança suficiente
- [ ] **OCR de comprovantes:**
  - Integrar serviço de OCR (on-device ou API)
  - Extrair: valor, data, estabelecimento, itens
  - Preencher form de transação automaticamente
  - Suportar: fotos de recibos, screenshots de transferências, notas fiscais
- [ ] **Cash flow forecasting:**
  - Prever saldo futuro baseado em: recorrentes, parcelas, padrões históricos
  - Gráfico de projeção (próximos 30/60/90 dias)
  - Alertas: "Saldo ficará negativo em 15 dias se manter o ritmo de gastos"
- [ ] **Detecção de anomalias:**
  - Identificar transações fora do padrão (valor, frequência, categoria)
  - Detectar aumentos em assinaturas/recorrentes
  - Notificar: "Gasto de R$500 em Lazer — 3x acima da sua média"
- [ ] **Análise de sentimento correlacionada:**
  - Correlacionar sentimentos das transações com categorias, dias, horários
  - Insights: "Compras noturnas têm sentimento médio de 😞"

Aceitação:
- Categorização automática com >80% de acurácia após 100 transações
- OCR funcional para recibos brasileiros
- Forecasting com gráfico de projeção
- Anomalias detectadas e notificadas
- Todos os processamentos preferencialmente on-device
