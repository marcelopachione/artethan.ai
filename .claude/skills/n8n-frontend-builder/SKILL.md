---
name: n8n-frontend-builder
description: Constrói páginas web profissionais (landing pages, formulários, dashboards, páginas de confirmação, páginas de obrigado) servidas diretamente pelo n8n usando a infra de três nós Webhook, HTML (operação generateHtmlTemplate) e Respond to Webhook. Use esta skill SEMPRE que o usuário pedir para criar uma página web, landing page, site, formulário, tela de confirmação, página de agendamento, ou qualquer frontend que vá rodar dentro do n8n, mesmo que diga só "monta uma página no n8n", "faz um HTML pro meu webhook", "preciso servir uma página", "cria um frontend no n8n", "página de obrigado pro meu workflow" ou variações. Também acionar quando o usuário enviar um print do nó HTML do n8n com problema de renderização (ícone que não carregou, fonte quebrada, layout errado, página dentro de iframe), porque a skill conhece todas as limitações do sandbox do n8n e produz HTML à prova dessas restrições. NÃO usar para sites hospedados fora do n8n (Vercel, Netlify, hospedagem própria), onde não há as limitações do sandbox.
---

# n8n Frontend Builder

Esta skill cria frontends profissionais que rodam **dentro** do n8n, servidos por uma página web a partir de um webhook. O diferencial dela não é gerar HTML bonito (isso qualquer um faz), e sim gerar HTML que **sobrevive às limitações reais do n8n**. A maioria dos frontends quebra no n8n por motivos invisíveis no editor: o ícone não aparece, a fonte some, o link não abre, o `localStorage` dá erro. Esta skill conhece cada uma dessas armadilhas e já entrega o código contornando todas.

## Quando esta skill é a escolha certa

Use quando a página vai ser servida pela infra de três nós do n8n:

```
Webhook (GET)  ->  HTML (Generate HTML Template)  ->  Respond to Webhook
```

Se a página vai para Vercel, Netlify, S3 ou qualquer host normal, **não use esta skill**, porque ela aplica restrições que só existem no sandbox do n8n e que limitariam o resultado sem necessidade.

## A regra de ouro que você nunca pode esquecer

Desde a versão **1.103.0**, o n8n embrulha todo HTML servido pelo Respond to Webhook em um **iframe com sandbox via `srcdoc`, e SEM `allow-same-origin`**. Isso significa que a página roda numa **origin opaca (null origin)**. Quase todo problema que o usuário enfrenta vem daqui. Internalize as consequências:

1. **Sem `localStorage`, `sessionStorage` ou cookies.** Qualquer acesso lança `SecurityError` e trava o script inteiro. Use só estado em memória (variáveis JS).
2. **Sem `window.parent` / `window.top`.** Scripts que tentam falar com a janela pai falham.
3. **`target="_blank"` e `window.open()` são bloqueados** (principalmente no n8n Cloud, por causa do COOP). Links têm que ser same-tab (âncora simples com `href`, sem `target`). O sandbox tem `allow-top-navigation-by-user-activation`, então um clique direto do usuário navega a aba normalmente.
4. **`srcdoc` não tem base URL.** Todo caminho relativo quebra. **Todo** asset externo (imagem, fonte, script) precisa de URL absoluta começando em `https://`.
5. **Icon fonts via CDN são frágeis e costumam falhar** (foi exatamente isso que aconteceu com o phosphor-icons no print clássico). A origin opaca + `@font-face` cross-origin = ícone fantasma. **Nunca use icon fonts. Use SVG inline.**
6. **`<title>` e `<link rel="icon">` são ignorados pela aba do navegador.** A aba mostra o título/favicon do n8n, não os da sua página. Não há contorno limpo no n8n Cloud. Não prometa favicon nem título de aba ao usuário.

Detalhamento completo, com cada workaround, está em `references/n8n-constraints.md`. **Leia esse arquivo antes de escrever qualquer linha de HTML.**

## Limitações do nó HTML (além do sandbox)

- A operação **Generate HTML Template NÃO suporta Handlebars.** Só expressões nativas do n8n com `{{ }}`. Para loops e dados dinâmicos, use expressões JS dentro das chaves (ex.: `{{ $json.itens.map(i => '<li>' + i.nome + '</li>').join('') }}`).
- O n8n **não executa o `<script>` na hora de gerar o template** (no editor). O JS só roda no navegador do visitante, depois de servido, e sempre dentro das restrições do sandbox acima.
- O atributo `id` montado via expressão já teve bug de sanitização. Se precisar de `id` dinâmico, prefira `class` ou gere o `id` com cuidado e teste.

## Processo de trabalho

Siga nesta ordem. Não pule a leitura das referências.

### 1. Entenda o objetivo da página
Antes de codar, saiba: que tipo de página é (landing, formulário, confirmação, dashboard), se é estática ou recebe dados dinâmicos do workflow, e qual a ação principal (CTA para WhatsApp, submit de formulário, etc.). Se o usuário já deu contexto suficiente, siga direto. Se faltar algo essencial, pergunte de forma objetiva.

### 2. Leia as referências
- `references/n8n-constraints.md` — a lista completa de limitações e o que usar no lugar de cada coisa proibida.
- `references/design-system.md` — princípios para o resultado parecer profissional e não template genérico (tipografia, espaçamento, hierarquia, paleta, microinterações que funcionam no sandbox).

### 3. Escreva o HTML a partir do boilerplate
Use `assets/boilerplate.html` como ponto de partida. Ele já vem com a estrutura segura: reset, CSS inline, fontes via Google Fonts com preconnect, padrão de SVG inline para ícones e nenhuma dependência proibida. Tudo num único arquivo, porque o n8n não serve assets próprios.

### 4. Valide contra o checklist
Antes de entregar, rode mentalmente o **Checklist de saída** abaixo. Cada item reprovado é uma quebra garantida em produção.

### 5. Entregue o HTML + a configuração dos três nós
Não entregue só o HTML solto. Entregue também:
- Como colar o HTML no nó **HTML (Generate HTML Template)**.
- A config exata do **Respond to Webhook**: `Respond With: Text`, `Response Body: {{ $json.html }}`, e o header `Content-Type: text/html; charset=UTF-8`.
- O lembrete de que o nó **Webhook** precisa estar com `Respond: Using 'Respond to Webhook' Node` e método `GET`.

A seção "Montagem dos três nós" em `references/n8n-constraints.md` tem os valores prontos para copiar.

## Decisão: CSS inline próprio vs Tailwind CDN

Ambos funcionam no sandbox (`allow-scripts` permite o script do Tailwind Play CDN, que injeta estilos inline). A escolha:

- **CSS inline próprio (padrão recomendado):** controle total, visual autoral, zero dependência de rede, carregamento instantâneo, nenhum risco de o CDN cair. É o caminho profissional e o que o boilerplate usa.
- **Tailwind Play CDN:** só quando o usuário pedir explicitamente ou quando for um protótipo rápido e descartável. Avise que é para prototipagem, não produção (o próprio Tailwind recomenda não usar o Play CDN em produção).

Nunca use frameworks que dependam de build (React, Vue compilados, Next) nem CSS hospedado em arquivo próprio: não há onde hospedar dentro do n8n.

## Checklist de saída

Antes de entregar, confirme TODOS:

- [ ] Documento HTML completo e único (`<!DOCTYPE html>` até `</html>`), tudo inline.
- [ ] **Zero icon fonts.** Todos os ícones são SVG inline.
- [ ] **Zero `localStorage`, `sessionStorage`, `document.cookie`.** Estado só em memória.
- [ ] **Zero `target="_blank"` e `window.open()`.** Links são same-tab, ou usa-se um aviso claro se precisar abrir externo.
- [ ] **Zero caminho relativo.** Toda URL externa é absoluta `https://`.
- [ ] Imagens em CDN/host absoluto (imgbb, cloudinary, etc.) ou data URI pequeno.
- [ ] CSS dentro de `<style>` no `<head>`; nenhuma folha de estilo em arquivo próprio.
- [ ] Fontes via Google Fonts com `preconnect`, ou font stack do sistema. Sem `@font-face` apontando para caminho relativo.
- [ ] Responsivo de verdade (mobile-first, testado mentalmente em ~375px).
- [ ] Nenhuma promessa de favicon ou título de aba customizados.
- [ ] Se houver dados dinâmicos, eles entram via expressão `{{ }}` do n8n, não Handlebars.
- [ ] A config dos três nós acompanha a entrega.

## Observações de comunicação

O público desta skill é técnico (devs e automatizadores), mas o objetivo final costuma ser um cliente leigo. Explique os contornos de forma direta, sem encher de jargão. Quando o usuário tiver enfrentado um bug (ícone sumido, etc.), diga a causa real em uma frase e já entregue a solução, sem rodeios.
