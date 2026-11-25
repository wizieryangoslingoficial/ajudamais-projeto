// Funções comuns dos campos: mostrar/ocultar senha, máscara de CPF e erros.
document.querySelectorAll("[data-toggle]").forEach(function (btn) {
  btn.addEventListener("click", function () {
    var input = document.getElementById(btn.dataset.toggle);
    var show = input.type === "password";
    input.type = show ? "text" : "password";
    btn.setAttribute("aria-label", show ? "Ocultar senha" : "Mostrar senha");
    btn.querySelector(".eye-off").style.display = show ? "" : "none";
  });
});

var cpfInput = document.getElementById("cpf");
if (cpfInput) cpfInput.addEventListener("input", function () { cpfInput.value = formatCpf(cpfInput.value); });

function showErrors(errors, ids) {
  ids.forEach(function (id) {
    var input = document.getElementById(id);
    var msg = document.getElementById(id + "-error");
    if (errors[id]) {
      msg.textContent = errors[id];
      msg.hidden = false;
      input.setAttribute("aria-invalid", "true");
    } else {
      msg.hidden = true;
      input.removeAttribute("aria-invalid");
    }
  });
  return Object.keys(errors).length === 0;
}

function value(id) { return document.getElementById(id).value; }
