// Recuperar senha: redefinição real do backend (e-mail + CPF + nova senha).
// Não há envio de link/código por e-mail no backend atual, então a troca é
// feita aqui mesmo, com os dados que só o dono da conta conhece.
document.getElementById("form").addEventListener("submit", function (e) {
  e.preventDefault();
  var data = {
    email: value("email").trim(),
    cpf: value("cpf"),
    password: value("password"),
    confirm: value("confirm")
  };

  var errors = {};
  if (!isValidEmail(data.email)) errors.email = "Informe o e-mail da conta.";
  if (!isValidCpf(data.cpf)) errors.cpf = "Informe o CPF da conta.";
  if (data.password.length < MIN_PASSWORD_LENGTH) {
    errors.password = "A senha precisa ter no mínimo " + MIN_PASSWORD_LENGTH + " caracteres.";
  }
  if (data.confirm !== data.password) errors.confirm = "As senhas não coincidem.";
  if (!showErrors(errors, ["email", "cpf", "password", "confirm"])) return;

  var button = e.target.querySelector('button[type="submit"]');
  if (button) button.disabled = true;

  AuthService.redefinirSenha(data).then(function (r) {
    if (button) button.disabled = false;
    if (r.ok) {
      showToast("Senha redefinida! Redirecionando para o login...");
      setTimeout(function () { window.location.href = "login.html"; }, 1200);
    } else {
      showToast(r.message);
    }
  });
});

// Se a pessoa veio da tela "Recuperar conta", o e-mail já vem preenchido.
(function preencherEmail() {
  var email = new URLSearchParams(location.search).get("email");
  if (!email || !isValidEmail(email)) return;
  var campo = document.getElementById("email");
  if (campo) campo.value = email;
})();
