import { z } from 'zod';

const onlyDigits = (v) => String(v ?? '').replace(/\D/g, '');

// CPF: 11 dígitos com dígitos verificadores válidos.
export function isValidCpf(input) {
  const cpf = onlyDigits(input);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;
  const digits = cpf.split('').map(Number);
  for (const [len, factor] of [[9, 10], [10, 11]]) {
    let sum = 0;
    for (let i = 0; i < len; i++) sum += digits[i] * (factor - i);
    const check = (sum * 10) % 11 % 10;
    if (check !== digits[len]) return false;
  }
  return true;
}

// CNPJ: 14 dígitos com dígitos verificadores válidos.
export function isValidCnpj(input) {
  const cnpj = onlyDigits(input);
  if (cnpj.length !== 14 || /^(\d)\1{13}$/.test(cnpj)) return false;
  const calc = (len) => {
    const weights = len === 12
      ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
      : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    let sum = 0;
    for (let i = 0; i < len; i++) sum += Number(cnpj[i]) * weights[i];
    const rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  };
  return calc(12) === Number(cnpj[12]) && calc(13) === Number(cnpj[13]);
}

// Telefone brasileiro -> E.164 (+55DDDNNNNNNNNN).
export function toE164(input) {
  const digits = onlyDigits(input);
  if (!digits) return null;
  if (digits.length === 13 && digits.startsWith('55')) return `+${digits}`;
  if (digits.length === 12 && digits.startsWith('55')) return `+${digits}`;
  if (digits.length === 11 || digits.length === 10) return `+55${digits}`;
  return null;
}

const cpfField = z.string().transform(onlyDigits).refine(isValidCpf, 'CPF inválido');
const phoneField = z.string().optional().nullable()
  .transform((v) => (v == null || String(v).trim() === '' ? null : toE164(v)))
  .refine((v) => v === null || /^\+55\d{10,11}$/.test(v), 'Telefone inválido');
const emailField = z.string().trim().toLowerCase().email('E-mail inválido').max(254);

export const registerSchema = z.object({
  full_name: z.string().trim().min(3, 'Informe seu nome completo').max(150),
  email: emailField,
  cpf: cpfField,
  phone: phoneField,
  password: z.string().min(8, 'A senha deve ter ao menos 8 caracteres').max(72),
  terms_accepted: z.literal(true, { errorMap: () => ({ message: 'É necessário aceitar os termos' }) }),
});

// A tela Entrar pede CPF (e-mail é opcional). Aceitamos CPF ou e-mail como
// identificador, sem exigir que o usuário digite os dois.
export const loginSchema = z.object({
  email: emailField.optional(),
  cpf: z.string().optional(),
  password: z.string().min(1, 'Informe a senha').max(72),
}).refine((d) => Boolean(d.email) || Boolean(d.cpf && onlyDigits(d.cpf)), {
  message: 'Informe o CPF ou o e-mail', path: ['cpf'],
}).refine((d) => !d.cpf || onlyDigits(d.cpf).length === 11, {
  message: 'CPF deve ter 11 dígitos', path: ['cpf'],
});

export const profileUpdateSchema = z.object({
  full_name: z.string().trim().min(3).max(150).optional(),
  display_name: z.string().trim().max(80).optional().nullable(),
  phone: phoneField.optional(),
  birth_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use AAAA-MM-DD').optional().nullable(),
  avatar_url: z.string().url().max(500).optional().nullable(),
});

export const addressSchema = z.object({
  label: z.string().trim().max(60).optional().nullable(),
  address_type: z.enum(['residencial', 'comercial', 'coleta', 'entrega', 'cobranca']).default('residencial'),
  postal_code: z.string().optional().nullable().transform((v) => (v ? onlyDigits(v).slice(0, 8) : null)),
  street: z.string().trim().min(2, 'Informe o logradouro').max(180),
  number: z.string().trim().max(20).optional().nullable(),
  complement: z.string().trim().max(120).optional().nullable(),
  district: z.string().trim().max(120).optional().nullable(),
  city: z.string().trim().min(2, 'Informe a cidade').max(120),
  state_code: z.string().trim().toUpperCase().length(2, 'UF com 2 letras').optional().nullable(),
  is_primary: z.coerce.boolean().optional().default(false),
});

export const institutionSchema = z.object({
  legal_name: z.string().trim().min(3).max(180),
  trade_name: z.string().trim().max(150).optional().nullable(),
  cnpj: z.string().optional().nullable()
    .transform((v) => (v == null || String(v).trim() === '' ? null : onlyDigits(v)))
    .refine((v) => v === null || isValidCnpj(v), 'CNPJ inválido'),
  institution_type: z.enum([
    'ong', 'igreja', 'escola', 'hospital', 'abrigo', 'orgao_publico', 'grupo_comunitario', 'outro',
  ]).default('ong'),
  description: z.string().trim().max(5000).optional().nullable(),
  email: emailField,
  phone: phoneField,
  website_url: z.string().url().max(500).optional().nullable(),
  accepts_items: z.coerce.boolean().optional().default(true),
  accepts_money: z.coerce.boolean().optional().default(false),
  accepts_volunteers: z.coerce.boolean().optional().default(false),
});

export const institutionUpdateSchema = institutionSchema.partial();

export const campaignSchema = z.object({
  title: z.string().trim().min(3).max(150),
  slug: z.string().trim().min(3).max(160).regex(/^[a-z0-9-]+$/, 'Use apenas letras minúsculas, números e hífen'),
  description: z.string().trim().max(10000).optional().nullable(),
  goal_type: z.enum(['itens', 'dinheiro']).default('itens'),
  goal_amount: z.coerce.number().positive().optional().nullable(),
  goal_quantity: z.coerce.number().int().positive().optional().nullable(),
  ends_at: z.string().datetime().optional().nullable(),
});

export const donationItemSchema = z.object({
  description: z.string().trim().min(2).max(200),
  category_id: z.coerce.number().int().positive().optional().nullable(),
  unit_code: z.string().trim().max(10).default('un'),
  quantity: z.coerce.number().positive('Quantidade deve ser maior que zero'),
  item_condition: z.enum(['novo', 'seminovo', 'usado']).default('usado'),
  request_item_id: z.coerce.number().int().positive().optional().nullable(),
});

// Doação pelo site: a instituição de destino é opcional. Quando não informada,
// a doação fica registrada e a administração direciona depois. Isso mantém o
// formulário atual (doação pessoal) funcionando sem inventar instituição.
export const donationSchema = z.object({
  institution_id: z.coerce.number().int().positive().optional().nullable(),
  donation_type: z.enum(['itens', 'dinheiro']).default('itens'),
  request_id: z.coerce.number().int().positive().optional().nullable(),
  campaign_id: z.coerce.number().int().positive().optional().nullable(),
  is_anonymous: z.coerce.boolean().optional().default(false),
  amount: z.coerce.number().positive().optional().nullable(),
  payment_method: z.enum(['pix', 'transferencia', 'cartao', 'boleto', 'dinheiro']).optional().nullable(),
  message: z.string().trim().max(500).optional().nullable(),
  donor_name: z.string().trim().max(150).optional().nullable(),
  donor_email: z.string().trim().toLowerCase().email('E-mail inválido').max(254).optional().nullable(),
  donor_phone: z.string().optional().nullable()
    .transform((v) => (v == null || String(v).trim() === '' ? null : toE164(v)))
    .refine((v) => v === null || /^\+55\d{10,11}$/.test(v), 'Telefone inválido'),
  // Endereço de coleta (linha em addresses do próprio doador) informado no
  // formulário de itens.
  dropoff_address_id: z.coerce.number().int().positive().optional().nullable(),
  items: z.array(donationItemSchema).optional().default([]),
}).refine((d) => d.donation_type === 'itens' || (d.amount != null && d.amount > 0), {
  message: 'Doação em dinheiro exige valor', path: ['amount'],
}).refine((d) => d.donation_type === 'dinheiro' || d.items.length > 0, {
  message: 'Doação de itens exige ao menos um item', path: ['items'],
});

export const donationStatusSchema = z.object({
  status: z.enum(['confirmada', 'em_transito', 'recebida', 'cancelada', 'recusada']),
  note: z.string().trim().max(255).optional().nullable(),
});

export const requestSchema = z.object({
  title: z.string().trim().min(5).max(150),
  description: z.string().trim().max(10000).optional().nullable(),
  category_id: z.coerce.number().int().positive().optional().nullable(),
  priority: z.enum(['baixa', 'normal', 'alta', 'urgente']).default('normal'),
  city: z.string().trim().max(120).optional().nullable(),
  state_code: z.string().trim().toUpperCase().length(2).optional().nullable(),
  beneficiary_count: z.coerce.number().int().positive().optional().nullable(),
  needed_by: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().nullable(),
  items: z.array(z.object({
    description: z.string().trim().min(2).max(200),
    category_id: z.coerce.number().int().positive().optional().nullable(),
    unit_code: z.string().trim().max(10).default('un'),
    quantity_requested: z.coerce.number().positive(),
  })).min(1, 'Informe ao menos um item'),
});

// Recuperação de conta: localiza a conta pelo e-mail ou celular cadastrado.
// Serve para orientar o usuário; a troca de senha ainda exige CPF.
export const recoverAccountSchema = z.object({
  metodo: z.enum(['email', 'phone']),
  valor: z.string().trim().min(3, 'Informe o e-mail ou celular'),
});

export const changePasswordSchema = z.object({
  current_password: z.string().min(1, 'Informe a senha atual').max(72),
  new_password: z.string().min(8, 'A nova senha deve ter ao menos 8 caracteres').max(72),
});

export const requestStatusSchema = z.object({
  status: z.enum(['aberta', 'parcialmente_atendida', 'atendida', 'cancelada', 'expirada']),
  note: z.string().trim().max(255).optional().nullable(),
});
