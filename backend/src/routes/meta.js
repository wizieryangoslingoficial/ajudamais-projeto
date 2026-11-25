import express from 'express';
import { one, query } from '../db.js';

const router = express.Router();

// Categorias reais do banco (item_categories), usadas pelos formulários do site.
// Devolve só as categorias principais, e as subcategorias de cada uma.
router.get('/categories', async (_req, res) => {
  const rows = await query(
    `SELECT id, parent_id, slug, name, icon, sort_order
       FROM item_categories
      WHERE is_active = 1
      ORDER BY sort_order, name`,
  );
  const main = rows.filter((c) => c.parent_id == null);
  const children = rows.reduce((acc, c) => {
    if (c.parent_id != null) (acc[c.parent_id] ??= []).push(c);
    return acc;
  }, {});
  res.json({
    categories: main.map((c) => ({ ...c, children: children[c.id] ?? [] })),
  });
});

// Números reais exibidos no painel inicial. Nada é inventado: tudo vem das
// tabelas de doações e solicitações, considerando apenas o que foi confirmado.
router.get('/stats', async (_req, res) => {
  const CONFIRMED = "('confirmada','em_transito','recebida')";

  const [money, items, people, openNeeds, donors, institutions] = await Promise.all([
    one(
      `SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
         FROM donations
        WHERE deleted_at IS NULL AND donation_type = 'dinheiro' AND status IN ${CONFIRMED}`,
    ),
    one(
      `SELECT COALESCE(SUM(di.quantity), 0) AS total, COUNT(DISTINCT di.donation_id) AS count
         FROM donation_items di
         JOIN donations d ON d.id = di.donation_id
        WHERE d.deleted_at IS NULL AND d.status IN ${CONFIRMED}`,
    ),
    one(
      `SELECT COALESCE(SUM(beneficiary_count), 0) AS total
         FROM assistance_requests
        WHERE deleted_at IS NULL AND status IN ('atendida','parcialmente_atendida')`,
    ),
    one(
      `SELECT COUNT(*) AS count
         FROM assistance_requests
        WHERE deleted_at IS NULL AND is_public = 1 AND status IN ('aberta','parcialmente_atendida')`,
    ),
    one(
      `SELECT COUNT(DISTINCT donor_user_id) AS count
         FROM donations
        WHERE deleted_at IS NULL AND donor_user_id IS NOT NULL AND status IN ${CONFIRMED}`,
    ),
    one("SELECT COUNT(*) AS count FROM institutions WHERE deleted_at IS NULL AND status = 'verificada'"),
  ]);

  res.json({
    money_total: Number(money?.total ?? 0),
    money_count: Number(money?.count ?? 0),
    items_total: Number(items?.total ?? 0),
    items_donations: Number(items?.count ?? 0),
    people_helped: Number(people?.total ?? 0),
    open_needs: Number(openNeeds?.count ?? 0),
    donors: Number(donors?.count ?? 0),
    institutions: Number(institutions?.count ?? 0),
  });
});

export default router;
