// Recuperar conta: localiza a conta pelo e-mail ou celular (POST /auth/recover-account).
// O backend confirma apenas um contato mascarado; a troca de senha é feita na
// tela "Recuperar senha" com e-mail + CPF.
var method = "email";
var values = { email: "", phone: "" };
var input = document.getElementById("contact");
var options = document.querySelectorAll("[data-method]");

function setMethod(m) {
  values[method] = input.value;
  method = m;
  var isEmail = m === "email";
  options.forEach(function (o) { o.setAttribute("aria-checked", String(o.dataset.method === m)); });
  input.type = isEmail ? "email" : "tel";
  input.inputMode = isEmail ? "email" : "numeric";
  input.autocomplete = isEmail ? "email" : "tel";
  input.placeholder = isEmail ? "seu@email.com" : "(00) 00000-0000";
  input.setAttribute("aria-label", isEmail ? "E-mail" : "Celular");
  input.value = values[m];
  showErrors({}, ["contact"]);
}

options.forEach(function (o) { o.addEventListener("click", function () { setMethod(o.dataset.method); }); });
input.addEventListener("input", function () { if (method === "phone") input.value = formatPhone(input.value); });

document.getElementById("form").addEventListener("submit", function (e) {
  e.preventDefault();
  var errors = {};
  if (method === "email" && !isValidEmail(input.value)) errors.contact = "Informe um e-mail válido.";
  if (method === "phone" && !isValidPhone(input.value)) errors.contact = "Informe um celular válido.";
  if (!showErrors(errors, ["contact"])) return;

  var button = e.target.querySelector('button[type="submit"]');
  if (button) button.disabled = true;

  AuthService.recuperarConta({ metodo: method, valor: input.value.trim() }).then(function (r) {
    if (button) button.disabled = false;
    if (!r.ok) { showToast(r.message); return; }
    var found = r.data && r.data.found;
    if (!found) {
      // Mesma resposta para conta inexistente, para não revelar cadastros.
      showToast(r.data && r.data.message ? r.data.message : "Se os dados estiverem cadastrados, você receberá as instruções.");
      return;
    }
    var email = r.data.masked_email || "";
    showToast("Conta encontrada. Defina uma nova senha na próxima tela.");
    setTimeout(function () {
      window.location.href = "esqueci-senha.html" + (method === "email" ? "?email=" + encodeURIComponent(input.value.trim()) : "");
    }, 1200);
  });
});
