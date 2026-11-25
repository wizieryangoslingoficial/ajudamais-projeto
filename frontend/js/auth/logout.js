// Botão Sair: qualquer elemento com data-logout ou data-action="logout" encerra a sessão.
document.addEventListener("click", function (e) {
  var btn = e.target.closest('[data-logout], [data-action="logout"]');
  if (!btn) return;
  e.preventDefault();
  AuthService.sair().then(function () {
    window.location.href = "acesso.html";
  });
});
