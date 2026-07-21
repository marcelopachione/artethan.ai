# n8n — ambiente de produção (local/VPN, modo fila)

Stack: **n8n (main) + n8n (worker) + Redis + PostgreSQL**, bind mounts, sem
reverse proxy/TLS (acesso via `http://localhost:5678` ou rede VPN).

## Onde ficam os dados

`data/` precisa estar em filesystem nativo Linux (ext4), nunca em pasta
compartilhada de rede/VM (`vboxsf`, `drvfs`/`/mnt/c` no WSL, NFS/SMB). Esses
filesystems não implementam `chown` corretamente — Postgres/Redis rodam como
usuário não-root (uid 999) dentro do container e precisam ser donos reais dos
seus diretórios, ou a inicialização quebra silenciosamente.

## Estrutura

```
n8n/
├── docker-compose.yml
├── .env.example
├── init.sh              # setup inicial (gera .env + ajusta permissões)
├── backups/
│   ├── backup.sh
│   └── restore.sh
└── data/                 # bind mounts (não versionar)
    ├── n8n/              # -> /home/node/.n8n (config, credenciais, binário de execuções)
    ├── postgres/         # -> dados do Postgres
    ├── redis/            # -> AOF do Redis (fila de execuções)
    └── files/            # -> /files no container, para workflows que leem/escrevem arquivos locais
```

## Primeira execução

```bash
cd n8n
./init.sh          # cria .env com segredos gerados e ajusta dono dos bind mounts (pede sudo)
docker compose up -d
docker compose logs -f n8n
```

Acesse `http://localhost:5678` e crie o usuário owner (setup obrigatório na
primeira execução).

> Se `docker compose` pedir senha mesmo com o usuário já no grupo `docker`, a
> sessão atual não recarregou o grupo — rode `newgrp docker` ou reabra a sessão.

## Escalando workers

```bash
docker compose up -d --scale n8n-worker=3
```

Workers consomem jobs da fila Redis; o `n8n` (main) fica com UI, API, triggers
e recepção de webhooks. Cobre a maioria dos cenários. Se o volume de webhooks
crescer muito, isole um processo dedicado (`n8n webhook`) atrás de um proxy
que roteie `/webhook*` — não incluído aqui por não haver reverse proxy neste
deploy.

## Integração com OpenClaw

Todos os serviços desta stack rodam na rede externa `artethan_net`,
compartilhada com `../openclaw/` — os containers dos dois projetos se
enxergam por nome (`n8n` ↔ `openclaw`). Detalhes em
[`../openclaw/README.md`](../openclaw/README.md).

## Segurança e boas práticas aplicadas

- **PostgreSQL** (não SQLite) — suporta concorrência real dos workers.
- **Modo fila** (`EXECUTIONS_MODE=queue`) com Redis protegido por senha.
- **`N8N_ENCRYPTION_KEY`** fixa, gerada uma única vez — nunca alterar depois
  de criar credenciais/workflows, ou elas ficam ilegíveis.
- **Task runners** (`N8N_RUNNERS_ENABLED=true`) — modo de execução recomendado
  atualmente pelo n8n.
- **Bind mounts** explícitos — dados visíveis e gerenciáveis no host.
- Só a porta do n8n (`5678`) é publicada — Postgres e Redis só são
  alcançáveis pela rede Docker.
- **Healthchecks** em todos os serviços, com `depends_on: service_healthy` —
  worker só sobe depois das migrations do banco.
- **Limites de recursos** (`cpus`/`memory`) por serviço.
- **Log rotation** (`json-file`, `max-size`/`max-file`).
- **`.env` fora do controle de versão**, segredos gerados com `openssl rand`.

## Expor com domínio/TLS

Adicione um reverse proxy (Caddy: TLS automático via Let's Encrypt) na frente
do container `n8n`, e ajuste:
- `N8N_HOST`, `N8N_PROTOCOL=https`, `WEBHOOK_URL=https://seu-dominio/`
- `N8N_SECURE_COOKIE=true`
- Remova o bind de porta e deixe o proxy expor 443/80.

## Backup e restore

```bash
./backups/backup.sh                       # dump do Postgres + tar da pasta data/n8n
./backups/restore.sh backups/postgres_YYYYMMDD_HHMMSS.sql.gz
```

Agende `backup.sh` num cron do host (exemplo no topo do próprio script).

## Comandos úteis

```bash
docker compose ps
docker compose logs -f n8n n8n-worker
docker compose down          # para os containers, mantém os dados
docker compose pull && docker compose up -d   # atualizar versão do n8n
```
