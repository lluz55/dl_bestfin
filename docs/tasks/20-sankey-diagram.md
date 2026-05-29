# Tarefa 20 — Sankey Diagram (Fluxo de Caixa Visual) ✅

**Fase:** 2 — Recursos Financeiros
**Prioridade:** 🟢 Média
**Pré-requisitos:** 13-reports

Descrição: Implementar Sankey diagram customizado para visualizar o fluxo de dinheiro: receitas → categorias → subcategorias/entities.

Subtarefas:
- [x] Pesquisar e definir abordagem de renderização: CustomPainter
- [x] Implementar layout algorithm para Sankey (calcular posições dos nodes e links)
- [x] Implementar renderização:
  - [x] Nodes (barras) representando: fontes de receita, categorias de despesa, entities/merchants
  - [x] Links (curvas) com largura proporcional ao valor
  - [x] Cores por categoria
- [x] Implementar interatividade:
  - [x] Tap em node: highlight dos links conectados
  - [x] Tap em link: mostrar valor e detalhes
  - [x] Zoom/pan para dados grandes (via InteractiveViewer)
- [x] Integrar com filtros de relatório (período, contas)
- [x] Animação de entrada: links preenchendo progressivamente
- [x] Layout responsivo (adaptar para mobile vs desktop)

Aceitação:
- [x] Sankey renderiza corretamente com dados reais
- [x] Fluxo visual: receita → categorias → top merchants
- [x] Interativo (tap, highlight)
- [x] Animação de entrada
- [x] Performance aceitável com 50+ nodes
