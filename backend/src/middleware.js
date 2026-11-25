import { HttpError } from './errors.js';

export { HttpError, badRequest, unauthorized, forbidden, notFound, conflict } from './errors.js';
export {
  assertInstitutionStaff, audit, bearerToken, hashPassword, hashToken, issueSession, loadRoles,
  requireAuth, requireRole, revokeSession, sessionUser, verifyPassword,
} from './auth.js';

// Valida com zod e converte falha em 422 com a lista de campos.
export function parse(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const issues = result.error.issues.map((i) => ({ campo: i.path.join('.'), mensagem: i.message }));
    throw new HttpError(422, 'dados_invalidos', issues[0]?.mensagem ?? 'Dados inválidos', issues);
  }
  return result.data;
}
