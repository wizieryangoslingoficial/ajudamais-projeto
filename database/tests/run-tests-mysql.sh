#!/usr/bin/env bash
# Teste de compatibilidade com MySQL 8 (motor usado no Windows).
# Mais enxuto que run-tests.sh (a suíte completa roda no MariaDB), mas cobre
# o que difere entre os motores: DDL, CHECK, triggers, views, migration e
# os três cenários de base legada.
#
# Uso: ENGINE=mysql MYSQL_HOME=/tmp/mysql8 bash database/tests/run-tests-mysql.sh
set -u
export DEBIAN_FRONTEND=noninteractive
cd "$(dirname "$0")/.." || exit 1

: "${MYSQL_HOME:?defina MYSQL_HOME com o diretório do MySQL extraído}"

# Alguns pacotes binários do MySQL são compilados contra a ABI do ncurses 5.
# Se ela não existir no sistema, aponta para a versão 6 (compatível na prática
# para o cliente de linha de comando) sem exigir instalação extra.
if ! ldconfig -p 2>/dev/null | grep -q "libncurses.so.5"; then
  mkdir -p /tmp/mysqllib
  ln -sf /lib/x86_64-linux-gnu/libncurses.so.6 /tmp/mysqllib/libncurses.so.5 2>/dev/null
  ln -sf /lib/x86_64-linux-gnu/libtinfo.so.6   /tmp/mysqllib/libtinfo.so.5   2>/dev/null
  export LD_LIBRARY_PATH="/tmp/mysqllib:${LD_LIBRARY_PATH:-}"
fi

DATADIR=/tmp/myd; SOCK=/tmp/myrun/my.sock
rm -rf "$DATADIR" && mkdir -p "$DATADIR" /tmp/myrun
"$MYSQL_HOME/bin/mysqld" --initialize-insecure --user=ubuntu --datadir="$DATADIR" >/tmp/init.log 2>&1 \
  || { echo "FALHA init-db"; tail -5 /tmp/init.log; exit 1; }
"$MYSQL_HOME/bin/mysqld" --user=ubuntu --datadir="$DATADIR" --socket="$SOCK" \
  --pid-file=/tmp/myrun/my.pid --skip-networking --mysqlx=OFF >/tmp/srv.log 2>&1 &
CLI="$MYSQL_HOME/bin/mysql --socket=$SOCK -u root"
for _ in $(seq 1 60); do $CLI -e "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
$CLI -e "SELECT 1" >/dev/null 2>&1 || { echo "FALHA start"; tail -15 /tmp/srv.log; exit 1; }

M="$CLI --batch --skip-column-names"
fail=0
check() {
  if [ "$2" = "$3" ]; then printf '  OK    %s = %s\n' "$1" "$3"
  else printf '  FALHA %s — esperado [%s], obtido [%s]\n' "$1" "$2" "$3"; fail=1; fi
}
q() { $M -e "$1" 2>/dev/null; }
echo "Motor: MySQL $("$MYSQL_HOME/bin/mysqld" --version | sed 's/.*Ver //;s/ for.*//')"

echo; echo "=== Schema: importação e reimportação ==="
$CLI < 01-schema.sql 2>/tmp/e1.txt; check "importa" "0" "$?"
[ -s /tmp/e1.txt ] && { head -10 /tmp/e1.txt; fail=1; }
$CLI < 01-schema.sql 2>/tmp/e2.txt; check "reimporta" "0" "$?"
[ -s /tmp/e2.txt ] && { head -10 /tmp/e2.txt; fail=1; }

echo; echo "=== Objetos ==="
check "tabelas" "39" "$(q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='ajudamais' AND table_type='BASE TABLE';")"
check "views" "5" "$(q "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='ajudamais';")"
check "triggers" "1" "$(q "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='ajudamais';")"
check "FKs" "76" "$(q "SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='ajudamais';")"
check "FK sem índice (0)" "0" "$(q "SELECT COUNT(*) FROM information_schema.key_column_usage k WHERE k.table_schema='ajudamais' AND k.referenced_table_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM information_schema.statistics s WHERE s.table_schema=k.table_schema AND s.table_name=k.table_name AND s.column_name=k.column_name AND s.seq_in_index=1);")"
check "seeds de categorias" "24" "$(q "SELECT COUNT(*) FROM ajudamais.item_categories;")"
check "seeds de estados" "27" "$(q "SELECT COUNT(*) FROM ajudamais.states;")"

echo; echo "=== Regras e relacionamentos ==="
$CLI ajudamais <<'SQL' 2>/tmp/seed.txt
INSERT INTO users (full_name,email,cpf,password_hash) VALUES ('A','a@a.com','11144477735','h');
INSERT INTO institutions (legal_name,cnpj,email) VALUES ('ONG','11222333000181','o@o.com');
INSERT INTO assistance_requests (institution_id,title) VALUES (1,'R1');
INSERT INTO request_items (request_id,description,quantity_requested) VALUES (1,'Cobertor',10);
INSERT INTO donations (code,donor_user_id,is_anonymous,donation_type,status,institution_id,request_id)
  VALUES ('A1',1,0,'itens','confirmada',1,1);
INSERT INTO donation_items (donation_id,request_item_id,description,quantity) VALUES (1,1,'Cobertor',4);
SQL
check "seed do fluxo" "0" "$?"
[ -s /tmp/seed.txt ] && { head -10 /tmp/seed.txt; fail=1; }
check "view de progresso" "40.0" "$(q "SELECT percent_complete FROM ajudamais.v_request_progress WHERE id=1;")"
check "impacto sem duplicar" "4.00" "$(q "SELECT items_total FROM ajudamais.v_institution_impact WHERE institution_id=1;")"

$CLI ajudamais -e "INSERT INTO donations (code,is_anonymous,donor_user_id,donation_type) VALUES ('B',1,1,'itens');" >/dev/null 2>&1
check "CHECK rejeita anônima com doador" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='B';")"
$CLI ajudamais -e "INSERT INTO users (full_name,email,cpf,password_hash) VALUES ('X','x@x.com','123','h');" >/dev/null 2>&1
check "CHECK de CPF" "0" "$(q "SELECT COUNT(*) FROM ajudamais.users WHERE email='x@x.com';")"
$CLI ajudamais -e "INSERT INTO donations (code,donor_user_id,is_anonymous,donation_type) VALUES ('C',NULL,0,'itens');" >/dev/null 2>&1
check "CHECK de identificação" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='C';")"
$CLI ajudamais -e "DELETE FROM users WHERE id=1;" >/dev/null 2>&1
check "exclusão de usuário com LGPD" "0" "$(q "SELECT COUNT(*) FROM ajudamais.users WHERE id=1;")"
check "doação anonimizada" "1" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='A1' AND is_anonymous=1;")"

echo; echo "=== Migration: banco novo ==="
$CLI -e "DROP DATABASE IF EXISTS am_new; CREATE DATABASE am_new;"
$CLI --database=am_new < 02-migration.sql 2>/tmp/m1.txt; check "importa" "0" "$?"
[ -s /tmp/m1.txt ] && { head -10 /tmp/m1.txt; fail=1; }
$CLI --database=am_new < 02-migration.sql 2>/tmp/m2.txt; check "reexecuta" "0" "$?"
[ -s /tmp/m2.txt ] && { head -10 /tmp/m2.txt; fail=1; }

echo; echo "=== Migration: base legada mínima ==="
$CLI -e "DROP DATABASE IF EXISTS am_min; CREATE DATABASE am_min;"
$CLI am_min <<'SQL'
CREATE TABLE usuarios (id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150), email VARCHAR(150), cpf VARCHAR(14), senha VARCHAR(255));
CREATE TABLE instituicoes (id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150), email VARCHAR(150));
CREATE TABLE doacoes (id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, instituicao_id INT, descricao TEXT, status VARCHAR(20));
CREATE TABLE solicitacoes (id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, titulo VARCHAR(150), descricao TEXT);
INSERT INTO usuarios (nome,email,cpf,senha) VALUES ('Ana','ana@min.com','111.444.777-35','h');
INSERT INTO instituicoes (nome,email) VALUES ('Lar','lar@min.com');
INSERT INTO doacoes (usuario_id,instituicao_id,descricao,status) VALUES (1,1,'Cesta','confirmada'),(NULL,NULL,'Anônima',NULL);
INSERT INTO solicitacoes (usuario_id,titulo,descricao) VALUES (1,'Roupas','Infantis');
SQL
$CLI --database=am_min < 02-migration.sql 2>/tmp/m3.txt; check "importa" "0" "$?"
[ -s /tmp/m3.txt ] && { head -10 /tmp/m3.txt; fail=1; }
$CLI --database=am_min < 02-migration.sql 2>/tmp/m4.txt; check "reexecuta" "0" "$?"
[ -s /tmp/m4.txt ] && { head -10 /tmp/m4.txt; fail=1; }
check "usuário migrado" "1" "$(q "SELECT COUNT(*) FROM am_min.users;")"
check "CPF normalizado" "11144477735" "$(q "SELECT cpf FROM am_min.users;")"
check "doações migradas" "2" "$(q "SELECT COUNT(*) FROM am_min.donations;")"
check "anônima preservada" "1" "$(q "SELECT COUNT(*) FROM am_min.donations WHERE is_anonymous=1;")"
check "originais intactas" "1" "$(q "SELECT COUNT(*) FROM am_min.usuarios;")"

echo; echo "=== Migration: base legada completa ==="
$CLI -e "DROP DATABASE IF EXISTS am_full; CREATE DATABASE am_full;"
$CLI am_full <<'SQL'
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150), email VARCHAR(150), cpf VARCHAR(14),
  senha VARCHAR(255), tipo VARCHAR(20), telefone VARCHAR(20), criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE instituicoes (
  id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150), cnpj VARCHAR(20), endereco VARCHAR(180),
  cidade VARCHAR(100), estado VARCHAR(2), email VARCHAR(150), telefone VARCHAR(20));
CREATE TABLE doacoes (
  id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, instituicao_id INT, descricao TEXT,
  categoria VARCHAR(50), quantidade INT, status VARCHAR(20), observacao VARCHAR(255),
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE solicitacoes (
  id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, titulo VARCHAR(150), descricao TEXT,
  categoria VARCHAR(50), status VARCHAR(20), criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
INSERT INTO usuarios (nome,email,cpf,senha,tipo,telefone) VALUES
  ('Maria','maria@f.com','111.444.777-35','h','doador','(11) 98888-7777'),
  ('ONG','ong@f.com','529.982.247-25','h','instituicao',NULL);
INSERT INTO instituicoes (nome,cnpj,endereco,cidade,estado,email,telefone)
  VALUES ('Casa','11.222.333/0001-81','Rua A, 1','São Paulo','SP','casa@f.com','(11) 3333-4444');
INSERT INTO doacoes (usuario_id,instituicao_id,descricao,categoria,quantidade,status,observacao)
  VALUES (1,1,'20 cestas','alimentos',20,'confirmada','ok');
INSERT INTO solicitacoes (usuario_id,titulo,descricao,categoria,status)
  VALUES (2,'Roupas','Infantis','roupas','aberta');
SQL
$CLI --database=am_full < 02-migration.sql 2>/tmp/m5.txt; check "importa" "0" "$?"
[ -s /tmp/m5.txt ] && { head -10 /tmp/m5.txt; fail=1; }
$CLI --database=am_full < 02-migration.sql 2>/tmp/m6.txt; check "reexecuta" "0" "$?"
[ -s /tmp/m6.txt ] && { head -10 /tmp/m6.txt; fail=1; }
qF() { $M --database=am_full -e "$1" 2>/dev/null; }
check "CNPJ normalizado" "11222333000181" "$(qF "SELECT cnpj FROM institutions;")"
check "telefone E.164" "+5511988887777" "$(qF "SELECT phone_e164 FROM users WHERE email='maria@f.com';")"
check "UF do endereço" "SP" "$(qF "SELECT state_code FROM addresses WHERE institution_id IS NOT NULL;")"
check "categoria do item" "alimentos" "$(qF "SELECT c.slug FROM donation_items di JOIN item_categories c ON c.id=di.category_id;")"
check "quantidade" "20.00" "$(qF "SELECT quantity FROM donation_items;")"
check "papel instituicao" "instituicao" "$(qF "SELECT r.code FROM user_roles ur JOIN roles r ON r.id=ur.role_id JOIN users u ON u.id=ur.user_id WHERE u.email='ong@f.com' AND r.code='instituicao';")"

echo
if [ "$fail" -eq 0 ]; then echo "RESULTADO MySQL: TODOS OS TESTES PASSARAM"; else echo "RESULTADO MySQL: HOUVE FALHAS"; fi
exit "$fail"
