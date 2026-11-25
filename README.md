# AjudaMais

Sistema de doações: site (HTML/CSS/JS) + API Node.js/Express + banco MySQL/MariaDB real.

O **Express serve o site e a API na mesma origem**, então não é preciso configurar CORS nem
subir dois servidores. Tudo roda com **Node.js 18+**, **MySQL 8** (ou MariaDB 10.x) e um navegador.

---

## 1. O que está no projeto

```
frontend/            site completo (telas, CSS, JS) — é o que o Express publica
backend/             API Express + scripts + testes
  src/               app.js (rotas), server.js (inicia), config, db, auth, rotas
  tests/             integração, fluxo, segurança, UI, persistência, responsividade, visual
database/            schema definitivo (01), migração (02) e fixtures de teste
backups/             dumps SQL do banco (ver seção 6)
api/index.js         entrada da API como função serverless (Vercel)
vercel.json          configuração de publicação
package.json         scripts da raiz (start, dev, testes)
artifacts/           capturas da auditoria visual (13 telas x 4 larguras)
README.md            este arquivo
ENTREGA.md           relatório final de testes e entrega
```

---

## 2. Rodar localmente no Windows 10 (VS Code)

### 2.1 Instalar

| Item | Versão | Link |
| --- | --- | --- |
| Node.js | 18+ (LTS) | https://nodejs.org |
| MySQL | 8.x (ou MariaDB 10.x) | https://dev.mysql.com/downloads/installer/ |
| VS Code | qualquer | https://code.visualstudio.com |

No PowerShell, confirme: `node --version` e `mysql --version`.

### 2.2 Criar o banco

Abra o MySQL Command Line Client (ou o Workbench) e rode **uma vez**:

```sql
SOURCE C:/caminho/do/projeto/database/01-schema.sql;
```

Isso cria o banco `ajudamais`, todas as tabelas, as categorias e os estados.

Se você já tem o banco antigo do grupo, rode em seguida `database/02-migration.sql`
para atualizar a estrutura **sem apagar dados**.

Opcional: para carregar o dump pronto (com as contas de teste usadas nos testes),
use `backups/ajudamais-completo-*.sql` (ver seção 6).

### 2.3 Configurar

Na pasta `backend/`, copie o modelo e edite só a senha:

```powershell
cd backend
copy .env.example .env
```

No `.env`, ajuste:

```
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=sua_senha_do_mysql
DB_NAME=ajudamais
PORT=3000
```

### 2.4 Instalar e iniciar

Na **raiz** do projeto:

```powershell
npm install
npm start
```

O `npm install` instala as dependências da raiz e do backend automaticamente.
Abra **http://localhost:3000**. O site e a API saem do mesmo endereço.

Para parar: `Ctrl + C`.

### 2.5 Testes (opcional)

Com o servidor rodando em outra janela:

```powershell
npm test                 :: integração (usa banco de teste)
npm run test:seguranca
npm run test:ui
```

Os testes de navegador precisam do Chromium do Playwright:

```powershell
npx playwright install chromium
```

---

## 3. Contas de teste

Os testes criam contas com e-mail `persist.*@teste.local` e senha `SenhaForte123`.
Se você restaurou o dump de `backups/`, pode entrar com uma delas para ver dados já
preenchidos. Para começar limpo, use **Criar conta** na tela inicial.

---

## 4. Publicar gratuitamente na Vercel

A Vercel hospeda o **site** e a **API** de graça no plano Hobby. Ela **não oferece
MySQL**, então você precisa de um banco MySQL gratuito externo.

### 4.1 Escolher onde hospedar o MySQL (gratuito)

| Serviço | Plano gratuito | Observação |
| --- | --- | --- |
| **Aiven** | MySQL gerenciado, plano free | Boa opção para projeto de faculdade; exige cartão só para verificação em alguns casos |
| **Railway** | crédito inicial gratuito | Fácil de criar MySQL; o crédito acaba com o tempo |
| **Clever Cloud** | MySQL free tier pequeno | Plano "free" limitado em armazenamento |
| **FreeMySQLHosting / db4free.net** | MySQL comunitário | Sem garantia de disponibilidade; serve para demonstração |

> Escolha um, crie o banco `ajudamais` e importe `database/01-schema.sql`
> (pelo painel do serviço ou com `mysql -h host -u user -p banco < 01-schema.sql`).
> Guarde **host, porta, usuário, senha e nome do banco**.

### 4.2 Configurar as variáveis na Vercel

No painel da Vercel, em **Settings → Environment Variables**, cadastre
(para Production e Preview):

| Nome | Valor |
| --- | --- |
| `DB_HOST` | host do MySQL |
| `DB_PORT` | porta (geralmente `3306`) |
| `DB_USER` | usuário |
| `DB_PASSWORD` | senha |
| `DB_NAME` | `ajudamais` |
| `NODE_ENV` | `production` |

Em muitos serviços gratuitos o MySQL exige **SSL**. Se a conexão falhar, veja a
documentação do provedor: normalmente é preciso adicionar `DB_SSL=true` e o backend
já aceita essa variável.

### 4.3 Publicar

1. Crie a conta em https://vercel.com (plano Hobby, gratuito).
2. Instale a CLI: `npm i -g vercel`.
3. Na raiz do projeto: `vercel` (primeira vez) e depois `vercel --prod`.
4. A Vercel detecta `vercel.json`: publica `frontend/` como estático e a API em
   `api/index.js` (todas as chamadas `/api/*`).
5. Abra a URL gerada (algo como `https://ajudamais.vercel.app`).

O `vercel.json` já define `outputDirectory: frontend`, a função `api/index.js`
e o redirecionamento de `/api/*`.

**Alternativa sem CLI:** suba o projeto para o GitHub e use **Add New → Project**
na Vercel apontando para o repositório. As variáveis da seção 4.2 são as mesmas.

---

## 5. Estrutura da API

| Rota | O que faz |
| --- | --- |
| `POST /api/auth/register` / `login` / `logout` | Cadastro, login (CPF ou e-mail) e saída |
| `POST /api/auth/recover-account` / `redefine-password` | Recuperação com contato mascarado e redefinição |
| `GET/PATCH /api/users/me` | Perfil do usuário logado |
| `GET/POST/DELETE /api/users/me/addresses` | Endereços |
| `GET/POST/PATCH /api/donations` | Doações em dinheiro e de itens |
| `GET/POST /api/requests` | Solicitações de ajuda |
| `GET /api/institutions`, `/api/categories`, `/api/stats` | Dados públicos do site |

Autenticação por token Bearer, guardado no banco **apenas como hash SHA-256**.
Senhas usam bcrypt. Rotas de escrita conferem permissões (dono do recurso ou papel
de administrador/moderador).

---

## 6. Backups do banco (arquivos preservados no projeto)

A pasta `backups/` fica dentro do projeto (portanto fora do banco temporário):

| Arquivo | Conteúdo |
| --- | --- |
| `ajudamais-completo-*.sql` | Dump **completo** do banco principal: estrutura, views, categorias, contas e dados de teste |
| `ajudamais-limpo.sql` | Banco só com a estrutura e dados de configuração (sem contas) |

**Restaurar no Windows:**

```powershell
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS ajudamais CHARACTER SET utf8mb4;"
mysql -u root -p ajudamais < backups/ajudamais-completo-AAAAmmdd-HHMM.sql
```

**Gerar um novo backup:**

```powershell
mysqldump -u root -p --single-transaction --routines --triggers --databases ajudamais > backups/meu-backup.sql
```

Sempre guarde uma cópia dos `.sql` fora do computador (Google Drive, OneDrive ou
repositório privado), porque o banco local pode ser perdido.

---

## 7. Problemas comuns

| Sintoma | Solução |
| --- | --- |
| `Configure um arquivo .env` | Falta `backend/.env`; copie de `backend/.env.example` |
| `ECONNREFUSED` | O MySQL não está rodando ou a porta/host estão errados |
| `Access denied` | `DB_USER`/`DB_PASSWORD` incorretos |
| Tela abre sem dados | Confira se `npm start` está rodando e abra pela porta 3000 |
| API na Vercel com erro 500 | Variáveis de banco ausentes ou MySQL externo exigindo SSL |

---

## 8. Licença e créditos

Projeto acadêmico. Sem fins comerciais.
