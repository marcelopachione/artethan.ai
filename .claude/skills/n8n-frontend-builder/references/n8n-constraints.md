# Limitações do n8n e contornos (referência completa)

Este arquivo é a fonte de verdade sobre o que quebra no n8n e o que usar no lugar. Leia inteiro antes de escrever HTML.

## Índice
1. O sandbox iframe (a causa raiz)
2. Tabela: proibido -> use no lugar
3. Ícones: por que icon fonts falham e como fazer SVG inline
4. Fontes e tipografia no sandbox
5. Imagens e mídia
6. JavaScript permitido e proibido
7. Links e navegação
8. Title e favicon
9. Dados dinâmicos com expressões do n8n (não Handlebars)
10. Montagem dos três nós (valores prontos)
11. Como testar e diagnosticar

---

## 1. O sandbox iframe (a causa raiz)

Desde o n8n **1.103.0**, toda resposta HTML do Respond to Webhook é injetada num iframe assim (simplificado):

```html
<iframe srcdoc="...seu HTML..."
  sandbox="allow-scripts allow-forms allow-popups allow-modals
           allow-orientation-lock allow-pointer-lock allow-presentation
           allow-popups-to-escape-sandbox allow-top-navigation-by-user-activation"
  style="position:fixed; top:0; left:0; width:100vw; height:100vh; border:none;">
</iframe>
```

O ponto decisivo: **não existe `allow-same-origin`**. Sem isso, o navegador trata a página como **origin opaca (null)**. Tudo que depende de identidade de origem deixa de funcionar.

No n8n Cloud some-se a isso uma política **Cross-Origin-Opener-Policy: same-origin** no proxy, que reforça o bloqueio de abrir novas janelas.

Em self-hosted existe a env var `N8N_INSECURE_DISABLE_WEBHOOK_IFRAME_SANDBOX=true` que desliga o sandbox, mas **não conte com ela**: é insegura, exige acesso à infra, e no Cloud não dá para setar. Sempre escreva HTML que funcione COM o sandbox ligado. Tratar o sandbox como permanente é o que torna a página confiável em qualquer ambiente.

---

## 2. Tabela: proibido -> use no lugar

| Proibido (quebra no sandbox) | Use no lugar |
| --- | --- |
| `localStorage` / `sessionStorage` | Variável JS em memória (estado vive só durante a sessão da página) |
| `document.cookie` | Não persista no cliente; mande dados de volta via fetch para outro webhook |
| Icon fonts (Phosphor, Font Awesome, Material Icons via CDN) | SVG inline |
| `<link rel="stylesheet" href="arquivo-proprio.css">` | `<style>` inline no `<head>` |
| Caminho relativo (`./img/logo.png`, `/assets/...`) | URL absoluta `https://...` |
| `target="_blank"` / `window.open()` | Âncora same-tab (sem `target`) |
| `window.parent` / `window.top` | Não acesse a janela pai |
| Handlebars (`{{#each}}`, `{{#if}}`) no nó HTML | Expressão JS do n8n dentro de `{{ }}` |
| Frameworks com build (React/Vue/Next) | HTML + CSS + JS vanilla, tudo inline |
| `<title>` e favicon customizados (esperando que apareçam na aba) | Aceite que a aba mostra o branding do n8n |

---

## 3. Ícones: por que icon fonts falham e como fazer SVG inline

**Por que o phosphor (e similares) não carregou:** icon fonts funcionam carregando um `.woff2` via `@font-face`. Numa origin opaca, o request da fonte sai com `Origin: null` e o resultado fica inconsistente entre navegadores e CDNs; além disso, qualquer URL relativa interna do pacote não resolve (sem base URL no `srcdoc`). O resultado é o "quadradinho" ou o espaço vazio que aparece no lugar do ícone.

**A solução definitiva é SVG inline.** SVG inline é HTML puro, não faz request de rede, não depende de origem, não depende de fonte, não depende de base URL. É imune a todas as restrições do sandbox.

Padrão recomendado: defina os ícones uma vez num `<svg>` oculto com `<symbol>` e reutilize com `<use>`:

```html
<!-- Sprite de ícones: coloque logo após <body> -->
<svg width="0" height="0" style="position:absolute" aria-hidden="true">
  <symbol id="i-whatsapp" viewBox="0 0 24 24">
    <path fill="currentColor" d="M12 2a10 10 0 0 0-8.6 15l-1.4 5 5.1-1.3A10 10 0 1 0 12 2Z"/>
  </symbol>
  <symbol id="i-arrow" viewBox="0 0 24 24">
    <path fill="none" stroke="currentColor" stroke-width="2" d="M5 12h14M13 6l6 6-6 6"/>
  </symbol>
</svg>

<!-- Uso, com cor herdada do texto: -->
<a class="btn">
  Fale conosco
  <svg class="icon"><use href="#i-whatsapp"/></svg>
</a>
```

```css
.icon { width: 1.25em; height: 1.25em; fill: currentColor; }
```

Para ícones únicos, basta colar o `<svg>` diretamente no lugar. Bons acervos de SVG para copiar o `path`: Lucide, Heroicons, Feather, Tabler, Phosphor (pegue o SVG, não a font). Sempre use `fill="currentColor"` ou `stroke="currentColor"` para o ícone herdar a cor do contexto.

---

## 4. Fontes e tipografia no sandbox

**Google Fonts via `<link>` funciona** e é a forma recomendada de ter tipografia autoral. Sempre com preconnect, no `<head>`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Fraunces:opsz,wght@9..144,400;9..144,600&display=swap" rel="stylesheet">
```

Alternativa zero-dependência: **font stack do sistema** (carrega instantâneo, nunca falha):

```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
```

**Nunca** use `@font-face` apontando para arquivo de fonte relativo ou hospedado no próprio n8n: não há onde hospedar e o caminho relativo quebra.

---

## 5. Imagens e mídia

- Use `<img src="https://...">` com **URL absoluta**. Hosts que funcionam bem: imgbb (`i.ibb.co`), Cloudinary, ImageKit, ou qualquer CDN público com CORS aberto.
- Para imagens pequenas e críticas (logo, ícone de marca), **data URI base64** embute a imagem no próprio HTML e elimina o request: `<img src="data:image/svg+xml;base64,...">`. Use só para arquivos pequenos (até ~10KB), senão o HTML incha.
- Evite vídeo pesado embutido; prefira embed de YouTube/Vimeo via `<iframe src="https://...">` com URL absoluta (iframe aninhado funciona).
- Sempre defina `width`/`height` ou `aspect-ratio` no CSS para evitar layout shift.

---

## 6. JavaScript permitido e proibido

**Funciona** (o sandbox tem `allow-scripts`):
- Manipulação de DOM, `addEventListener`, `querySelector`.
- `fetch()` para APIs externas e para outros webhooks do n8n (ótimo para formulários: o submit faz POST para um segundo webhook).
- `IntersectionObserver` (animações on-scroll), `requestAnimationFrame`.
- Estado em memória, validação de formulário, máscaras de input.

**Não funciona / evite:**
- `localStorage`, `sessionStorage`, `document.cookie` -> `SecurityError`, trava o script.
- `window.parent`, `window.top`, `window.opener`.
- `window.open()` e navegação para nova aba.
- Service Workers, Notification API, Clipboard API (parcial/instável).

Padrão de formulário seguro (submit via fetch para um segundo webhook):

```html
<script>
  document.querySelector('#form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const dados = Object.fromEntries(new FormData(e.target));
    try {
      await fetch('https://SEU-N8N/webhook/recebe-form', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(dados),
      });
      // troca a UI em memória, sem recarregar
      document.querySelector('#form').hidden = true;
      document.querySelector('#sucesso').hidden = false;
    } catch (err) {
      document.querySelector('#erro').hidden = false;
    }
  });
</script>
```

---

## 7. Links e navegação

- **Same-tab funciona:** `<a href="https://...">texto</a>` sem `target`. O clique do usuário navega a aba (o sandbox tem `allow-top-navigation-by-user-activation`).
- **`target="_blank"` é bloqueado**, principalmente no Cloud. Se o usuário insistir em abrir externo, explique o tradeoff e use same-tab.
- **Links de WhatsApp, tel, mailto funcionam** same-tab: `https://wa.me/55519...`, `tel:+55...`, `mailto:...`.
- Âncoras internas (`href="#secao"`) funcionam normalmente para scroll na própria página.

---

## 8. Title e favicon

Como o conteúdo vive dentro de um iframe `srcdoc`, **a aba do navegador não reflete o `<title>` nem o `<link rel="icon">` da sua página**. A aba mostra o título/favicon do n8n. Isso é comportamento conhecido (issue #21229) e não tem contorno limpo no Cloud.

O que fazer: ainda inclua `<title>` no HTML (boa prática, acessibilidade, e aparece se a página for aberta direto algum dia), mas **não prometa ao cliente** que o título ou o ícone da aba serão personalizados. Se isso for requisito do cliente, a página precisa sair do n8n para um host próprio.

---

## 9. Dados dinâmicos com expressões do n8n (não Handlebars)

O nó Generate HTML Template avalia `{{ }}` como expressão **JavaScript do n8n**, com acesso a `$json`, `$node`, etc. Não é Handlebars.

Valor simples:
```html
<h1>Olá, {{ $json.nome }}</h1>
```

Lista dinâmica (gera o loop com `.map().join('')`):
```html
<ul>
  {{ $json.servicos.map(s => `<li>${s.titulo} - R$ ${s.preco}</li>`).join('') }}
</ul>
```

Condicional (ternário):
```html
{{ $json.logado ? '<a href="/painel">Painel</a>' : '<a href="/login">Entrar</a>' }}
```

Cuidados:
- Escape aspas e crases com atenção dentro das chaves.
- `id` dinâmico via expressão já teve bug de sanitização; prefira `class`.
- Para HTML grande e majoritariamente estático, mantenha o template fixo e injete só os pedaços dinâmicos com `{{ }}` pontuais. Fica mais legível e menos sujeito a erro.

---

## 10. Montagem dos três nós (valores prontos)

### Nó 1 — Webhook
- **HTTP Method:** `GET`
- **Path:** o caminho da sua página (ex.: `clinica`)
- **Respond:** `Using 'Respond to Webhook' Node`

### Nó 2 — HTML
- **Operation:** `Generate HTML Template`
- **HTML Template:** cole o documento HTML completo aqui (do `<!DOCTYPE html>` ao `</html>`).
- A saída renderizada fica no campo `html` do item.

### Nó 3 — Respond to Webhook
- **Respond With:** `Text`
- **Response Body:** `{{ $json.html }}`
- **Options -> Response Headers -> Add Header:**
  - Name: `Content-Type`
  - Value: `text/html; charset=UTF-8`

Notas:
- Ao usar expressão no Respond to Webhook, ele responde apenas com o **primeiro item** da entrada. Para servir uma página, isso é o esperado (um item só).
- Sem o header `Content-Type: text/html`, o navegador pode tratar a resposta como texto puro. Com ele, renderiza como página (dentro do sandbox).
- Depois de ativar o workflow, teste pela **Production URL** do Webhook, não pela Test URL.

---

## 11. Como testar e diagnosticar

- **No editor do n8n** o preview do nó HTML mostra a renderização, mas NÃO reflete o sandbox. Coisas que aparecem ali (como icon font) podem sumir em produção. Sempre confie no teste pela Production URL no navegador, não no preview.
- **Ícone sumiu em produção mas aparece no preview:** é icon font + origin opaca. Troque por SVG inline.
- **Script não roda / página "morta":** procure acesso a `localStorage`/`cookie`/`window.parent` no JS; um único acesso lança erro e mata o resto do script. Abra o console do navegador para confirmar o `SecurityError`.
- **Link não abre:** provavelmente tem `target="_blank"`. Remova.
- **Imagem quebrada:** caminho relativo ou host sem CORS. Troque por URL absoluta de um CDN aberto.
- **Aba com título/favicon do n8n:** esperado, sem contorno no Cloud.
