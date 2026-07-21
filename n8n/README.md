# n8n — ambiente de produção (local/VPN, modo fila)

Stack: **n8n (main) + n8n (worker) + Redis + PostgreSQL**, todos com bind mounts,
sem reverse proxy/TLS (acesso via `http://localhost:5678` ou rede VPN).

## Por que os dados NÃO ficam em `/prj/artethan.ai`

`/prj` é uma pasta compartilhada VirtualBox (`vboxsf`). Esse tipo de filesystem
**não implementa `chown`/permissões Unix corretamente** e tem problemas de file
locking — testado neste ambiente: `chown` retorna sucesso mas não altera o
dono real do arquivo. Postgres e Redis rodam como usuários não-root dentro do
container (uid 999) e precisam ser donos dos seus diretórios de dados; em
`vboxsf` isso falha silenciosamente ou quebra o Postgres na inicialização.

Por isso os dados ficam em `/home/marcelo/workspace/artethan.ai/n8n/data`
(filesystem nativo ext4 do host), separado por serviço, para não colidir com
outras stacks que venham a ser criadas dentro de
`/home/marcelo/workspace/artethan.ai/`.

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
cd /home/marcelo/workspace/artethan.ai/n8n
./init.sh          # cria .env com segredos gerados e ajusta dono dos bind mounts (pede sudo)
docker compose up -d
docker compose logs -f n8n
```

Acesse `http://localhost:5678` e crie o usuário owner (setup obrigatório na
primeira execução — substitui o antigo basic auth).

> Se `docker compose` pedir senha mesmo com o usuário já no grupo `docker`,
> a sessão atual não recarregou o grupo — rode `newgrp docker` ou reabra a
> sessão (logout/login).

## Escalando workers

```bash
docker compose up -d --scale n8n-worker=3
```

Cada worker consome jobs da fila Redis. O container `n8n` (main) continua
responsável pela UI, API, gatilhos (triggers) e recebimento de webhooks; os
workers executam os workflows. Isso já cobre a grande maioria dos cenários de
produção. Se o volume de webhooks ficar muito alto, o próximo passo é isolar
um processo dedicado (`n8n webhook`) atrás de um proxy que roteie `/webhook*`
para ele — não incluído aqui por não haver reverse proxy neste deploy.

## Integração com OpenClaw

Todos os serviços desta stack (`postgres`, `redis`, `n8n`, `n8n-worker`)
rodam na rede externa `artethan_net`, compartilhada com a stack
`../openclaw/`. Qualquer container dos dois projetos se enxerga por nome
(`n8n` ↔ `openclaw`). Detalhes e exemplos de uso em
[`../openclaw/README.md`](../openclaw/README.md).

## Segurança e boas práticas aplicadas

- **PostgreSQL** como banco (não SQLite) — suporta concorrência real dos workers.
- **Modo fila (`EXECUTIONS_MODE=queue`)** com Redis protegido por senha (`requirepass`).
- **`N8N_ENCRYPTION_KEY`** fixa e gerada uma única vez — nunca alterá-la depois
  de criar credenciais/workflows, ou elas ficam ilegíveis.
- **Task runners** (`N8N_RUNNERS_ENABLED=true`) — modo de execução de código
  recomendado atualmente pelo n8n, substituindo o runtime legado.
- **Bind mounts** explícitos (não named volumes), como solicitado — dados
  ficam visíveis e gerenciáveis diretamente no filesystem do host.
- **Sem exposição desnecessária**: só a porta do n8n (`5678`) é publicada —
  Postgres e Redis não publicam porta nenhuma para o host, só são
  alcançáveis pela rede Docker (`artethan_net`), que hoje inclui também o
  `openclaw`.
- **Healthchecks** em todos os serviços, com `depends_on: condition:
  service_healthy` — o worker só sobe depois que o `n8n` main já rodou as
  migrations do banco, evitando corrida entre os dois.
- **Limites de recursos** (`cpus`/`memory`) por serviço, para não deixar um
  container faminto derrubar o host.
- **Log rotation** (`json-file`, `max-size`/`max-file`) em todos os serviços,
  para não encher o disco com logs.
- **`.env` fora do controle de versão** (`.gitignore`), segredos gerados com
  `openssl rand`.

## Se decidir expor isso com domínio/TLS no futuro

Adicione um reverse proxy (Caddy é o mais simples: TLS automático via Let's
Encrypt) na frente do container `n8n`, e ajuste:
- `N8N_HOST`, `N8N_PROTOCOL=https`, `WEBHOOK_URL=https://seu-dominio/`
- `N8N_SECURE_COOKIE=true`
- Remova o bind de porta em `127.0.0.1:5678` e deixe o proxy expor 443/80.

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
