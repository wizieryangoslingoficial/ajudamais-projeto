// Aviso temporário na parte de baixo da tela.
var toastTimers = [];
function showToast(text) {
  var el = document.getElementById("toast");
  toastTimers.forEach(clearTimeout);
  toastTimers = [];
  el.textContent = text;
  el.hidden = false;
  requestAnimationFrame(function () { el.classList.add("toast--visible"); });
  toastTimers.push(setTimeout(function () {
    el.classList.remove("toast--visible");
    toastTimers.push(setTimeout(function () { el.hidden = true; }, 250));
  }, 3000));
}
