# n8n-mcp — Guia de Uso

MCP server que da acesso direto a nós, templates e workflows do n8n. Configurado em [.mcp.json](../../.mcp.json).

## Setup (ja feito neste repo)

```json
"n8n-mcp": {
  "command": "n8n-mcp",
  "args": [],
  "env": {
    "MCP_MODE": "stdio",
    "N8N_API_URL": "${N8N_API_URL}",
    "N8N_API_KEY": "${N8N_API_KEY}",
    "WEBHOOK_SECURITY_MODE": "moderate"
  }
}
```

- `command: "n8n-mcp"` direto (nao `npx -y`) — evita timeout de download em toda sessao. Instalado global com `npm install -g n8n-mcp`.
- `WEBHOOK_SECURITY_MODE=moderate` — libera checagem de API em `localhost` (proteção SSRF do pacote bloqueia localhost por padrão em modo `strict`).
- `N8N_API_URL` / `N8N_API_KEY` vem do `.env` — sem eles, só ficam disponíveis os tools de discovery/validação (não os de gerenciar workflow).

## Categorias de tools

| Categoria | Tools | Precisa API key? |
|---|---|---|
| Sistema | `tools_documentation`, `n8n_health_check`, `n8n_audit_instance` | health/audit sim |
| Descoberta | `search_nodes`, `get_node` | não |
| Templates | `search_templates`, `get_template` | não |
| Validação | `validate_node`, `validate_workflow` | não |
| Gerenciamento | `n8n_create_workflow`, `n8n_list_workflows`, `n8n_update_partial_workflow`, `n8n_delete_workflow`, etc. | sim |

## Exemplos diretos

### 1. Checar saúde da conexão com n8n

```
n8n_health_check()
```
Confirma se a API está acessível e responde rápido antes de qualquer outra chamada.

```json
{
  "success": true,
  "data": { "status": "ok", "apiUrl": "http://localhost:5678", "performance": { "responseTimeMs": 927 } }
}
```

### 2. Buscar um nó pelo nome

```
search_nodes(query="webhook", limit=3)
```
Retorna os nós que batem com a palavra-chave, ordenados por relevância — usado antes de montar qualquer workflow, pra saber o `nodeType` exato.

```json
{
  "nodeType": "nodes-base.webhook",
  "workflowNodeType": "n8n-nodes-base.webhook",
  "displayName": "Webhook",
  "category": "trigger"
}
```

### 3. Ver detalhes de um nó

```
get_node(nodeType="nodes-base.webhook", detail="minimal")
```
`detail=minimal` traz só o essencial (~200 tokens) — bom pra confirmar tipo/trigger sem gastar contexto com schema completo.

```json
{
  "nodeType": "nodes-base.webhook",
  "isTrigger": true,
  "isWebhook": true
}
```

### 4. Buscar templates prontos

```
search_templates(query="slack notification", limit=2)
```
Procura entre 2700+ templates públicos do n8n.io — útil pra não reinventar workflow comum (ex: alerta de erro, notificação Slack).

```json
{ "total": 644, "items": [{ "id": 5629, "name": "Multi-Channel Workflow Error Alerts..." }] }
```

### 5. Validar um workflow antes de criar/deployar

```
validate_workflow(workflow={
  "nodes": [
    {"name": "Webhook", "type": "n8n-nodes-base.webhook", "typeVersion": 2, "parameters": {"path": "test", "httpMethod": "POST"}},
    {"name": "Respond", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "parameters": {}}
  ],
  "connections": {"Webhook": {"main": [[{"node": "Respond", "type": "main", "index": 0}]]}}
})
```
Passo obrigatório antes de `n8n_create_workflow` — pega erro de conexão, expressão ou tipo de nó errado sem precisar subir no n8n de verdade.

```json
{ "valid": true, "summary": { "totalNodes": 2, "errorCount": 0 }, "suggestions": ["Add error handling..."] }
```

### 6. Criar workflow direto no n8n (precisa API key)

```
n8n_create_workflow(name="Meu Webhook", nodes=[...], connections={...})
```
Cria já no servidor n8n configurado — sai inativo (precisa `activateWorkflow` depois via `n8n_update_partial_workflow`).

### 7. Listar workflows existentes (precisa API key)

```
n8n_list_workflows()
```
Retorna metadata mínima (id, nome, status) — não traz nodes/connections, usado pra achar o ID antes de um `n8n_get_workflow` detalhado.

## Fluxo recomendado pra criar workflow do zero

1. `search_nodes` — achar os nós certos
2. `get_node(detail="standard")` — ver parâmetros de cada um
3. Montar JSON de `nodes` + `connections`
4. `validate_workflow` — validar antes de subir
5. `n8n_create_workflow` — criar (fica inativo)
6. `n8n_update_partial_workflow(operations=[{"type":"activateWorkflow"}])` — ativar
