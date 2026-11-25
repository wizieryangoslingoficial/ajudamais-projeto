// Tela de acesso (termos e escolha de entrada: Entrar, Criar conta ou Doação anônima)
var checkbox = document.getElementById("terms-checkbox");
var buttons = ["btn-login", "btn-signup", "btn-anonymous"].map(function (id) { return document.getElementById(id); });

function update() { buttons.forEach(function (b) { if (b) b.disabled = !checkbox.checked; }); }

if (new URLSearchParams(location.search).get("aceito") === "1") checkbox.checked = true;
update();
checkbox.addEventListener("change", update);

document.getElementById("btn-login").addEventListener("click", function () { location.href = "login.html"; });
document.getElementById("btn-signup").addEventListener("click", function () { location.href = "cadastro.html"; });
document.getElementById("btn-anonymous").addEventListener("click", function () {
  localStorage.setItem("ajudamais_modo", "anonimo");
  location.href = "index.html";
});
