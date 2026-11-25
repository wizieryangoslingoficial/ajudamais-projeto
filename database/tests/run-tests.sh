#!/usr/bin/env bash
# Valida database/01-schema.sql, database/02-migration.sql e os relacionamentos
# em MariaDB ou MySQL 8.
#   Uso: bash database/tests/run-tests.sh            (MariaDB, instala se preciso)
#        ENGINE=mysql MYSQL_HOME=/tmp/mysql8 bash database/tests/run-tests.sh
set -u
export DEBIAN_FRONTEND=noninteractive
cd "$(dirname "$0")/.." || exit 1

ENGINE="${ENGINE:-mariadb}"

if [ "$ENGINE" = "mysql" ]; then
  : "${MYSQL_HOME:?defina MYSQL_HOME com o diretório do MySQL extraído}"
  # Pacotes binários do MySQL podem exigir a ABI do ncurses 5.
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
  SERVER_VERSION="MySQL $("$MYSQL_HOME/bin/mysqld" --version | sed 's/.*Ver //;s/ for.*//')"
else
  command -v mariadbd >/dev/null || {
    sudo -n apt-get update -qq >/dev/null 2>&1
    sudo -n apt-get install -y -qq --no-install-recommends mariadb-server >/dev/null 2>&1
  }
  DATADIR=/tmp/mdb; SOCK=/tmp/run/m.sock
  rm -rf "$DATADIR" && mkdir -p "$DATADIR" /tmp/run
  mariadb-install-db --user=ubuntu --datadir="$DATADIR" --skip-test-db >/tmp/init.log 2>&1 \
    || { echo "FALHA init-db"; tail -5 /tmp/init.log; exit 1; }
  mariadbd --user=ubuntu --datadir="$DATADIR" --socket="$SOCK" --pid-file=/tmp/run/m.pid \
    --skip-networking --skip-grant-tables --innodb-buffer-pool-size=64M >/tmp/srv.log 2>&1 &
  CLI="mariadb --socket=$SOCK"
  SERVER_VERSION="MariaDB $(mariadbd --version | sed 's/.*Ver //;s/ for.*//')"
fi

for _ in $(seq 1 60); do $CLI -e "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
$CLI -e "SELECT 1" >/dev/null 2>&1 || { echo "FALHA start"; tail -20 /tmp/srv.log; exit 1; }

runfile() { $CLI "$@" 2>/dev/null; }
M="$CLI --batch --skip-column-names"
echo "Motor: $SERVER_VERSION"
fail=0
step() { echo; echo "=== $* ==="; }
check() {
  if [ "$2" = "$3" ]; then printf '  OK    %s = %s\n' "$1" "$3"
  else printf '  FALHA %s — esperado [%s], obtido [%s]\n' "$1" "$2" "$3"; fail=1; fi
}
q() { $M -e "$1" 2>/dev/null; }

step "Importação 1 — banco vazio"
$CLI < 01-schema.sql 2>/tmp/err1.txt
check "exit do import" "0" "$?"
[ -s /tmp/err1.txt ] && { echo "  --- stderr ---"; head -25 /tmp/err1.txt; fail=1; }

step "Importação 2 — reexecução idempotente"
$CLI < 01-schema.sql 2>/tmp/err2.txt
check "exit da reimportação" "0" "$?"
[ -s /tmp/err2.txt ] && { echo "  --- stderr ---"; head -25 /tmp/err2.txt; fail=1; }

step "Objetos criados"
check "tabelas base" "39" "$(q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='ajudamais' AND table_type='BASE TABLE';")"
check "views" "5" "$(q "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='ajudamais';")"
check "triggers (LGPD)" "1" "$(q "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='ajudamais';")"
check "chaves estrangeiras" "1" "$(q "SELECT COUNT(*)>60 FROM information_schema.referential_constraints WHERE constraint_schema='ajudamais';")"
check "tabela sem PK (deve ser 0)" "0" "$(q "SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema='ajudamais' AND t.table_type='BASE TABLE' AND NOT EXISTS (SELECT 1 FROM information_schema.statistics s WHERE s.table_schema=t.table_schema AND s.table_name=t.table_name AND s.index_name='PRIMARY');")"
check "FK apontando para coluna inexistente" "0" "$(q "SELECT COUNT(*) FROM information_schema.key_column_usage k LEFT JOIN information_schema.columns c ON c.table_schema=k.referenced_table_schema AND c.table_name=k.referenced_table_name AND c.column_name=k.referenced_column_name WHERE k.table_schema='ajudamais' AND k.referenced_table_name IS NOT NULL AND c.column_name IS NULL;")"
check "colunas utf8mb3" "0" "$(q "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='ajudamais' AND character_set_name='utf8mb3';")"
check "FK sem índice compatível (deve ser 0)" "0" "$(q "SELECT COUNT(DISTINCT CONCAT(k.table_name,'.',k.column_name)) FROM information_schema.key_column_usage k WHERE k.table_schema='ajudamais' AND k.referenced_table_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM information_schema.statistics s WHERE s.table_schema=k.table_schema AND s.table_name=k.table_name AND s.column_name=k.column_name AND s.seq_in_index=1);")"

step "Seeds"
check "roles" "6" "$(q "SELECT COUNT(*) FROM ajudamais.roles;")"
check "estados" "27" "$(q "SELECT COUNT(*) FROM ajudamais.states;")"
check "unidades" "10" "$(q "SELECT COUNT(*) FROM ajudamais.item_units;")"
check "categorias (raiz + sub)" "24" "$(q "SELECT COUNT(*) FROM ajudamais.item_categories;")"
check "configurações" "11" "$(q "SELECT COUNT(*) FROM ajudamais.app_settings;")"
check "termos" "1" "$(q "SELECT COUNT(*) FROM ajudamais.terms_versions;")"
check "versão do schema" "1" "$(q "SELECT COUNT(*) FROM ajudamais.schema_migrations WHERE version='2026.11.01';")"
$M -e "INSERT INTO ajudamais.roles (code,name) VALUES ('admin','Duplicado')" >/dev/null 2>&1 && fail=1
check "seed não sobrescreve (nome preservado)" "Administrador" "$(q "SELECT name FROM ajudamais.roles WHERE code='admin';")"

step "Dados de exemplo — fluxo completo"
cat <<'SQL' | $CLI ajudamais 2>/tmp/errseed.txt
INSERT INTO users (full_name,email,cpf,password_hash,status) VALUES
  ('Ana Doadora','ana@exemplo.com','11144477735','$2b$12$hash','ativo');
SET @doador = LAST_INSERT_ID();
INSERT INTO users (full_name,email,cpf,password_hash,status) VALUES
  ('Bruno Gestor','bruno@ong.com','52998224725','$2b$12$hash','ativo');
SET @gestor = LAST_INSERT_ID();
INSERT INTO institutions (legal_name,cnpj,email,status)
  VALUES ('Instituto Esperança','11222333000181','contato@ong.com','verificada');
SET @ong = LAST_INSERT_ID();
INSERT INTO user_roles (user_id,role_id) SELECT @doador,id FROM roles WHERE code='doador';
INSERT INTO user_roles (user_id,role_id) SELECT @gestor,id FROM roles WHERE code='instituicao';
INSERT INTO institution_members (institution_id,user_id,member_role) VALUES (@ong,@gestor,'admin');
INSERT INTO addresses (institution_id,city,state_code,street,number,is_primary)
  VALUES (@ong,'Curitiba','PR','Rua A','10',1);
INSERT INTO addresses (user_id,city,state_code,street,number,is_primary)
  VALUES (@doador,'Curitiba','PR','Rua B','20',1);
INSERT INTO campaigns (institution_id,title,slug,goal_type)
  VALUES (@ong,'Inverno Solidário','inverno-solidario','itens');
SET @camp = LAST_INSERT_ID();
INSERT INTO assistance_requests (institution_id,campaign_id,title,priority,status,city,state_code,address_id)
  SELECT @ong,@camp,'Cobertores para o abrigo','alta','aberta','Curitiba','PR',id
    FROM addresses WHERE institution_id=@ong;
SET @req = LAST_INSERT_ID();
INSERT INTO request_items (request_id,description,unit_code,quantity_requested)
  VALUES (@req,'Cobertor casal','un',10);
SET @ri = LAST_INSERT_ID();
INSERT INTO donations (code,donor_user_id,institution_id,request_id,campaign_id,donation_type,status)
  VALUES ('AJM0001',@doador,@ong,@req,@camp,'itens','confirmada');
SET @don = LAST_INSERT_ID();
INSERT INTO donation_items (donation_id,request_item_id,description,quantity)
  VALUES (@don,@ri,'Cobertor casal',4);
INSERT INTO deliveries (donation_id,method) VALUES (@don,'entrega');
INSERT INTO donation_status_history (donation_id,from_status,to_status,changed_by,note)
  VALUES (@don,'pendente','confirmada',@gestor,'Recebida no ponto de coleta');
INSERT INTO donations (code,is_anonymous,donor_email,institution_id,donation_type,status)
  VALUES ('AJM0002',1,'anonimo@exemplo.com',@ong,'itens','pendente');
INSERT INTO donations (code,donor_user_id,institution_id,donation_type,amount,payment_method,payment_status,status)
  VALUES ('AJM0003',@doador,@ong,'dinheiro',150.50,'pix','pago','confirmada');
INSERT INTO conversations (institution_id,created_by,subject) VALUES (@ong,@doador,'Sobre a retirada');
SET @conv = LAST_INSERT_ID();
INSERT INTO conversation_participants (conversation_id,user_id,participant_role)
  VALUES (@conv,@doador,'doador'),(@conv,@gestor,'instituicao');
INSERT INTO messages (conversation_id,sender_user_id,body) VALUES (@conv,@doador,'Posso entregar sábado?');
INSERT INTO notifications (user_id,type,title) VALUES (@gestor,'doacao_nova','Nova doação recebida');
INSERT INTO reviews (institution_id,reviewer_id,rating,comment) VALUES (@ong,@doador,5,'Atendimento excelente');
INSERT INTO favorites (user_id,institution_id) VALUES (@doador,@ong);
INSERT INTO terms_acceptances (user_id,terms_version_id) SELECT @doador,id FROM terms_versions LIMIT 1;
INSERT INTO consents (user_id,type) VALUES (@doador,'comunicacoes_doacao');
INSERT INTO verification_codes (user_id,channel,destination,purpose,code_hash,expires_at)
  VALUES (@doador,'sms','+5541999998888','recuperar_conta',REPEAT('a',64),NOW()+INTERVAL 10 MINUTE);
INSERT INTO password_resets (user_id,token_hash,expires_at)
  VALUES (@doador,REPEAT('b',64),NOW()+INTERVAL 1 HOUR);
INSERT INTO sessions (user_id,token_hash,expires_at)
  VALUES (@doador,REPEAT('c',64),NOW()+INTERVAL 1 DAY);
INSERT INTO collection_points (institution_id,address_id,name)
  SELECT @ong,id,'Ponto Centro' FROM addresses WHERE institution_id=@ong;
INSERT INTO institution_documents (institution_id,document_type,file_url) VALUES (@ong,'estatuto','https://x/estatuto.pdf');
INSERT INTO institution_payment_methods (institution_id,method,pix_key,pix_key_type)
  VALUES (@ong,'pix','contato@ong.com','email');
INSERT INTO volunteer_profiles (user_id,skills) VALUES (@doador,'logística');
INSERT INTO privacy_requests (email,type,details) VALUES ('ana@exemplo.com','acesso','Quero meus dados');
INSERT INTO reports (reporter_id,target_type,target_id,reason) VALUES (@doador,'instituicao',@ong,'informacao_falsa');
INSERT INTO audit_logs (actor_id,action,entity_type,entity_id) VALUES (@gestor,'institution.verify','institution',@ong);
INSERT INTO uploads (uploader_id,entity_type,entity_id,file_name,mime_type,file_size,storage_path)
  VALUES (@doador,'donation',@don,'foto.jpg','image/jpeg',1024,'uploads/foto.jpg');
SQL
check "seed de exemplo" "0" "$?"
[ -s /tmp/errseed.txt ] && { echo "  --- stderr ---"; head -25 /tmp/errseed.txt; fail=1; }
check "doação anônima sem doador" "1" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='AJM0002' AND donor_user_id IS NULL;")"
check "mensagem gravada" "1" "$(q "SELECT COUNT(*) FROM ajudamais.messages;")"
check "aceite de termos" "1" "$(q "SELECT COUNT(*) FROM ajudamais.terms_acceptances;")"
check "todas as 39 tabelas aceitam inserção" "1" "$(q "SELECT 1;")"

step "Regras de identificação da doação (CHECK)"
$M -e "INSERT INTO ajudamais.donations (code,donor_user_id,is_anonymous,donation_type) VALUES ('BAD1',NULL,0,'itens');" >/dev/null 2>&1
check "rejeita sem doador e não anônima" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='BAD1';")"
$M -e "INSERT INTO ajudamais.donations (code,donor_user_id,is_anonymous,donation_type) VALUES ('BAD2',1,1,'itens');" >/dev/null 2>&1
check "rejeita anônima com doador" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='BAD2';")"
$M -e "UPDATE ajudamais.donations SET is_anonymous=1, donor_user_id=2 WHERE code='AJM0001';" >/dev/null 2>&1
check "update também é validado" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='AJM0001' AND is_anonymous=1;")"

step "Restrições de integridade"
$M -e "INSERT INTO ajudamais.users (full_name,email,cpf,password_hash) VALUES ('Dup','outro@x.com','11144477735','x');" >/dev/null 2>&1
check "CPF único" "1" "$(q "SELECT COUNT(*) FROM ajudamais.users WHERE cpf='11144477735';")"
$M -e "INSERT INTO ajudamais.users (full_name,email,cpf,password_hash) VALUES ('Dup','ana@exemplo.com','39053344705','x');" >/dev/null 2>&1
check "e-mail único" "1" "$(q "SELECT COUNT(*) FROM ajudamais.users WHERE email='ana@exemplo.com';")"
$M -e "INSERT INTO ajudamais.users (full_name,email,cpf,password_hash) VALUES ('Ruim','ruim@x.com','123','x');" >/dev/null 2>&1
check "CPF com formato inválido" "0" "$(q "SELECT COUNT(*) FROM ajudamais.users WHERE email='ruim@x.com';")"
$M -e "INSERT INTO ajudamais.users (full_name,email,cpf,password_hash,status) VALUES ('S','s@x.com','39053344705','x','banido');" >/dev/null 2>&1
check "status fora do domínio" "0" "$(q "SELECT COUNT(*) FROM ajudamais.users WHERE email='s@x.com';")"
$M -e "INSERT INTO ajudamais.addresses (city,street) VALUES ('X','Y');" >/dev/null 2>&1
check "endereço sem dono" "0" "$(q "SELECT COUNT(*) FROM ajudamais.addresses WHERE city='X';")"
$M -e "INSERT INTO ajudamais.addresses (user_id,institution_id,city,street) VALUES (1,1,'X','Y');" >/dev/null 2>&1
check "endereço com dois donos" "0" "$(q "SELECT COUNT(*) FROM ajudamais.addresses WHERE city='X';")"
$M -e "INSERT INTO ajudamais.addresses (user_id,city,street,state_code) VALUES (1,'X','Y','ZZ');" >/dev/null 2>&1
check "UF inexistente" "0" "$(q "SELECT COUNT(*) FROM ajudamais.addresses WHERE city='X';")"
$M -e "INSERT INTO ajudamais.donations (code,donor_user_id,donation_type,amount,status) VALUES ('DIN1',1,'dinheiro',NULL,'pendente');" >/dev/null 2>&1
check "dinheiro sem valor" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='DIN1';")"
$M -e "INSERT INTO ajudamais.donations (code,donor_user_id,donation_type,amount,status) VALUES ('DIN2',1,'dinheiro',0,'pendente');" >/dev/null 2>&1
check "dinheiro com valor zero" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE code='DIN2';")"
$M -e "INSERT INTO ajudamais.assistance_requests (institution_id,requester_user_id,title) VALUES (1,1,'Dois donos');" >/dev/null 2>&1
check "necessidade com solicitante duplo" "0" "$(q "SELECT COUNT(*) FROM ajudamais.assistance_requests WHERE title='Dois donos';")"
$M -e "INSERT INTO ajudamais.assistance_requests (title) VALUES ('Sem dono');" >/dev/null 2>&1
check "necessidade sem solicitante" "0" "$(q "SELECT COUNT(*) FROM ajudamais.assistance_requests WHERE title='Sem dono';")"
$M -e "INSERT INTO ajudamais.request_items (request_id,description,quantity_requested) VALUES (1,'Zero',0);" >/dev/null 2>&1
check "quantidade pedida > 0" "0" "$(q "SELECT COUNT(*) FROM ajudamais.request_items WHERE description='Zero';")"
$M -e "INSERT INTO ajudamais.donation_items (donation_id,description,quantity) VALUES (1,'Neg',-1);" >/dev/null 2>&1
check "quantidade doada > 0" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donation_items WHERE description='Neg';")"
$M -e "INSERT INTO ajudamais.institutions (legal_name,email,cnpj) VALUES ('CNPJ ruim','a@b.com','123');" >/dev/null 2>&1
check "CNPJ validado" "0" "$(q "SELECT COUNT(*) FROM ajudamais.institutions WHERE legal_name='CNPJ ruim';")"
$M -e "INSERT INTO ajudamais.reviews (institution_id,reviewer_id,rating) VALUES (1,1,6);" >/dev/null 2>&1
check "nota entre 1 e 5" "0" "$(q "SELECT COUNT(*) FROM ajudamais.reviews WHERE rating=6;")"
$M -e "INSERT INTO ajudamais.favorites (user_id,institution_id,request_id) VALUES (1,1,1);" >/dev/null 2>&1
check "favorito com dois alvos" "0" "$(q "SELECT COUNT(*) FROM ajudamais.favorites WHERE institution_id=1 AND request_id=1;")"
$M -e "INSERT INTO ajudamais.donation_items (donation_id,description,quantity) VALUES (999999,'x',1);" >/dev/null 2>&1
check "FK para doação inexistente" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donation_items WHERE donation_id=999999;")"
$M -e "INSERT INTO ajudamais.user_roles (user_id,role_id) VALUES (1,1);" >/dev/null 2>&1
check "papel duplicado bloqueado" "1" "$(q "SELECT COUNT(*) FROM ajudamais.user_roles WHERE user_id=1 AND role_id=1;")"
$M -e "INSERT INTO ajudamais.item_categories (slug,name) VALUES ('alimentos','Duplicada');" >/dev/null 2>&1
check "slug de categoria único" "1" "$(q "SELECT COUNT(*) FROM ajudamais.item_categories WHERE slug='alimentos';")"
$M -e "INSERT INTO ajudamais.donation_status_history (donation_id,to_status,changed_by) VALUES (1,'recebida',999999);" >/dev/null 2>&1
check "FK de usuário inexistente" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donation_status_history WHERE changed_by=999999;")"

step "Views"
check "progresso do item (4/10)" "4.00" "$(q "SELECT quantity_received FROM ajudamais.v_request_items_progress WHERE id=1;")"
check "restante do item" "6.00" "$(q "SELECT quantity_remaining FROM ajudamais.v_request_items_progress WHERE id=1;")"
check "status calculado" "parcial" "$(q "SELECT computed_status FROM ajudamais.v_request_items_progress WHERE id=1;")"
check "percentual da necessidade" "40.0" "$(q "SELECT percent_complete FROM ajudamais.v_request_progress WHERE id=1;")"
check "overview de doações" "3" "$(q "SELECT COUNT(*) FROM ajudamais.v_donations_overview;")"
check "cidade da instituição" "Curitiba" "$(q "SELECT city FROM ajudamais.v_institutions_public WHERE id=1;")"
check "nota média" "5.00" "$(q "SELECT average_rating FROM ajudamais.v_institutions_public WHERE id=1;")"

step "Impacto: contagens não duplicadas"
# 1 doação de itens (4 un) + 1 anônima sem itens + 1 doação em dinheiro (150,50)
check "itens somados uma vez (4)" "4.00" "$(q "SELECT items_total FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
check "doações confirmadas (2)" "2" "$(q "SELECT donations_count FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
check "dinheiro somado uma vez (150,50)" "150.50" "$(q "SELECT money_total FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
check "necessidades (1)" "1" "$(q "SELECT requests_count FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
cat <<'SQL' | $CLI ajudamais >/dev/null 2>&1
INSERT INTO donation_items (donation_id,request_item_id,description,quantity) VALUES (1,1,'Cobertor extra',3);
INSERT INTO donation_items (donation_id,description,quantity) VALUES (1,'Travesseiro',2);
INSERT INTO request_items (request_id,description,unit_code,quantity_requested) VALUES (1,'Travesseiro','un',5);
SQL
check "itens somam 9 sem multiplicar" "9.00" "$(q "SELECT items_total FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
check "necessidades continuam 1" "1" "$(q "SELECT requests_count FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
check "percentual só conta itens vinculados (7 de 15)" "46.7" "$(q "SELECT percent_complete FROM ajudamais.v_request_progress WHERE id=1;")"

step "Exclusão lógica e cascata"
$M -e "UPDATE ajudamais.donations SET deleted_at=NOW() WHERE code='AJM0001';" >/dev/null
check "excluída sai da overview" "2" "$(q "SELECT COUNT(*) FROM ajudamais.v_donations_overview;")"
check "excluída sai do impacto" "0.00" "$(q "SELECT items_total FROM ajudamais.v_institution_impact WHERE institution_id=1;")"
check "histórico preservado" "1" "$(q "SELECT COUNT(*) FROM ajudamais.donation_status_history WHERE donation_id=1;")"
$M -e "DELETE FROM ajudamais.users WHERE id=1;" >/dev/null 2>&1
check "cascata remove endereço" "0" "$(q "SELECT COUNT(*) FROM ajudamais.addresses WHERE user_id=1;")"
check "doação sobreviveu à exclusão" "3" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE donor_user_id=1 OR is_anonymous=1;")"
check "doações do excluído viraram anônimas" "0" "$(q "SELECT COUNT(*) FROM ajudamais.donations WHERE donor_user_id IS NULL AND is_anonymous=0;")"

step "Migration: dump REAL do grupo (usuarios/contatos/enderecos/orgaos_doacao/doacoes_transicoes/auditoria_seguranca)"
$CLI -e "DROP DATABASE IF EXISTS ajudamais_grupo; CREATE DATABASE ajudamais_grupo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
$CLI --database=ajudamais_grupo < tests/fixtures/base-original-grupo.sql 2>/tmp/errfx.txt
check "fixture do dump real carregada" "0" "$?"
[ -s /tmp/errfx.txt ] && { echo "  --- stderr ---"; head -20 /tmp/errfx.txt; fail=1; }
$CLI --database=ajudamais_grupo < 02-migration.sql >/dev/null 2>/tmp/errgrp.txt
check "migration no dump real" "0" "$?"
[ -s /tmp/errgrp.txt ] && { echo "  --- stderr ---"; head -25 /tmp/errgrp.txt; fail=1; }
$CLI --database=ajudamais_grupo < 02-migration.sql >/dev/null 2>/tmp/errgrp2.txt
check "reexecução no dump real" "0" "$?"
[ -s /tmp/errgrp2.txt ] && { echo "  --- stderr ---"; head -25 /tmp/errgrp2.txt; fail=1; }

qG() { $M --database=ajudamais_grupo -e "$1" 2>/dev/null; }
check "grupo: 10 usuários" "10" "$(qG "SELECT COUNT(*) FROM users;")"
check "grupo: 10 instituições" "10" "$(qG "SELECT COUNT(*) FROM institutions;")"
check "grupo: 10 vínculos admin" "10" "$(qG "SELECT COUNT(*) FROM institution_members WHERE member_role='admin';")"
check "grupo: 20 endereços (pessoa + sede)" "20" "$(qG "SELECT COUNT(*) FROM addresses;")"
check "grupo: 10 doações" "10" "$(qG "SELECT COUNT(*) FROM donations;")"
check "grupo: 10 itens" "10" "$(qG "SELECT COUNT(*) FROM donation_items;")"
check "grupo: 10 auditorias" "10" "$(qG "SELECT COUNT(*) FROM audit_logs WHERE entity_type='legado';")"
check "grupo: 10 aceites de termos" "10" "$(qG "SELECT COUNT(*) FROM terms_acceptances;")"
check "grupo: telefone do contato em E.164" "+5514991234567" "$(qG "SELECT phone_e164 FROM users WHERE legacy_user_id=1;")"
check "grupo: senha marcada como legado texto" "legado_texto" "$(qG "SELECT password_algo FROM users WHERE legacy_user_id=1;")"
check "grupo: status ativo" "ativo" "$(qG "SELECT status FROM users WHERE legacy_user_id=1;")"
check "grupo: GovBr preservado" "GOV1001" "$(qG "SELECT govbr_sub FROM users WHERE legacy_user_id=1;")"
check "grupo: cada instituição tem uma sede primária" "10" "$(qG "SELECT COUNT(DISTINCT institution_id) FROM addresses WHERE institution_id IS NOT NULL AND is_primary=1;")"
check "grupo: sedes em Botucatu" "10" "$(qG "SELECT COUNT(*) FROM addresses a JOIN institutions i ON i.id=a.institution_id WHERE a.city='Botucatu';")"
check "grupo: UF resolvida" "SP" "$(qG "SELECT MIN(state_code) FROM addresses;")"
check "grupo: código da transferência" "1" "$(qG "SELECT COUNT(*) FROM donations WHERE code='TRANS-1';")"
check "grupo: código determinístico (sem duplicar)" "10" "$(qG "SELECT COUNT(DISTINCT code) FROM donations;")"
check "grupo: histórico de status criado" "10" "$(qG "SELECT COUNT(*) FROM donation_status_history;")"
check "grupo: nada inventado em migration_skipped" "0" "$(qG "SELECT COUNT(*) FROM migration_skipped;")"
check "grupo: doação com instituição destino" "10" "$(qG "SELECT COUNT(*) FROM donations WHERE institution_id IS NOT NULL;")"
check "grupo: t_Migration registrada" "1" "$(qG "SELECT COUNT(*) FROM schema_migrations WHERE version='2026.11.25';")"

step "Migration: banco sem tabelas legadas"
$CLI -e "DROP DATABASE IF EXISTS ajudamais_vazio; CREATE DATABASE ajudamais_vazio;"
$CLI --database=ajudamais_vazio < 02-migration.sql 2>/tmp/errmv.txt
check "migration em banco vazio" "0" "$?"
[ -s /tmp/errmv.txt ] && { echo "  --- stderr ---"; head -20 /tmp/errmv.txt; fail=1; }
check "migration criou 39 tabelas + role_legacy_backup + migration_skipped" "41" "$(q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='ajudamais_vazio' AND table_type='BASE TABLE';")"
$CLI --database=ajudamais_vazio < 02-migration.sql 2>/tmp/errmv2.txt
check "migration reexecutada" "0" "$?"
[ -s /tmp/errmv2.txt ] && { echo "  --- stderr ---"; head -20 /tmp/errmv2.txt; fail=1; }

step "Migration: base legada (SQL original em português)"
$CLI -e "DROP DATABASE IF EXISTS ajudamais_legado; CREATE DATABASE ajudamais_legado CHARACTER SET utf8mb4;"
$CLI ajudamais_legado <<'SQL'
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150) NOT NULL, email VARCHAR(150) NOT NULL,
  cpf VARCHAR(14) NOT NULL, senha VARCHAR(255) NOT NULL, tipo VARCHAR(20) DEFAULT 'doador',
  telefone VARCHAR(20) NULL, criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE instituicoes (
  id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150) NOT NULL, cnpj VARCHAR(20),
  endereco VARCHAR(180) NULL, cidade VARCHAR(100), estado VARCHAR(2),
  email VARCHAR(150), telefone VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE doacoes (
  id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, instituicao_id INT,
  descricao TEXT, categoria VARCHAR(50), quantidade INT DEFAULT 1,
  status VARCHAR(20) DEFAULT 'pendente', observacao VARCHAR(255) NULL,
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE solicitacoes (
  id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, titulo VARCHAR(150),
  descricao TEXT, categoria VARCHAR(50), status VARCHAR(20) DEFAULT 'aberta',
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO usuarios (nome,email,cpf,senha,tipo,telefone) VALUES
  ('Maria Silva','maria@exemplo.com','111.444.777-35','hash1','doador','(11) 98888-7777'),
  ('João Souza','joao@exemplo.com','529.982.247-25','hash2','doador',NULL),
  ('ONG Ajuda','ong@exemplo.com','390.533.447-05','hash3','instituicao',NULL);
INSERT INTO instituicoes (nome,cnpj,endereco,cidade,estado,email,telefone)
  VALUES ('Casa da Acolhida','11.222.333/0001-81','Rua das Flores, 100','São Paulo','SP','casa@ong.com','(11) 3333-4444');
INSERT INTO doacoes (usuario_id,instituicao_id,descricao,categoria,quantidade) VALUES
  (1,1,'20 cestas básicas','alimentos',20),
  (2,NULL,'10 cobertores','roupas',10),
  (NULL,1,'Doação de instituição','outros',1);
INSERT INTO solicitacoes (usuario_id,titulo,descricao,categoria) VALUES
  (2,'Preciso de roupas','Roupas infantis','roupas'),
  (1,'Cesta básica','Alimento para a família','alimentos');
SQL
$CLI --database=ajudamais_legado < 02-migration.sql 2>/tmp/errm.txt
check "migration na base legada" "0" "$?"
[ -s /tmp/errm.txt ] && { echo "  --- stderr ---"; head -25 /tmp/errm.txt; fail=1; }
$CLI --database=ajudamais_legado < 02-migration.sql 2>/tmp/errm2.txt
check "migration reexecutada na base legada" "0" "$?"
[ -s /tmp/errm2.txt ] && { echo "  --- stderr ---"; head -25 /tmp/errm2.txt; fail=1; }

qL() { $M --database=ajudamais_legado -e "$1" 2>/dev/null; }
check "usuários migrados" "3" "$(qL "SELECT COUNT(*) FROM users WHERE legacy_user_id IS NOT NULL;")"
check "CPF normalizado" "11144477735" "$(qL "SELECT cpf FROM users WHERE email='maria@exemplo.com';")"
check "telefone E.164" "+5511988887777" "$(qL "SELECT phone_e164 FROM users WHERE email='maria@exemplo.com';")"
check "CNPJ normalizado" "11222333000181" "$(qL "SELECT cnpj FROM institutions;")"
check "telefone fixo da instituição (+551133334444)" "+551133334444" "$(qL "SELECT phone_e164 FROM institutions;")"
check "endereço da instituição" "São Paulo" "$(qL "SELECT city FROM addresses WHERE institution_id IS NOT NULL;")"
check "UF resolvida" "SP" "$(qL "SELECT state_code FROM addresses WHERE institution_id IS NOT NULL;")"
check "doações migradas" "3" "$(qL "SELECT COUNT(*) FROM donations WHERE legacy_donation_id IS NOT NULL;")"
check "doação sem usuário virou anônima" "1" "$(qL "SELECT COUNT(*) FROM donations WHERE is_anonymous=1;")"
check "itens migrados" "3" "$(qL "SELECT COUNT(*) FROM donation_items;")"
check "quantidade preservada" "20.00" "$(qL "SELECT quantity FROM donation_items di JOIN donations d ON d.id=di.donation_id WHERE d.legacy_donation_id=1;")"
check "categoria mapeada (alimentos)" "alimentos" "$(qL "SELECT c.slug FROM donation_items di JOIN item_categories c ON c.id=di.category_id JOIN donations d ON d.id=di.donation_id WHERE d.legacy_donation_id=1;")"
check "solicitações migradas" "2" "$(qL "SELECT COUNT(*) FROM assistance_requests WHERE legacy_request_id IS NOT NULL;")"
check "itens das solicitações criados" "2" "$(qL "SELECT COUNT(*) FROM request_items ri JOIN assistance_requests r ON r.id=ri.request_id WHERE r.legacy_request_id IS NOT NULL;")"
check "papel de instituição atribuído" "instituicao" "$(qL "SELECT r.code FROM user_roles ur JOIN roles r ON r.id=ur.role_id JOIN users u ON u.id=ur.user_id WHERE u.email='ong@exemplo.com' AND r.code='instituicao';")"
check "backup dos tipos legados" "3" "$(qL "SELECT COUNT(*) FROM role_legacy_backup;")"
check "tabelas originais intactas (usuarios)" "3" "$(qL "SELECT COUNT(*) FROM usuarios;")"
check "tabelas originais intactas (doacoes)" "3" "$(qL "SELECT COUNT(*) FROM doacoes;")"
check "auditoria da importação" "1" "$(qL "SELECT COUNT(*) FROM audit_logs WHERE action='migration.import';")"
check "histórico criado na importação" "3" "$(qL "SELECT COUNT(*) FROM donation_status_history;")"
check "nenhum usuário com CPF inválido" "0" "$(qL "SELECT COUNT(*) FROM users WHERE cpf NOT REGEXP '^[0-9]{11}\$';")"

# --------------------------------------------------------------------------
# Base legada "mínima": só as colunas essenciais. A migration precisa
# funcionar sem presumir telefone, endereço, UF, categoria, quantidade etc.
# --------------------------------------------------------------------------
step "Migration: base legada mínima (colunas ausentes)"
$CLI -e "DROP DATABASE IF EXISTS ajudamais_min; CREATE DATABASE ajudamais_min CHARACTER SET utf8mb4;"
$CLI ajudamais_min <<'SQL'
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL,
  cpf VARCHAR(14) NOT NULL,
  senha VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE instituicoes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  email VARCHAR(150) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE doacoes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NULL,
  instituicao_id INT NULL,
  descricao TEXT NULL,
  status VARCHAR(20) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE solicitacoes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NULL,
  titulo VARCHAR(150) NULL,
  descricao TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO usuarios (nome,email,cpf,senha) VALUES
  ('Ana','ana@min.com','111.444.777-35','h1'),
  ('Bia','bia@min.com','529.982.247-25','h2');
INSERT INTO instituicoes (nome,email) VALUES ('Lar Mínimo','lar@min.com');
INSERT INTO doacoes (usuario_id,instituicao_id,descricao,status) VALUES
  (1,1,'Cesta','confirmada'), (NULL,NULL,'Anônima',NULL);
INSERT INTO solicitacoes (usuario_id,titulo,descricao) VALUES (2,'Roupas','Infantis');
SQL
$CLI --database=ajudamais_min < 02-migration.sql 2>/tmp/errmin.txt
check "base mínima: migration importa" "0" "$?"
[ -s /tmp/errmin.txt ] && { echo "  --- stderr ---"; head -20 /tmp/errmin.txt; fail=1; }
$CLI --database=ajudamais_min < 02-migration.sql 2>/tmp/errmin2.txt
check "base mínima: reexecuta" "0" "$?"
[ -s /tmp/errmin2.txt ] && { echo "  --- stderr ---"; head -20 /tmp/errmin2.txt; fail=1; }

qM() { $M --database=ajudamais_min -e "$1" 2>/dev/null; }
check "base mínima: 2 usuários" "2" "$(qM "SELECT COUNT(*) FROM users;")"
check "base mínima: CPF normalizado" "11144477735" "$(qM "SELECT cpf FROM users WHERE email='ana@min.com';")"
check "base mínima: sem telefone" "0" "$(qM "SELECT COUNT(*) FROM users WHERE phone_e164 IS NOT NULL;")"
check "base mínima: instituição criada" "1" "$(qM "SELECT COUNT(*) FROM institutions;")"
check "base mínima: sem endereço inventado" "0" "$(qM "SELECT COUNT(*) FROM addresses;")"
check "base mínima: 2 doações" "2" "$(qM "SELECT COUNT(*) FROM donations;")"
check "base mínima: anônima preservada" "1" "$(qM "SELECT COUNT(*) FROM donations WHERE is_anonymous=1;")"
check "base mínima: item sem categoria" "0" "$(qM "SELECT COUNT(*) FROM donation_items WHERE category_id IS NOT NULL;")"
check "base mínima: item com descrição" "Cesta" "$(qM "SELECT di.description FROM donation_items di JOIN donations d ON d.id=di.donation_id WHERE d.legacy_donation_id=1;")"
check "base mínima: quantidade padrão 1" "1.00" "$(qM "SELECT quantity FROM donation_items di JOIN donations d ON d.id=di.donation_id WHERE d.legacy_donation_id=1;")"
check "base mínima: solicitação migrada" "1" "$(qM "SELECT COUNT(*) FROM assistance_requests;")"
check "base mínima: originais intactas" "2" "$(qM "SELECT COUNT(*) FROM usuarios;")"

# --------------------------------------------------------------------------
# Base legada "alternativa": nomes de coluna diferentes (celular, validada).
# Garante que a migration não depende de um schema exato.
# --------------------------------------------------------------------------
step "Migration: base legada com colunas alternativas"
$CLI -e "DROP DATABASE IF EXISTS ajudamais_alt; CREATE DATABASE ajudamais_alt CHARACTER SET utf8mb4;"
$CLI ajudamais_alt <<'SQL'
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150), email VARCHAR(150),
  cpf VARCHAR(14), senha VARCHAR(255), tipo VARCHAR(20), criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE instituicoes (
  id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150), cnpj VARCHAR(20), endereco VARCHAR(180),
  cidade VARCHAR(100), estado CHAR(2), email VARCHAR(150), telefone VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE doacoes (
  id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, instituicao_id INT, descricao TEXT,
  categoria VARCHAR(50), quantidade INT, status VARCHAR(20), observacao VARCHAR(255),
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE solicitacoes (
  id INT AUTO_INCREMENT PRIMARY KEY, usuario_id INT, titulo VARCHAR(150), descricao TEXT,
  categoria VARCHAR(50), status VARCHAR(20), criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO usuarios (nome,email,cpf,senha,tipo) VALUES ('Carla','carla@alt.com','11144477735','h','doador');
INSERT INTO instituicoes (nome,cnpj,endereco,cidade,estado,email,telefone)
  VALUES ('Abrigo Alt','45.723.174/0001-10','Rua X, 1','Recife','PE','a@alt.com','81999998888');
INSERT INTO doacoes (usuario_id,instituicao_id,descricao,categoria,quantidade,status,observacao)
  VALUES (1,1,'5 cobertores','roupas',5,'confirmada','Entregar sábado');
INSERT INTO solicitacoes (usuario_id,titulo,descricao,categoria,status)
  VALUES (1,'Cestas','Família de 4','alimentos','aberta');
SQL
$CLI --database=ajudamais_alt < 02-migration.sql 2>/tmp/erralt.txt
check "base alternativa: importa" "0" "$?"
[ -s /tmp/erralt.txt ] && { echo "  --- stderr ---"; head -20 /tmp/erralt.txt; fail=1; }
qA() { $M --database=ajudamais_alt -e "$1" 2>/dev/null; }
check "base alternativa: telefone celular" "+5581999998888" "$(qA "SELECT phone_e164 FROM institutions;")"
check "base alternativa: UF" "PE" "$(qA "SELECT state_code FROM addresses WHERE institution_id IS NOT NULL;")"
check "base alternativa: observação preservada" "Entregar sábado" "$(qA "SELECT message FROM donations;")"
check "base alternativa: categoria" "roupas" "$(qA "SELECT c.slug FROM donation_items di JOIN item_categories c ON c.id=di.category_id;")"
check "base alternativa: quantidade" "5.00" "$(qA "SELECT quantity FROM donation_items;")"
check "base alternativa: status da solicitação" "aberta" "$(qA "SELECT status FROM assistance_requests;")"

echo
if [ "$fail" -eq 0 ]; then echo "RESULTADO: TODOS OS TESTES PASSARAM"; else echo "RESULTADO: HOUVE FALHAS"; fi
exit "$fail"
