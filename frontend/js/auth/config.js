// Configuração da API do AjudaMais (Backend Node.js + Express).
// O site é servido pelo próprio Express, então a mesma origem já contém /api.
// Ao abrir os HTML direto no VS Code (Live Server), use http://localhost:3000/api.
var AJUDAMAIS_CONFIG = {
  apiBaseUrl: (function () {
    var origin = window.location.origin;
    var isHttp = origin && (origin.indexOf("http://") === 0 || origin.indexOf("https://") === 0);
    // Live Server (porta 5500) e file:// apontam para o backend local.
    if (!isHttp || /:(5500|5501|8080)$/.test(origin)) return "http://localhost:3000/api";
    if (window.AJUDAMAIS_API_BASE) return window.AJUDAMAIS_API_BASE;
    return origin + "/api";
  })()
};
