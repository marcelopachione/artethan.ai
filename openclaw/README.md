# OpenClaw — gateway de agente de IA (self-hosted)

Stack: **OpenClaw gateway**, na mesma rede Docker do `n8n/` — um único
projeto, uma única rede.

## O que é

OpenClaw é um gateway self-hosted que conecta modelos a ferramentas, sessões
e automações locais. Aqui ele roda como um único container que expõe uma API
em `http://localhost:18789`, usando a **OpenRouter** como provedor de modelo
(uma chave só, roteamento entre vários modelos/fabricantes) em vez de falar
direto com a Anthropic.

> A documentação oficial do projeto está espalhada por vários domínios
> (`docs.openclaw.ai`, `clawdocs.org`, mirrors de terceiros), com informação
> nem sempre consistente entre si — é um ecossistema novo e em movimento
> rápido. Antes do primeiro `docker compose up`, vale conferir a versão mais
> recente da imagem em https://github.com/openclaw/openclaw e fixar uma tag
> específica em `OPENCLAW_IMAGE` (veja `.env.example`) em vez de rastrear
> `:latest` em produção.

## Arquitetura: uma rede para o projeto todo

```
                         artethan_net (externa)
┌───────────────────────────────────────────────────────────────────┐
│   postgres · redis · n8n · n8n-worker · openclaw                    │
└───────────────────────────────────────────────────────────────────┘
      stack n8n/ (docker-compose.yml)   stack openclaw/ (docker-compose.yml)
```

- `artethan_net` é uma rede **externa**, criada uma única vez (por qualquer
  um dos dois `init.sh`) e referenciada como `external: true` nos dois
  `docker-compose.yml`. Nenhuma das stacks é dona dela, então
  `docker compose down` em uma não derruba a rede que a outra depende.
- Todos os serviços dos dois projetos entram nela e se enxergam pelo nome do
  container: `n8n` chama `http://openclaw:18789/...`, o `openclaw` chama
  `http://n8n:5678/webhook/...`. Isso inclui `postgres` e `redis` — eles não
  publicam porta para o host, mas dentro da rede ficam alcançáveis por
  qualquer container do projeto (inclusive o `openclaw`). Se algum dia
  precisar isolar o banco do n8n do OpenClaw, é só voltar a usar redes
  separadas por stack.
- A porta do gateway (`18789`) é publicada em todas as interfaces, igual ao
  n8n (`5678`) — acesso direto do host. Proteção fica por conta do
  `OPENCLAW_GATEWAY_TOKEN` obrigatório.

### Exemplos de uso cruzado

- **n8n → OpenClaw**: um node HTTP Request no n8n chama
  `http://openclaw:18789/...` enviando `Authorization: Bearer
  ${OPENCLAW_GATEWAY_TOKEN}` para disparar um agente.
- **OpenClaw → n8n**: um workflow no n8n com um node *Webhook* trigger recebe
  chamadas do OpenClaw em `http://n8n:5678/webhook/<caminho>`, sem sair da
  rede Docker.

## Estrutura

```
openclaw/
├── docker-compose.yml
├── .env.example
├── init.sh              # cria a rede artethan_net + .env + ajusta permissões
├── onboard.sh            # grava a config (openclaw.json) e define o modelo padrão
├── backups/
│   └── backup.sh
└── data/
    └── openclaw/         # -> /home/node/.openclaw (config, token, sessões, cron, embeddings)
```

## Primeira execução

```bash
cd /home/marcelo/workspace/artethan.ai/openclaw
./init.sh          # cria a rede artethan_net, gera .env, ajusta dono do bind mount
```

Edite `.env` e preencha `OPENROUTER_API_KEY` (crie uma em
https://openrouter.ai/keys) e, se quiser, `OPENCLAW_PRIMARY_MODEL` (padrão
`openrouter/auto`). Depois:

```bash
./onboard.sh
docker compose logs -f openclaw
```

> `docker compose up -d` sozinho **não é suficiente** na primeira vez: o
> gateway recusa subir só com variáveis de ambiente ("Missing config. Run
> `openclaw setup`...") — ele exige um `openclaw.json` gravado. O
> `onboard.sh` roda `openclaw setup` de forma não-interativa (auth via
> OpenRouter, token do gateway lido do `.env` por referência, sem instalar
> daemon/canais/skills extras), define o modelo padrão com `openclaw models
> set` e só então sobe o serviço definitivo.

Acesse `http://localhost:18789`.

Para trocar o modelo depois, sem refazer o setup todo:

```bash
docker compose exec openclaw openclaw models set openrouter/tencent/hy3
docker compose exec openclaw openclaw models status   # confere o que está ativo
```

## Segurança e boas práticas aplicadas

- **Gateway token obrigatório** (`OPENCLAW_GATEWAY_TOKEN`), gerado com
  `openssl rand` — qualquer chamador (incluindo o n8n) precisa apresentá-lo.
- **Porta publicada em todas as interfaces** (`18789`), mesmo padrão do n8n —
  quem barra acesso indevido é o gateway token, não o binding de rede.
- **Bind mount** explícito (não named volume) em `data/openclaw`, dono
  ajustado para uid/gid 1000 (usuário `node` da imagem oficial), mesmo padrão
  do `n8n/`.
- **Healthcheck** em `/healthz` e **limites de recursos** (`cpus`/`memory`)
  para não deixar o container faminto derrubar o host.
- **Log rotation** (`json-file`) igual ao resto do projeto.
- **`.env` fora do controle de versão**, chaves/token nunca hardcoded no
  compose.

## Backup e restore

```bash
./backups/backup.sh    # tar.gz de data/openclaw (config, token, sessões, cron, embeddings)
```

Agende no cron do host, como já é feito para o `n8n/backups/backup.sh`.

## Comandos úteis

```bash
docker compose ps
docker compose logs -f openclaw
docker compose down          # para o container, mantém os dados
docker compose pull && docker compose up -d   # atualizar a imagem
```
