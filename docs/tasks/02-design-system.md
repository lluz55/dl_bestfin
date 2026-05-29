# Tarefa 02 — Design System M3 Expressive

> [!IMPORTANT]
> O design system é a base visual de todo o app. Todas as features de UI dependem dos tokens, extensions e widgets definidos aqui.

**Fase:** 1 — Fundação
**Prioridade:** 🔴 Crítica
**Pré-requisitos:** [01-project-setup](./01-project-setup.md)

---

## Descrição

Implementar o design system completo seguindo Material Design 3 Expressive: color schemes (light/dark), shapes expressivas com cantos assimétricos, motion system com spring physics, escala tipográfica com Google Fonts e widgets base reutilizáveis.

---

## Subtarefas

### Color Schemes

 - [x] Criar `lib/core/theme/color_schemes.dart`:
  - Light e Dark color schemes via `ColorScheme.fromSeed()`
  - Seed color: Deep Purple (`#6750A4`)
  - Cores funcionais adicionais (via `ThemeExtension`):
    - **Receita:** verde (#4CAF50 / variantes)
    - **Despesa:** coral/vermelho (#FF6B6B / variantes)
    - **Transferência:** azul (#42A5F5 / variantes)
    - **Investimento:** dourado (#FFB300 / variantes)

### Tipografia

 - [x] Criar `lib/core/theme/typography.dart`:
  - Escala tipográfica completa com **Inter** via Google Fonts
  - Variações emphasized (weight, letter-spacing)
  - Fonte **monospace** dedicada para valores monetários (ex: `JetBrains Mono` ou `Fira Code`)
  - Text styles pré-definidos para: títulos, saldos, labels, corpo

### Shapes Expressivas

 - [x] Criar `lib/core/theme/shapes.dart`:
  - `ExpressiveShapes extends ThemeExtension<ExpressiveShapes>`
  - Escala de 10 níveis de arredondamento (none → full)
  - Shapes **assimétricas** para cards (ex: `BorderRadius.only(topLeft: 28, topRight: 8, bottomLeft: 8, bottomRight: 28)`)
  - Shapes por componente: card, button, chip, dialog, bottomSheet

### Motion System

 - [x] Criar `lib/core/theme/motion.dart`:
  - `ExpressiveMotion extends ThemeExtension<ExpressiveMotion>`
  - **Springs espaciais (spatial):** bouncy, para movimentos de elementos (stiffness alta, damping baixo)
  - **Springs de efeito (effects):** smooth, para fades e mudanças de cor (stiffness moderada, damping alto)
  - 3 velocidades para cada: fast, medium, slow
  - Curvas e durações padrão para transições de página

### Tema Integrado

 - [x] Criar `lib/core/theme/app_theme.dart`:
  - `ThemeData` completo para **light** e **dark**
  - Registrar `ExpressiveShapes` e `ExpressiveMotion` como `ThemeExtension`
  - Configurar `useMaterial3: true`
  - Aplicar shapes e cores nos componentes padrão (Card, Button, FAB, Dialog, etc.)

### Widgets Base

 - [x] Criar `lib/core/widgets/animated_card.dart`:
  - Card com spring animation ao aparecer (slide up + fade in)
  - Suporte a shape expressiva (cantos assimétricos)
  - Elevação animada ao pressionar

 - [x] Criar `lib/core/widgets/amount_display.dart`:
  - Exibição de valor monetário formatado em BRL (R$ 1.234,56)
  - Cor dinâmica (positivo → verde, negativo → coral, zero → neutro)
  - Animated counter (transição suave entre valores)
  - Fonte monospace

 - [x] Criar `lib/core/widgets/loading_indicator.dart`:
  - Indicador de loading com animação expressiva
  - Variantes: circular, linear, skeleton

 - [x] Criar `lib/core/widgets/empty_state.dart`:
  - Layout de estado vazio: ilustração Lottie + título + descrição + CTA
  - Animações de entrada

### Extensions

 - [x] Criar `lib/core/extensions/context_extensions.dart`:
  - `context.colorScheme` → `Theme.of(context).colorScheme`
  - `context.textTheme` → `Theme.of(context).textTheme`
  - `context.shapes` → `Theme.of(context).extension<ExpressiveShapes>()`
  - `context.motion` → `Theme.of(context).extension<ExpressiveMotion>()`
  - `context.isDark` → `Theme.of(context).brightness == Brightness.dark`

### Integração e Validação

 - [x] Integrar no `app.dart`: `MaterialApp` com `themeMode`, `theme` e `darkTheme`
 - [x] Criar tela de **showcase/demo** para validar visualmente todos os componentes do design system

---

## Critérios de Aceitação

 - [x] Temas light e dark funcionando com toggle dinâmico
 - [x] Shapes assimétricas visíveis nos cards (cantos diferentes)
 - [x] Spring animations funcionando (bounce perceptível em elementos espaciais)
 - [x] Tipografia com Inter carregada corretamente via Google Fonts
 - [x] Valores monetários renderizados com fonte monospace
 - [x] Cores funcionais (receita/despesa/transferência/investimento) distintas e acessíveis
 - [x] `AnimatedCard` com animação de entrada suave
 - [x] `AmountDisplay` com counter animado
 - [x] `EmptyState` com animação Lottie funcional
 - [x] Extensions de contexto funcionais e tipadas

---

## Arquivos Principais

| Arquivo | Ação |
|---------|------|
| `lib/core/theme/color_schemes.dart` | Criar |
| `lib/core/theme/typography.dart` | Criar |
| `lib/core/theme/shapes.dart` | Criar |
| `lib/core/theme/motion.dart` | Criar |
| `lib/core/theme/app_theme.dart` | Criar |
| `lib/core/widgets/animated_card.dart` | Criar |
| `lib/core/widgets/amount_display.dart` | Criar |
| `lib/core/widgets/loading_indicator.dart` | Criar |
| `lib/core/widgets/empty_state.dart` | Criar |
| `lib/core/extensions/context_extensions.dart` | Criar |

---

## Notas e Considerações

> [!NOTE]
> - As shapes assimétricas são uma característica-chave do M3 Expressive. Usar `BorderRadius.only()` com valores diferentes em cada canto.
> - Spring physics: usar `SpringDescription` do Flutter para definir as animações. Elementos que se movem no espaço usam springs bouncy; efeitos visuais (fade, cor) usam springs smooth.
> - O Google Fonts faz download das fontes na primeira execução. Considerar pré-cache em `main.dart`.

> [!TIP]
> - Criar a tela de showcase como uma rota acessível apenas em debug mode (`kDebugMode`). Isso ajuda a validar e iterar rapidamente sobre o design system.
> - Testar acessibilidade: contraste de cores em ambos os temas, tamanhos de fonte com scale factor > 1.0.

> [!WARNING]
> - `ThemeExtension` requer implementação de `copyWith()` e `lerp()` para transições suaves entre temas. Não pular essa implementação.
