# AjudaMais — Relatório final de entrega

Data: 25/11/2026
Status: **concluído** para apresentação.

---

## 1. O que foi entregue

Sistema completo funcionando com dados reais no MySQL:

- **Site** (`frontend/`): 7 telas internas + 6 telas públicas (acesso, login, cadastro,
  recuperação, redefinição, termos), responsivo de 320 px a 1366 px.
- **API** (`backend/src/`): autenticação, perfil, endereços, doações (dinheiro e itens),
  solicitações, instituições, categorias e estatísticas.
- **Banco** (`database/`): schema definitivo, migração e fixtures.
- **Publicação**: `api/index.js` + `vercel.json` + `package.json` na raiz.
- **Backups**: dumps em `backups/` (ver seção 6).
- **Capturas**: 52 imagens da auditoria visual em `artifacts/`.

---

## 2. Resultados dos testes (executados no banco real)

| Suíte | O que verifica | Resultado |
| --- | --- | --- |
| `integration.test.js` | 61 casos de API contra banco dedicado | **61/61** |
| `fluxo-site.test.mjs` | Fluxo completo pela API (cadastro → doação → solicitação) | **44 OK, 0 falhas** |
| `security.test.mjs` | Sessão por hash, bcrypt, permissões, dados pessoais, validação | **48 OK, 0 falhas** |
| `persistencia.test.mjs` | Cria dados, sai, entra de novo e confere no MySQL | **23 OK, 0 falhas** |
| `ui-fluxo.test.mjs` | Navegador: todas as telas e ações principais | **49 OK, 0 falhas** |
| `ui-botoes.test.mjs` | Navegador: todos os botões e console | **34 OK, 0 falhas** |
| `responsividade.test.mjs` | 320/390/760/820/1366 px, menu, toque, rolagem | **187 OK, 0 falhas** |
| `visual.test.mjs` | 13 telas × 4 larguras: contraste, sobreposição, corte, imagens | **0 problemas** |

**Contraste (WCAG AA)** — ajustes feitos sem mudar o design:

| Elemento | Antes | Depois |
| --- | --- | --- |
| Texto secundário cinza | 3,82:1 | 4,97:1 |
| Verde usado como texto/ícone | 3,06:1 | 5,20:1 |
| "Cancelar" / "Remover" (vermelho) | 3,91:1 | 5,29:1 |
| Badge "Pendente" | 3,89:1 | 5,02:1 |
| Badge "Urgente" | 4,48:1 | 5,01:1 |
| "← Voltar" / subtítulo no gradiente | ~4,18:1 | ≥4,80:1 |

**Persistência confirmada:** doações, endereços, solicitações e perfil continuam no MySQL
depois de sair, fechar o navegador e entrar novamente — inclusive no celular.

**Segurança:** senha em bcrypt; token só armazenado como hash SHA-256; logout revoga a
sessão; usuário não acessa nem altera dados de outro; listagens públicas não expõem CPF,
e-mail ou telefone; endpoint de teste desativado fora de `NODE_ENV=test`.

---

## 3. O que **não** foi possível testar

- **Publicação real na Vercel**: não foi feita porque exige uma conta e um banco MySQL
  externo. A configuração foi validada localmente simulando a função serverless —
  respondeu site, CSS, API, categorias e bloqueou o endpoint de teste em produção.
- **Navegadores além do Chromium** (Firefox/Safari): não testados.
- **Leitores de tela**: a auditoria cobre contraste, toque e estrutura, não leitores reais.

---

## 4. Arquivos modificados nesta etapa final

| Arquivo | Mudança |
| --- | --- |
| `frontend/css/base.css` | Tons legíveis: lilás do botão desabilitado e subtítulo do gradiente |
| `frontend/css/auth.css` | Texto secundário e "← Voltar" com contraste adequado |
| `frontend/css/home.css` | Variáveis de cinza/verde e legibilidade no celular (fonte ≥ 11,5 px, toque 44 px) |
| `frontend/js/home.js` | Cores de texto/status e remoção do `opacity` nos cabeçalhos coloridos |
| `backend/src/config.js` | Suporte opcional a TLS (`DB_SSL=true`) para MySQL na nuvem |
| `backend/.env.example` | Documenta `DB_SSL` |
| `backend/tests/chrome.mjs` | **Novo**: encontra o Chromium instalado sem depender da versão |
| `backend/tests/*.mjs` | Usam o localizador de Chromium; auditoria ignora painel fechado |
| `README.md` | Reescrito: execução local, publicação gratuita, backups |
| `ENTREGA.md` | Este relatório |

---

## 5. Executar localmente (Windows 10 + VS Code)

1. Instale **Node.js 18+** e **MySQL 8** (ou MariaDB 10.x).
2. Crie o banco: `mysql -u root -p < database/01-schema.sql`.
   Para carregar o dump pronto: `mysql -u root -p ajudamais < backups/ajudamais-completo-*.sql`.
3. Em `backend/`, copie `.env.example` para `.env` e informe `DB_PASSWORD`.
4. Na raiz do projeto: `npm install` e `npm start`.
5. Abra **http://localhost:3000**.

Detalhes e solução de problemas: `README.md`, seções 2 e 7.

---

## 6. Backups preservados

| Arquivo | Conteúdo |
| --- | --- |
| `backups/ajudamais-completo-20261125-0458.sql` | Dump completo: 44 tabelas/views, 5 usuários, 24 categorias, doações e solicitações de teste |
| `backups/ajudamais-limpo.sql` | Estrutura + dados de configuração, sem contas |

O dump completo foi **restaurado num banco temporário durante a entrega** e voltou com
as 44 tabelas/views e os mesmos registros — ou seja, é um backup válido.

O ZIP inclui esses arquivos. Mantenha uma cópia fora do computador (Drive/OneDrive).

---

## 7. Publicar gratuitamente na Vercel

1. **Banco:** a Vercel não oferece MySQL. Crie um gratuito no **Aiven**, **Railway**,
   **Clever Cloud** ou **db4free.net**, importe `database/01-schema.sql` e guarde
   host, porta, usuário, senha e nome do banco.
2. **Variáveis na Vercel** (Settings → Environment Variables):
   `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `NODE_ENV=production`
   e, se o serviço exigir TLS, `DB_SSL=true`.
3. **Publicar:** instale a CLI (`npm i -g vercel`), rode `vercel` e depois
   `vercel --prod` na raiz do projeto. Alternativa: enviar ao GitHub e usar
   **Add New → Project** na Vercel.
4. Abra a URL gerada (`https://ajudamais-....vercel.app`).

O `vercel.json` publica `frontend/` como site estático e `api/index.js` como a API.

> Se a API publicada retornar erro 500, quase sempre é variável de banco faltando ou
> MySQL externo exigindo SSL (`DB_SSL=true`).

---

## 8. Observações

- O servidor local não é "sempre ligado": se o computador dormir, o site local para.
- As contas `persist.*@teste.local` (senha `SenhaForte123`) existem apenas no dump
  de teste; para uma entrega limpa use `ajudamais-limpo.sql`.
- Nenhum serviço pago foi contratado.
