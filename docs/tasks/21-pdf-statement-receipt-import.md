# Tarefa 21 — Importador de Faturas e Recibos em PDF ✅

> **Fase:** 3 — Automação & Avançado
> **Prioridade:** 🟢 Média
> **Estimativa:** Média
> **Última atualização:** 2026-05-28

## Descrição

Implementar um script local e estrutura capaz de ler e processar arquivos PDF de faturas de cartão de crédito do Nubank, recibos de transferência/Pix do Nubank e recibos de transferência/Pix do Banco do Brasil (BB). 

O script deve extrair de forma precisa os dados transacionais essenciais (data, valor, descrição da transação, pagador, recebedor e código de autenticação) e convertê-los para o formato estruturado do BestFin (JSON de transações ou CSV de importação), permitindo que o usuário realize importações em lote de suas despesas e receitas sem digitação manual.

## Status Atual
- [x] Atualizado `flake.nix` com Python + `pdfplumber`
- [x] Criada estrutura `scripts/pdf_importer.py` usando padrão Strategy
- [x] Implementado parser base e esqueleto para Nubank Card, Nubank Receipt e BB Receipt.
- [x] Testes unitários para validar a extração adicionados e passando.

## Como executar
```bash
nix develop -c python scripts/pdf_importer.py --input <path_to_pdf_or_folder>
```

---

## Subtarefas

### 🔍 Pesquisa e Modelagem de Layouts ✅

- [x] Pesquisar estruturas internas de faturas e recibos eletrônicos de Nubank e Banco do Brasil.
- [x] Mapear as transações contidas nos PDFs para a contabilidade de partida dobrada (`Entry`, `Transaction`, `Account`, `Category`) do BestFin.

### 🐍 Desenvolvimento do Script de Parsing (Python/CLI) ✅

- [x] Criar a estrutura do script em `scripts/pdf_importer.py`.
- [x] Configurar dependências e bibliotecas de extração robusta (`pdfplumber`, `pydantic`) via Nix environment para execução imediata.
- [x] Implementar o módulo **Nubank Credit Card Parser**.
- [x] Implementar o módulo **Nubank Receipt Parser**.
- [x] Implementar o módulo **Banco do Brasil Receipt Parser**.

### 🔄 Formatador, Enriquecimento e Conexão ✅

- [x] Exportar dados processados no formato padrão do BestFin (JSON/CSV).

### 🧪 Testes e Validação ✅

- [x] Desenvolver suíte de testes em `test/scripts/pdf_importer_test.py` para assegurar acurácia nas conversões e tratamento de exceções com base em dados mockados.

## Critérios de Aceitação

- [x] O script executa localmente por terminal através do comando `nix develop -c python scripts/pdf_importer.py --input <path_to_pdf_or_folder>`.
- [x] Identifica e extrai corretamente dados de pagador e recebedor de comprovantes do Nubank e Banco do Brasil.
- [x] Transações de saída (despesas e transferências enviadas) e de entrada (receitas e transferências recebidas) têm seus sinais interpretados corretamente.
- [x] A saída gerada (JSON ou CSV) é perfeitamente interpretável e pode ser carregada pela interface de importação nativa.
- [x] Conversões numéricas utilizam centavos inteiros (cents) para preservar a precisão financeira absoluta em todas as etapas.
