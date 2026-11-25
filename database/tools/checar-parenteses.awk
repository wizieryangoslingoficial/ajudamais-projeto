# Rastreia profundidade de parênteses por statement SQL, ignorando strings
# ('...' com '' escapado) e comentários "--". Uso:
#   awk -f database/tools/checar-parenteses.awk database/parts/*.sql
{
  n = length($0); i = 1; insq = 0
  while (i <= n) {
    c = substr($0, i, 1)
    if (insq) {
      if (c == "\047") {
        if (substr($0, i+1, 1) == "\047") { i += 2; continue }
        insq = 0
      }
      i++; continue
    }
    if (c == "\047") { insq = 1; i++; continue }
    if (c == "-" && substr($0, i+1, 1) == "-") break
    if (c == "(") depth++
    else if (c == ")") depth--
    i++
  }
  if ($0 ~ /;[[:space:]]*$/) {
    if (depth != 0) printf "LINHA %d: saldo %d -> %s\n", FNR, depth, substr($0, 1, 50)
    depth = 0
  }
}
