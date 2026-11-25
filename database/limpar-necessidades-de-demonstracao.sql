-- Remove somente as três solicitações de demonstração do dump inicial.
-- O registro chamado 'Teste 1' não é atingido por este script.
-- Os itens e históricos vinculados são tratados pelas FKs ON DELETE CASCADE.

START TRANSACTION;

SELECT id, title, created_at
FROM assistance_requests
WHERE (id = 1 AND title = 'Pedido PERSISTfpssxl')
   OR (id = 2 AND title = 'Cobertores para família')
   OR (id = 3 AND title = 'Cestas para vizinhos')
FOR UPDATE;

DELETE FROM assistance_requests
WHERE title <> 'Teste 1'
  AND (
    (id = 1 AND title = 'Pedido PERSISTfpssxl')
    OR (id = 2 AND title = 'Cobertores para família')
    OR (id = 3 AND title = 'Cestas para vizinhos')
  );

-- Conferência: 'Teste 1' deve continuar aparecendo, se existir.
SELECT id, title, created_at
FROM assistance_requests
ORDER BY id;

COMMIT;
