// Sessão: diferencia visitante (anônimo) de usuário logado.
// O usuário é lido do backend (/users/me) quando há token; sem token, visitante.
var Sessao = {
  carregar: function () {
    return AuthService.usuarioAtual().then(function (usuario) {
      document.body.dataset.acesso = usuario ? "logado" : "visitante";
      return usuario;
    });
  },
  exigirLogin: function () {
    return Sessao.carregar().then(function (usuario) {
      if (!usuario) {
        window.location.href = "login.html?next=" + encodeURIComponent(location.pathname.split("/").pop() || "index.html");
      }
      return usuario;
    });
  }
};
Sessao.carregar();
