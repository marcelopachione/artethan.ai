# artethan.ai — stacks self-hosted (n8n + OpenClaw)

Dois projetos Docker Compose independentes, compartilhando uma rede:

- **[`n8n/`](n8n/README.md)** — automação de workflows (n8n main + worker,
  Postgres, Redis, modo fila).
- **[`openclaw/`](openclaw/README.md)** — gateway de agente de IA
  (OpenRouter como provedor de modelo).

Cada pasta é uma stack própria (`docker-compose.yml`, `.env`, `init.sh`), mas
os containers dos dois projetos se enxergam pelo nome na rede externa
`artethan_net` — detalhes em [`openclaw/README.md`](openclaw/README.md#rede-compartilhada-com-o-n8n).

## Pré-requisitos

- Docker + Docker Compose
- `openssl` (geração de segredos pelos `init.sh`)
- Clonar em filesystem Linux nativo (ext4) — não em pasta de rede/VM
  (`vboxsf`, `/mnt/c` no WSL, NFS/SMB); Postgres/Redis rodam como usuário
  não-root e precisam ser donos reais dos seus dados, o que essas pastas
  compartilhadas não garantem.

## Primeira execução

```bash
cd n8n && ./init.sh && docker compose up -d
cd ../openclaw && ./init.sh && ./onboard.sh
```

Passo a passo completo (variáveis de ambiente, segurança, backup, scaling)
em cada README:

- [n8n/README.md](n8n/README.md)
- [openclaw/README.md](openclaw/README.md)

## Segredos

`.env` de cada stack é gerado pelo próprio `init.sh` e nunca versionado
(`.gitignore` na raiz). A pasta `infos/` (credenciais pessoais soltas) também
é ignorada — nunca commitar nada nela.

## Expor serviço local pra internet (cloudflared)

Automações externas (ex: webhook de API de terceiros) não alcançam
`localhost` — precisa de um túnel público apontando pra porta do container.

Instalar (uma vez, exige `sudo`):

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

Abrir túnel (modo rápido, sem conta Cloudflare):

```bash
cloudflared tunnel --url http://localhost:5678   # ou a porta do serviço (18789 pro openclaw)
```

Gera uma URL tipo `https://palavras-aleatorias.trycloudflare.com`, que
repassa pra `localhost:5678`. Use essa URL + o path do endpoint (ex:
`/webhook/<id>` de um workflow n8n) na configuração da API externa.

Pontos importantes:
- **URL muda a cada reinício** do túnel — sem conta Cloudflare não dá pra
  fixar. Se o processo cair, atualizar a URL na automação externa.
- Roda em primeiro plano — matar o processo derruba o túnel. Pra manter de
  pé em background: `nohup cloudflared tunnel --url http://localhost:5678 &`
  (ou um serviço `systemd`, se for usar em produção de fato).
- Testando webhook do n8n: use `/webhook-test/<id>` (path de teste, ativa só
  enquanto clica "Listen for test event" no editor) antes de trocar pra
  `/webhook/<id>` (produção, workflow com toggle **Active** ligado).
- Pra uso sério/permanente, crie uma tunnel nomeada com conta Cloudflare
  (domínio fixo, sobrevive a reinícios) — ver
  https://developers.cloudflare.com/cloudflare-one/connections/connect-apps.
