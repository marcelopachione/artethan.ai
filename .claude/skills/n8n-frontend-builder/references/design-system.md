# Design profissional dentro do n8n

O sandbox limita a infraestrutura, não a qualidade visual. Uma página servida pelo n8n pode ser tão profissional quanto qualquer landing page, desde que as decisões de design respeitem as restrições técnicas. Este arquivo cobre como fazer o resultado parecer autoral, não template genérico.

## Princípio central: o constraint vira estilo

Como tudo precisa ser inline e SVG, abrace isso. Páginas pesadas de framework são lentas e frágeis; uma página inline bem feita carrega instantâneo e nunca quebra. Trate a leveza como vantagem, não limitação.

## Ancore o design no assunto real

Antes de escolher cores e fontes, fixe: qual é o negócio, quem é o público, qual a única ação que a página precisa provocar. Uma clínica odontológica, um escritório de advocacia e um agente de IA pedem mundos visuais diferentes. As escolhas distintas vêm do universo do próprio assunto (materiais, vocabulário, símbolos), não de um tema padrão aplicado por cima.

Se houver contexto na memória sobre a marca do usuário (paleta, tipografia, tom), use como base.

## Os três defaults de IA a evitar

Design gerado por IA hoje cai quase sempre em um destes três, e todos passam sensação de genérico:
1. Fundo creme (~#F4F1EA) + serifada de alto contraste + acento terracota.
2. Fundo quase preto + um único acento verde-limão ou vermelho vivo.
3. Layout estilo jornal, fios de 1px, zero border-radius, colunas densas.

São legítimos quando o brief pede, mas são padrão, não escolha. Onde o brief deixa um eixo livre, não gaste essa liberdade num desses. Derive a paleta e a tipografia do assunto específico.

## Tipografia carrega a personalidade

- Pare 2 a 3 papéis: um display com caráter (usado com parcimônia), um corpo legível, e opcionalmente uma face utilitária para legendas/dados.
- Defina uma escala de tipo clara, com pesos e espaçamentos intencionais. O tratamento tipográfico deve ser memorável, não um veículo neutro.
- Google Fonts via `<link>` com preconnect funciona no sandbox (ver `n8n-constraints.md`). Boas combinações fora do óbvio: Fraunces + Inter, Bricolage Grotesque + Newsreader, Space Grotesk + IBM Plex Sans, Instrument Serif + Geist.

## Estrutura é informação

Devices estruturais (numeração 01/02/03, eyebrows, divisores, labels) devem codificar algo verdadeiro do conteúdo, não decorar. Só numere se houver de fato uma sequência. Questione cada device antes de usar.

## Movimento que funciona no sandbox

O sandbox permite `allow-scripts`, então animação CSS e JS rodam. O que funciona bem:
- Transições e keyframes em CSS puro (hover, entrada, gradientes animados).
- Reveal on-scroll com `IntersectionObserver`.
- `requestAnimationFrame` para contadores e efeitos suaves.

Um momento orquestrado (uma sequência de entrada bem pensada) costuma valer mais que muitos efeitos espalhados. Excesso de animação é, ele próprio, sinal de página gerada por IA. Sempre respeite `prefers-reduced-motion`.

## Piso de qualidade (sem anunciar)

Toda entrega precisa atender, no mínimo:
- Responsivo de verdade, mobile-first, testado mentalmente em ~375px.
- Foco de teclado visível em elementos interativos.
- `prefers-reduced-motion` respeitado.
- Contraste de cor adequado (texto legível sobre o fundo).
- Hierarquia clara: o olho sabe para onde ir primeiro.
- Espaçamento consistente (defina uma escala, ex.: 4/8/16/24/48px, e siga).

## Cuidado com especificidade de CSS

Inline e classe-a-classe, é fácil criar seletores que se cancelam (ex.: `.section` e `.cta` brigando por padding). Estruture a especificidade com cuidado, principalmente em margens e paddings entre seções.

## Copy é material de design

O texto existe para a pessoa entender e agir, não para enfeitar. Escreva do lado de quem usa a tela:
- Botões dizem o que acontece: "Agendar avaliação", não "Enviar".
- A ação mantém o mesmo nome no fluxo todo (botão "Agendar" gera confirmação "Agendado").
- Estados de erro e vazio dão direção, não desculpa nem clima. Diga o que houve e como resolver.
- Sentence case, verbos diretos, sem encheção. Tom afinado à marca e ao público.

Se o brief não trouxer copy real, escreva você, mas evite frases genéricas que tornam a página tão template quanto um layout padrão.

## Gaste a ousadia em um lugar só

Escolha um elemento de assinatura, a única coisa pela qual a página será lembrada, e deixe todo o resto quieto e disciplinado. Corte qualquer decoração que não sirva ao brief. Antes de entregar, olhe a página inteira e remova um exagero.
