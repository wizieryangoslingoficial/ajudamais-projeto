// Tela Entrar: envia CPF (ou e-mail) + senha para POST /api/auth/login.
document.getElementById("form").addEventListener("submit", function (e) {
  e.preventDefault();
  var data = { cpf: value("cpf"), email: value("email"), password: value("password") };
  if (!showErrors(validateLogin(data), ["cpf", "email", "password"])) return;

  var button = e.target.querySelector('button[type="submit"]');
  if (button) button.disabled = true;

  AuthService.entrar(data).then(function (r) {
    if (button) button.disabled = false;
    if (r.ok) {
      showToast("Bem-vindo(a) de volta!");
      // Volta para a tela que pediu login, ou para o painel.
      var next = new URLSearchParams(location.search).get("next");
      setTimeout(function () { window.location.href = /^[a-z0-9_-]+\.html$/i.test(next || "") ? next : "index.html"; }, 600);
    } else {
      showToast(r.message);
    }
  });
});
