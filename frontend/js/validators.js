// Regras de validação usadas pelos formulários (CPF, e-mail, celular, senha).
// O backend exige 8 caracteres; o formulário segue a mesma regra.
var MIN_PASSWORD_LENGTH = 8;

function onlyDigits(v) { return v.replace(/\D/g, ""); }

// Máscara 000.000.000-00
function formatCpf(value) {
  var d = onlyDigits(value).slice(0, 11);
  return d.replace(/^(\d{3})(\d)/, "$1.$2")
          .replace(/^(\d{3})\.(\d{3})(\d)/, "$1.$2.$3")
          .replace(/\.(\d{3})(\d{1,2})$/, ".$1-$2");
}

// Valida CPF pelos dígitos verificadores
function isValidCpf(value) {
  var d = onlyDigits(value);
  if (d.length !== 11 || /^(\d)\1{10}$/.test(d)) return false;
  function calc(len) {
    var sum = 0;
    for (var i = 0; i < len; i++) sum += Number(d[i]) * (len + 1 - i);
    var r = (sum * 10) % 11;
    return r === 10 ? 0 : r;
  }
  return calc(9) === Number(d[9]) && calc(10) === Number(d[10]);
}

// Máscara (00) 00000-0000
function formatPhone(value) {
  var d = onlyDigits(value).slice(0, 11);
  if (d.length <= 2) return d.length ? "(" + d : "";
  if (d.length <= 7) return "(" + d.slice(0, 2) + ") " + d.slice(2);
  return "(" + d.slice(0, 2) + ") " + d.slice(2, 7) + "-" + d.slice(7);
}

function isValidPhone(value) { return onlyDigits(value).length === 11; }
function isValidEmail(value) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value); }

// Login aceita CPF (preferido) ou e-mail quando o CPF estiver vazio.
function validateLogin(data) {
  var e = {};
  if (!data.cpf && !data.email) e.cpf = "Informe seu CPF ou e-mail.";
  else if (data.cpf && !isValidCpf(data.cpf)) e.cpf = "Informe um CPF válido.";
  else if (!data.cpf && data.email && !isValidEmail(data.email)) e.email = "Informe um e-mail válido.";
  if (!data.password) e.password = "Informe sua senha.";
  return e;
}

function validateSignup(d) {
  var e = {};
  if (!d.name.trim()) e.name = "Informe seu nome completo.";
  if (!isValidEmail(d.email)) e.email = "Informe um e-mail válido.";
  if (!isValidCpf(d.cpf)) e.cpf = "Informe um CPF válido.";
  if (!d.phone || !isValidPhone(d.phone)) e.phone = "Informe um telefone celular válido com DDD.";
  if (d.password.length < MIN_PASSWORD_LENGTH) e.password = "A senha precisa ter no mínimo " + MIN_PASSWORD_LENGTH + " caracteres.";
  if (d.confirm !== d.password) e.confirm = "As senhas não coincidem.";
  return e;
}
