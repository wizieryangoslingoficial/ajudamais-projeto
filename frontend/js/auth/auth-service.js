// Camada única de acesso à API do AjudaMais (Express + MySQL).
// Contrato do backend:
//   sucesso  -> corpo JSON (ex.: { user, token, expires_at })
//   erro     -> { code, message, details? }
// Toda função devolve { ok, status, data, message } para as telas usarem
// sem precisar conhecer o formato cru do fetch.
var Api = (function () {
  var STORAGE_USER = "ajudamais_usuario";
  var STORAGE_TOKEN = "ajudamais_token";

  function getToken() {
    try { return localStorage.getItem(STORAGE_TOKEN) || ""; } catch (e) { return ""; }
  }

  function setSession(data) {
    if (data && data.token) {
      try { localStorage.setItem(STORAGE_TOKEN, data.token); } catch (e) { /* modo privado */ }
    }
    if (data && data.user) {
      try { localStorage.setItem(STORAGE_USER, JSON.stringify(data.user)); } catch (e) { /* modo privado */ }
    }
  }

  function clearSession() {
    try {
      localStorage.removeItem(STORAGE_USER);
      localStorage.removeItem(STORAGE_TOKEN);
    } catch (e) { /* modo privado */ }
  }

  function cachedUser() {
    try {
      var raw = localStorage.getItem(STORAGE_USER);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  // Mensagem amigável a partir do erro do backend.
  function readError(json, status) {
    if (json && json.message) return json.message;
    if (status === 0) return "Não foi possível conectar ao servidor. Verifique se o backend está rodando.";
    if (status === 401) return "Sessão expirada. Entre novamente.";
    if (status === 403) return "Você não tem permissão para esta ação.";
    if (status === 404) return "Registro não encontrado.";
    if (status === 409) return "Já existe um registro com estes dados.";
    if (status === 422) return "Confira os dados informados.";
    return "Não foi possível concluir a operação.";
  }

  function request(path, options) {
    options = options || {};
    var headers = { "Content-Type": "application/json" };
    var token = options.token !== undefined ? options.token : getToken();
    if (token) headers.Authorization = "Bearer " + token;

    var url = AJUDAMAIS_CONFIG.apiBaseUrl + path;
    // GET com parâmetros de consulta.
    if (options.query) {
      var qs = Object.keys(options.query)
        .filter(function (k) { return options.query[k] !== undefined && options.query[k] !== null && options.query[k] !== ""; })
        .map(function (k) { return encodeURIComponent(k) + "=" + encodeURIComponent(options.query[k]); })
        .join("&");
      if (qs) url += (url.indexOf("?") >= 0 ? "&" : "?") + qs;
    }

    return fetch(url, {
      method: options.method || "GET",
      headers: headers,
      body: options.body !== undefined ? JSON.stringify(options.body) : undefined
    })
      .then(function (res) {
        return res.text().then(function (text) {
          var json = null;
          if (text) {
            try { json = JSON.parse(text); } catch (e) { json = null; }
          }
          var ok = res.ok;
          if (ok && options.after) options.after(json);
          return {
            ok: ok,
            status: res.status,
            data: json,
            message: ok ? (json && json.message) || "" : readError(json, res.status)
          };
        });
      })
      .catch(function () {
        return { ok: false, status: 0, data: null, message: readError(null, 0) };
      });
  }

  function get(path, query) { return request(path, { query: query }); }
  function post(path, body) { return request(path, { method: "POST", body: body }); }
  function patch(path, body) { return request(path, { method: "PATCH", body: body }); }
  function del(path) { return request(path, { method: "DELETE" }); }

  return {
    request: request,
    get: get,
    post: post,
    patch: patch,
    del: del,
    getToken: getToken,
    setSession: setSession,
    clearSession: clearSession,
    cachedUser: cachedUser,
    isLogged: function () { return Boolean(getToken()); }
  };
})();

// Serviço de autenticação usado pelas telas de acesso.
var AuthService = (function () {
  function maskCpf(cpf) {
    var d = String(cpf || "").replace(/\D/g, "");
    return d ? "***" + d.slice(-2) : null;
  }

  // O dashboard usa nome/telefone; a API devolve full_name/phone_e164.
  function normalizeUser(u) {
    if (!u) return null;
    return {
      id: u.id,
      nome: u.full_name,
      display_name: u.display_name,
      email: u.email,
      cpf: maskCpf(u.cpf_masked ? u.cpf_masked.replace(/\D/g, "") : null),
      cpf_masked: u.cpf_masked,
      telefone: u.phone_e164,
      phone_e164: u.phone_e164,
      birth_date: u.birth_date,
      avatar_url: u.avatar_url,
      created_at: u.created_at
    };
  }

  function salvar(data) {
    if (!data || !data.token) return null;
    var user = normalizeUser(data.user);
    Api.setSession({ token: data.token, user: user });
    return user;
  }

  return {
    cadastrar: function (dados) {
      return Api.post("/auth/register", {
        full_name: dados.full_name,
        email: dados.email,
        cpf: dados.cpf,
        phone: dados.phone || null,
        password: dados.password,
        terms_accepted: true
      }).then(function (r) {
        if (r.ok) r.user = salvar(r.data);
        return r;
      });
    },

    entrar: function (dados) {
      var body = { password: dados.password };
      if (dados.email) body.email = dados.email;
      if (dados.cpf) body.cpf = dados.cpf;
      return Api.post("/auth/login", body).then(function (r) {
        if (r.ok) r.user = salvar(r.data);
        return r;
      });
    },

    sair: function () {
      var token = Api.getToken();
      return Api.request("/auth/logout", { method: "POST", body: {}, token: token })
        .then(function (r) {
          Api.clearSession();
          return r.ok ? r : { ok: true, message: "Sessão encerrada." };
        })
        .catch(function () {
          Api.clearSession();
          return { ok: true, message: "Sessão encerrada." };
        });
    },

    // Recuperação: localiza a conta por e-mail/celular (sem expor dados).
    recuperarConta: function (dados) {
      return Api.post("/auth/recover-account", { metodo: dados.metodo, valor: dados.valor });
    },

    // Redefinição real disponível no backend: e-mail + CPF + nova senha.
    redefinirSenha: function (dados) {
      return Api.post("/auth/redefine-password", {
        email: dados.email, cpf: dados.cpf, password: dados.password
      });
    },

    // Perfil atual lido do banco (não confia só no cache local).
    usuarioAtual: function () {
      var cached = Api.cachedUser();
      if (!Api.isLogged()) return Promise.resolve(cached);
      return Api.get("/users/me").then(function (r) {
        if (r.ok && r.data && r.data.user) {
          var user = normalizeUser(r.data.user);
          Api.setSession({ user: user });
          return user;
        }
        if (r.status === 401) {
          Api.clearSession();
          return null;
        }
        return cached;
      });
    },

    atualizarPerfil: function (dados) {
      return Api.patch("/users/me", dados).then(function (r) {
        if (r.ok && r.data && r.data.user) {
          var user = normalizeUser(r.data.user);
          Api.setSession({ user: user });
          r.user = user;
        }
        return r;
      });
    }
  };
})();
