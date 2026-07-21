# OpenClaw — gateway de agente de IA (self-hosted)

Stack: **OpenClaw gateway**, na mesma rede Docker do `n8n/` — um único
projeto, uma única rede.

## O que é

Gateway self-hosted que conecta modelos a ferramentas, sessões e automações
locais. Roda como um único container, expõe API em `http://localhost:18789`,
usando **OpenRouter** como provedor de modelo (uma chave, roteamento entre
vários modelos/fabricantes) em vez de falar direto com a Anthropic.

> Documentação oficial espalhada por vários domínios, nem sempre consistente
> entre si — ecossistema novo, muda rápido. Antes do primeiro
> `docker compose up`, confira a versão mais recente em
> https://github.com/openclaw/openclaw e fixe uma tag específica em
> `OPENCLAW_IMAGE` (`.env.example`) em vez de rastrear `:latest`.

## Rede compartilhada com o n8n

`artethan_net` é externa, criada uma única vez por qualquer um dos dois
`init.sh` e referenciada como `external: true` nos dois `docker-compose.yml`
— nenhuma das stacks é dona dela, `docker compose down` numa não derruba a
rede que a outra usa. Todo serviço dos dois projetos se enxerga pelo nome do
container (`n8n`, `openclaw`, `postgres`, `redis` — os dois últimos sem porta
publicada, só alcançáveis dentro da rede).

A porta do gateway (`18789`) é publicada em todas as interfaces, igual ao n8n
(`5678`) — proteção fica por conta do `OPENCLAW_GATEWAY_TOKEN` obrigatório,
não do binding de rede.

**Uso cruzado:**
- n8n → OpenClaw: node HTTP Request chama `http://openclaw:18789/...` com
  `Authorization: Bearer ${OPENCLAW_GATEWAY_TOKEN}`.
- OpenClaw → n8n: node *Webhook* trigger recebe em
  `http://n8n:5678/webhook/<caminho>`, sem sair da rede Docker.

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
cd openclaw
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
> `openclaw setup`...") — exige um `openclaw.json` gravado. O `onboard.sh`
> roda `openclaw setup` não-interativo (auth via OpenRouter, token do gateway
> lido do `.env`, sem daemon/canais/skills extras), define o modelo padrão e
> só então sobe o serviço definitivo.

Acesse `http://localhost:18789`.

Trocar o modelo depois, sem refazer o setup:

```bash
docker compose exec openclaw openclaw models set openrouter/tencent/hy3
docker compose exec openclaw openclaw models status   # confere o que está ativo
```

## Segurança e boas práticas aplicadas

- **Gateway token obrigatório** (`OPENCLAW_GATEWAY_TOKEN`), gerado com
  `openssl rand` — todo chamador (incluindo n8n) precisa apresentá-lo.
- **Bind mount** explícito em `data/openclaw`, dono ajustado para uid/gid 1000
  (usuário `node` da imagem oficial), mesmo padrão do `n8n/`.
- **Healthcheck** em `/healthz` e **limites de recursos** (`cpus`/`memory`).
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
