// Tela Criar conta: envia os dados para POST /api/auth/register.
// O backend grava o usuário no MySQL e devolve a sessão (token).
document.getElementById("form").addEventListener("submit", function (e) {
  e.preventDefault();
  var ids = ["name", "email", "cpf", "password", "confirm"];
  var data = {};
  ids.forEach(function (id) { data[id] = value(id); });
  if (!showErrors(validateSignup(data), ids)) return;

  var button = e.target.querySelector('button[type="submit"]');
  if (button) button.disabled = true;

  AuthService.cadastrar({
    full_name: data.name.trim(),
    email: data.email.trim(),
    cpf: data.cpf,
    password: data.password
  }).then(function (r) {
    if (button) button.disabled = false;
    if (r.ok) {
      showToast("Conta criada com sucesso! Redirecionando...");
      setTimeout(function () { window.location.href = "index.html"; }, 900);
    } else {
      // A API devolve o motivo real (CPF/e-mail já cadastrado, senha curta...).
      showToast(r.message);
    }
  });
});
