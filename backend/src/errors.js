export class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const badRequest = (msg, details) => new HttpError(400, 'requisicao_invalida', msg, details);
export const unauthorized = (msg = 'Autenticação necessária') => new HttpError(401, 'nao_autenticado', msg);
export const forbidden = (msg = 'Sem permissão para esta ação') => new HttpError(403, 'sem_permissao', msg);
export const notFound = (msg = 'Registro não encontrado') => new HttpError(404, 'nao_encontrado', msg);
export const conflict = (msg, details) => new HttpError(409, 'conflito', msg, details);
