const icons = {
  heart: '<path d="M20.8 8.7c0 5.4-8.8 10.4-8.8 10.4S3.2 14.1 3.2 8.7A4.7 4.7 0 0 1 12 6.5a4.7 4.7 0 0 1 8.8 2.2Z"/>',
  home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v6H9v6H4a1 1 0 0 1-1-1V10Z"/>',
  dollar: '<path d="M12 2v20M17 6.5c-.8-.9-2.3-1.5-4.2-1.5-2.7 0-4.3 1.2-4.3 3s1.4 2.7 4.4 3.5c3 .8 4.4 1.8 4.4 3.7s-1.7 3.2-4.6 3.2c-2 0-3.6-.6-4.7-1.8"/>',
  box: '<path d="m21 8-9-5-9 5 9 5 9-5ZM3 8v8l9 5 9-5V8M12 13v8"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
  logout: '<path d="M10 17l5-5-5-5M15 12H3M21 19V5a2 2 0 0 0-2-2h-6"/>',
  user: '<circle cx="12" cy="8" r="3.5"/><path d="M5 21a7 7 0 0 1 14 0"/>',
  trend: '<path d="m3 17 6-6 4 4 8-9M15 6h6v6"/>',
  shield: '<path d="M12 3 5 6v5c0 4.4 2.9 8.4 7 10 4.1-1.6 7-5.6 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/>',
  zap: '<path d="m13 2-9 12h7l-1 8 9-12h-7l1-8Z"/>',
  arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  chat: '<path d="M20 11.5a7.5 7.5 0 0 1-8 7.5 8.3 8.3 0 0 1-3.5-.8L4 20l1.4-3.7A7.1 7.1 0 0 1 4.5 12 7.5 7.5 0 0 1 12 4.5a7.5 7.5 0 0 1 8 7Z"/>',
  close: '<path d="m6 6 12 12M18 6 6 18"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  card: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/>',
  transfer: '<path d="M4 14h16M4 10h16M7 6l5-4 5 4M17 18l-5 4-5-4"/>',
  pix: '<rect x="6" y="3" width="12" height="18" rx="2"/><path d="M12 17v.01"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  food: '<path d="M18 2v6a3 3 0 0 1-3 3h-3v7a2 2 0 0 1-2 2h0a2 2 0 0 1-2-2v-7H5a3 3 0 0 1-3-3V2h2v4h1V2h2v4h1V2h2v4h1V2h2v4h1V2h2z"/>',
  clothes: '<path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/><path d="M9 2v4a3 3 0 0 0 6 0V2"/>',
  bed: '<path d="M2 4v16M2 8h18a2 2 0 0 1 2 2v10M2 17h20M6 8v9"/>',
  hygiene: '<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  minus: '<path d="M5 12h14"/>',
  mapPin: '<path d="M12 2a7 7 0 0 0-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 0 0-7-7z"/><circle cx="12" cy="9" r="2.5"/>',
}

function icon(name, className = '') {
  return `<svg class="icon ${className}" viewBox="0 0 24 24" aria-hidden="true">${icons[name] || ''}</svg>`
}

const fallbackDonations = []

function formatNumber(n) {
  return Number(n || 0).toLocaleString('pt-BR')
}

function formatMoney(n) {
  if (n == null) return '—'
  return 'R$ ' + Number(n).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function timeAgo(iso) {
  if (!iso) return 'Recente'
  const ms = Date.now() - new Date(iso).getTime()
  const min = Math.floor(ms / 60000)
  if (min < 1) return 'agora'
  if (min < 60) return `${min} min atrás`
  const h = Math.floor(min / 60)
  if (h < 24) return `${h} hora${h > 1 ? 's' : ''} atrás`
  const d = Math.floor(h / 24)
  return `${d} dia${d > 1 ? 's' : ''} atrás`
}

function renderDonationRows(list) {
  if (!list || !list.length) {
    return '<p style="font-size:13px;color:#667085;padding:8px 0;">Nenhuma doação confirmada ainda. A primeira pode ser a sua!</p>'
  }
  return list.map((donation) => `
    <article class="donation-row">
      <div class="donor-avatar" aria-hidden="true">${donation.initials || (donation.name ? donation.name[0].toUpperCase() : 'D')}</div>
      <div class="donation-info">
        <strong>${donation.name || 'Doador'}</strong>
        <span>${donation.detail || donation.descricao || ''}</span>
      </div>
      <time>${donation.time || 'Recente'}</time>
    </article>
  `).join('')
}

let activeSection = 'Início'
let selectedAmount = 0
let selectedPayment = 'card'
let donationSuccess = false
let successData = null

// Doar Itens State - All counters start at 0
let itemCategory = 'Alimentos'
let itemCounts = {
  // Alimentos
  'Arroz': 0,
  'Feijão': 0,
  'Macarrão': 0,
  'Óleo': 0,
  'Açúcar': 0,
  'Leite': 0,
  'Café': 0,
  'Enlatados': 0,
  // Roupas
  'Camisetas': 0,
  'Calças': 0,
  'Jaquetas': 0,
  'Sapatos': 0,
  'Meias': 0,
  'Roupas Infantis': 0,
  // Cobertores e Cama
  'Cobertores': 0,
  'Lençóis': 0,
  'Travesseiros': 0,
  'Edredons': 0,
  'Toalhas': 0,
  // Higiene
  'Sabonete': 0,
  'Shampoo': 0,
  'Pasta de dente': 0,
  'Escova de dente': 0,
  'Papel higiênico': 0,
  'Fraldas': 0
}

let itemSuccess = false
let itemSuccessData = null

// Necessidades State
let necessidadesFilter = 'todas' // 'todas', 'urgentes', 'verificadas'

// Preenchida com os dados reais de GET /api/requests (nada fixo).
let necessidadesList = []
let stats = null
let minhasDoacoes = []
let minhasSolicitacoes = []
let meusEnderecos = []
let recentDonations = null
let pendingRequestId = null
let pendingNeedTitle = ''
let categories = []

// Nome da categoria no formulário -> slug da tabela item_categories.
const CATEGORY_ALIASES = {
  'Alimentos': 'alimentos',
  'Roupas': 'roupas',
  'Cobertores e Cama': 'roupas',
  'Higiene': 'higiene'
}

function categoryIdFor(formCategory) {
  const slug = CATEGORY_ALIASES[formCategory]
  const found = categories.find((c) => c.slug === slug)
  return found ? found.id : undefined
}

// ---- Rascunho por aba ----------------------------------------------------
// Guarda o que foi digitado em cada aba, para os campos não se perderem ao
// alternar entre elas. Os valores nunca são enviados sem o usuário clicar.
const rascunhos = {}
const CAMPOS_FORMULARIO = '#app input, #app textarea, #app select'

function guardarRascunho(secao) {
  if (!secao) return
  const valores = {}
  document.querySelectorAll(CAMPOS_FORMULARIO).forEach((el) => {
    if (!el.id || el.type === 'hidden') return
    valores[el.id] = el.type === 'checkbox' ? el.checked : el.value
  })
  rascunhos[secao] = valores
}

function limparRascunho(secao) {
  delete rascunhos[secao]
}

function restaurarRascunho(secao) {
  const valores = rascunhos[secao]
  if (!valores) return
  Object.keys(valores).forEach((id) => {
    const el = document.getElementById(id)
    if (!el) return
    if (el.type === 'checkbox') el.checked = valores[id]
    else el.value = valores[id]
  })
}

function renderApp(usuario) {
  const userName = usuario && usuario.nome ? usuario.nome : 'Visitante'
  const userInitial = userName.charAt(0).toUpperCase()
  const authButtons = usuario
    ? `
      <button class="profile-button" type="button" data-action="profile" aria-label="Abrir perfil de ${userName}">
        <span class="profile-avatar">${userInitial}</span>
        <span>${userName}</span>
        ${icon('user', 'profile-icon')}
      </button>
      <button class="logout-button" type="button" data-action="logout" data-logout>
        ${icon('logout')}
        <span>Sair</span>
      </button>
    `
    : `
      <a class="profile-button" href="acesso.html" style="text-decoration:none;">
        <span class="profile-avatar">E</span>
        <span>Entrar / Cadastrar</span>
        ${icon('user', 'profile-icon')}
      </a>
    `

  const headerHtml = `
    <header class="site-header">
      <div class="header-inner">
        <a class="brand" href="index.html" aria-label="AjudaMais, voltar ao início">
          <span class="brand-mark">${icon('heart')}</span>
          <span class="brand-copy">
            <strong>AjudaMais</strong>
            <small>Conectando corações, transformando vidas</small>
          </span>
        </a>

        <div class="header-actions">
          ${authButtons}
          <button class="menu-toggle" type="button" aria-label="Abrir menu" aria-expanded="false">
            ${icon('menu')}
          </button>
        </div>
      </div>
    </header>
  `

  const navHtml = `
    <nav class="dashboard-nav" aria-label="Navegação principal">
      <button class="nav-link ${activeSection === 'Início' ? 'is-active' : ''}" type="button" data-section="Início">
        ${icon('home')}
        <span>Início</span>
      </button>
      <button class="nav-link ${activeSection === 'Doar Dinheiro' ? 'is-active' : ''}" type="button" data-section="Doar Dinheiro">
        ${icon('dollar')}
        <span>Doar Dinheiro</span>
      </button>
      <button class="nav-link ${activeSection === 'Doar Itens' ? 'is-active' : ''}" type="button" data-section="Doar Itens">
        ${icon('box')}
        <span>Doar Itens</span>
      </button>
      <button class="nav-link ${activeSection === 'Necessidades' ? 'is-active' : ''}" type="button" data-section="Necessidades">
        ${icon('users')}
        <span>Necessidades</span>
      </button>
      <button class="nav-link ${activeSection === 'Doações' ? 'is-active' : ''}" type="button" data-section="Doações">
        ${icon('heart')}
        <span>Minhas Doações</span>
      </button>
      <button class="nav-link ${activeSection === 'Solicitações' ? 'is-active' : ''}" type="button" data-section="Solicitações">
        ${icon('zap')}
        <span>Solicitações</span>
      </button>
      <button class="nav-link ${activeSection === 'Perfil' ? 'is-active' : ''}" type="button" data-section="Perfil">
        ${icon('user')}
        <span>Perfil</span>
      </button>
    </nav>
  `

  let mainContent = ''

  if (activeSection === 'Início') {
    mainContent = `
      <section class="welcome-banner" aria-labelledby="welcome-title">
        <h1 id="welcome-title">Bem-vindo ao AjudaMais${usuario ? ', ' + userName.split(' ')[0] : ''}!</h1>
        <p>Sua generosidade transforma vidas. Veja o impacto que estamos fazendo juntos.</p>
      </section>

      <section class="stats-grid" aria-label="Resumo do impacto">
        <article class="stat-card">
          <div class="stat-icon stat-icon-green">${icon('dollar')}</div>
          <span class="stat-label">Doações em Dinheiro</span>
          <strong class="stat-value">${formatMoney(stats ? stats.money_total : null)}</strong>
          <span class="stat-change">${stats ? stats.money_count + ' doação(ões) confirmada(s)' : 'Carregando...'}</span>
        </article>
        <article class="stat-card">
          <div class="stat-icon stat-icon-blue">${icon('box')}</div>
          <span class="stat-label">Itens Doados</span>
          <strong class="stat-value">${stats ? formatNumber(stats.items_total) : '—'}</strong>
          <span class="stat-change">${stats ? stats.items_donations + ' doação(ões) de itens' : 'Carregando...'}</span>
        </article>
        <article class="stat-card">
          <div class="stat-icon stat-icon-pink">${icon('users')}</div>
          <span class="stat-label">Pessoas Ajudadas</span>
          <strong class="stat-value">${stats ? formatNumber(stats.people_helped) : '—'}</strong>
          <span class="stat-change">${stats ? stats.open_needs + ' necessidades abertas' : 'Carregando...'}</span>
        </article>
        <article class="stat-card">
          <div class="stat-icon stat-icon-orange">${icon('trend')}</div>
          <span class="stat-label">Impacto Total</span>
          <strong class="stat-value">${stats ? formatNumber(stats.donors) : '—'}</strong>
          <span class="stat-change">${stats ? stats.institutions + ' instituição(ões) verificada(s)' : 'Carregando...'}</span>
        </article>
      </section>

      <section class="content-card donations-card" aria-labelledby="donations-title">
        <div class="section-heading">
          <h2 id="donations-title">Doações Recentes</h2>
        </div>
        <div class="donation-list" id="donation-list">${renderDonationRows(recentDonations || [])}</div>
      </section>

      <section class="difference-banner" aria-labelledby="difference-title">
        <div>
          <h2 id="difference-title">Faça a Diferença Hoje!</h2>
          <p>Cada doação, seja em dinheiro ou itens, ajuda a transformar a vida de alguém que precisa.</p>
        </div>
        <button class="primary-button" type="button" data-action="goto-donate">
          Doar Agora
          ${icon('arrow')}
        </button>
      </section>

      <section class="content-card how-card" aria-labelledby="how-title">
        <div class="section-heading">
          <h2 id="how-title">Como funciona o AjudaMais</h2>
        </div>
        <div class="how-grid">
          <article class="how-item">
            <div class="how-icon how-icon-blue">${icon('heart')}</div>
            <h3>Escolha como ajudar</h3>
            <p>Doe dinheiro via Pix ou transferência, ou selecione itens como alimentos, roupas e cobertores para enviar diretamente a quem precisa.</p>
          </article>
          <article class="how-item">
            <div class="how-icon how-icon-purple">${icon('shield')}</div>
            <h3>Verificação segura</h3>
            <p>Os dados dos beneficiários são verificados via Gov.br, garantindo que as doações cheguem a pessoas realmente em situação de vulnerabilidade.</p>
          </article>
          <article class="how-item">
            <div class="how-icon how-icon-green">${icon('zap')}</div>
            <h3>Impacto direto</h3>
            <p>Sem intermediários desnecessários. Sua doação vai direto para a pessoa indicada — você pode acompanhar o status em tempo real.</p>
          </article>
        </div>
      </section>
    `
  } else if (activeSection === 'Doar Dinheiro') {
    if (donationSuccess) {
      mainContent = `
        <div class="content-card" style="padding: 40px; text-align: center; margin-top: 25px;">
          <div style="width: 64px; height: 64px; background: #e6f9f0; color: #007d4b; border-radius: 50%; display: grid; place-items: center; margin: 0 auto 20px;">
            ${icon('check')}
          </div>
          <h2 style="font-size: 24px; color: #172033; margin-bottom: 16px;">Doação aprovada com sucesso! ❤️</h2>
          <p style="font-size: 15px; line-height: 1.6; color: #45536b; max-width: 600px; margin: 0 auto 24px;">
            Agradecemos imensamente pela sua contribuição! Sua generosidade faz a diferença e ajuda a transformar vidas. Obrigado por fazer parte dessa iniciativa!
          </p>
          <div style="background: #f6f8ff; padding: 16px; border-radius: 12px; max-width: 400px; margin: 0 auto 24px; text-align: left; font-size: 13px; color: #344056;">
            <p><strong>Valor doado:</strong> R$ ${successData.amount.toFixed(2).replace('.', ',')}</p>
            <p><strong>Doador:</strong> ${successData.name}</p>
            <p><strong>Método:</strong> ${successData.paymentMethod === 'card' ? 'Cartão de Crédito' : successData.paymentMethod === 'transfer' ? 'Transferência Bancária' : 'PIX'}</p>
          </div>
          <p style="font-size: 16px; font-weight: 600; color: #007d4b; margin-bottom: 24px;">Sua doação faz a diferença!</p>
          <button class="primary-button" type="button" id="btn-new-donation" style="margin: 0 auto; background: #3154f4; color: #fff;">Fazer Nova Doação</button>
        </div>
      `
    } else {
      mainContent = `
        <div class="content-card" style="margin-top: 25px; overflow: hidden;">
          <div style="background: #007d4b; color: #fff; padding: 28px 32px;">
            <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 8px;">
              ${icon('dollar', '')}
              <h2 style="font-size: 22px; font-weight: 700; margin: 0;">Doar Dinheiro</h2>
            </div>
            <p style="font-size: 14px; margin: 0;">Sua contribuição financeira permite comprar itens essenciais e ajudar quem mais precisa.</p>
          </div>

          <form id="donation-form" style="padding: 32px;" novalidate>
            <div style="margin-bottom: 28px;">
              <label style="display: block; font-weight: 600; font-size: 14px; color: #172033; margin-bottom: 12px;">Escolha o valor da doação</label>
              <div style="display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; margin-bottom: 16px;" class="preset-grid">
                <button type="button" class="preset-btn ${selectedAmount === 20 ? 'is-selected' : ''}" data-val="20" style="padding: 12px; border: 1px solid #dfe6f0; border-radius: 10px; background: ${selectedAmount === 20 ? '#f2f5ff' : '#fff'}; color: ${selectedAmount === 20 ? '#3154f4' : '#172033'}; font-weight: 600; cursor: pointer;">R$ 20</button>
                <button type="button" class="preset-btn ${selectedAmount === 50 ? 'is-selected' : ''}" data-val="50" style="padding: 12px; border: 1px solid #dfe6f0; border-radius: 10px; background: ${selectedAmount === 50 ? '#f2f5ff' : '#fff'}; color: ${selectedAmount === 50 ? '#3154f4' : '#172033'}; font-weight: 600; cursor: pointer;">R$ 50</button>
                <button type="button" class="preset-btn ${selectedAmount === 100 ? 'is-selected' : ''}" data-val="100" style="padding: 12px; border: 1px solid #dfe6f0; border-radius: 10px; background: ${selectedAmount === 100 ? '#f2f5ff' : '#fff'}; color: ${selectedAmount === 100 ? '#3154f4' : '#172033'}; font-weight: 600; cursor: pointer;">R$ 100</button>
                <button type="button" class="preset-btn ${selectedAmount === 200 ? 'is-selected' : ''}" data-val="200" style="padding: 12px; border: 1px solid #dfe6f0; border-radius: 10px; background: ${selectedAmount === 200 ? '#f2f5ff' : '#fff'}; color: ${selectedAmount === 200 ? '#3154f4' : '#172033'}; font-weight: 600; cursor: pointer;">R$ 200</button>
                <button type="button" class="preset-btn ${selectedAmount === 500 ? 'is-selected' : ''}" data-val="500" style="padding: 12px; border: 1px solid #dfe6f0; border-radius: 10px; background: ${selectedAmount === 500 ? '#f2f5ff' : '#fff'}; color: ${selectedAmount === 500 ? '#3154f4' : '#172033'}; font-weight: 600; cursor: pointer;">R$ 500</button>
              </div>
              <label for="custom-amount" style="display: block; font-size: 13px; color: #45536b; margin-bottom: 8px;">Ou digite outro valor:</label>
              <input type="text" id="custom-amount" placeholder="R$ 0,00" value="${selectedAmount ? 'R$ ' + selectedAmount.toFixed(2).replace('.', ',') : ''}" style="width: 100%; height: 46px; padding: 0 16px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 15px;">
            </div>

            <div style="margin-bottom: 28px;">
              <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 16px; color: #007d4b;">
                ${icon('shield')}
                <h3 style="font-size: 15px; font-weight: 600; margin: 0;">Informações do Doador</h3>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px;" class="form-grid">
                <div>
                  <label for="donor-name" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">Nome Completo *</label>
                  <input type="text" id="donor-name" required value="${usuario && usuario.nome ? usuario.nome : ''}" placeholder="Seu nome completo" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
                <div>
                  <label for="donor-cpf" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">CPF *</label>
                  <input type="text" id="donor-cpf" required value="${usuario && usuario.cpf ? usuario.cpf : ''}" placeholder="000.000.000-00" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px;" class="form-grid">
                <div>
                  <label for="donor-email" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">E-mail *</label>
                  <input type="email" id="donor-email" required value="${usuario && usuario.email ? usuario.email : ''}" placeholder="seu@email.com" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
                <div>
                  <label for="donor-phone" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">Telefone *</label>
                  <input type="text" id="donor-phone" required value="${usuario && usuario.telefone ? usuario.telefone : ''}" placeholder="(00) 00000-0000" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
              </div>
              <div style="background: #f2f5ff; border: 1px solid #dce5ff; padding: 12px 16px; border-radius: 10px; font-size: 12px; color: #3154f4; display: flex; align-items: center; gap: 10px;">
                ${icon('shield')}
                <span>Seus dados serão verificados automaticamente para garantir a segurança da transação.</span>
              </div>
            </div>

            <div style="margin-bottom: 32px;">
              <label style="display: block; font-weight: 600; font-size: 14px; color: #172033; margin-bottom: 12px;">Método de Pagamento</label>
              <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px;" class="pay-grid">
                <button type="button" class="pay-btn ${selectedPayment === 'card' ? 'is-selected' : ''}" data-pay="card" style="padding: 20px 16px; border: 2px solid ${selectedPayment === 'card' ? '#007d4b' : '#dfe6f0'}; border-radius: 12px; background: #fff; cursor: pointer; text-align: center;">
                  <div style="color: #007d4b; margin-bottom: 8px; display: grid; place-items: center;">${icon('card')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">Cartão de Crédito</span>
                </button>
                <button type="button" class="pay-btn ${selectedPayment === 'transfer' ? 'is-selected' : ''}" data-pay="transfer" style="padding: 20px 16px; border: 2px solid ${selectedPayment === 'transfer' ? '#007d4b' : '#dfe6f0'}; border-radius: 12px; background: #fff; cursor: pointer; text-align: center;">
                  <div style="color: #007d4b; margin-bottom: 8px; display: grid; place-items: center;">${icon('transfer')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">Transferência</span>
                </button>
                <button type="button" class="pay-btn ${selectedPayment === 'pix' ? 'is-selected' : ''}" data-pay="pix" style="padding: 20px 16px; border: 2px solid ${selectedPayment === 'pix' ? '#007d4b' : '#dfe6f0'}; border-radius: 12px; background: #fff; cursor: pointer; text-align: center;">
                  <div style="color: #007d4b; margin-bottom: 8px; display: grid; place-items: center;">${icon('pix')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">PIX</span>
                </button>
              </div>
            </div>

            <div style="display: flex; align-items: center; justify-content: space-between; padding-top: 20px; border-top: 1px solid #dfe6f0; flex-wrap: wrap; gap: 16px;">
              <div>
                <span style="font-size: 13px; color: #45536b; display: block;">Total a doar:</span>
                <strong style="font-size: 24px; color: #007d4b; font-weight: 700;">R$ ${selectedAmount.toFixed(2).replace('.', ',')}</strong>
              </div>
              <button type="submit" style="background: #007d4b; color: #fff; border: 0; padding: 0 32px; height: 50px; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer; box-shadow: 0 4px 12px rgba(0, 169, 101, 0.25);">Confirmar Doação</button>
            </div>
            <p style="text-align: center; font-size: 11px; color: #667085; margin-top: 16px;">Ao confirmar, você concorda com nossos termos de uso e política de privacidade.</p>
          </form>
        </div>
      `
    }
  } else if (activeSection === 'Doar Itens') {
    if (itemSuccess) {
      mainContent = `
        <div class="content-card" style="padding: 40px; text-align: center; margin-top: 25px;">
          <div style="width: 64px; height: 64px; background: #e6f9f0; color: #007d4b; border-radius: 50%; display: grid; place-items: center; margin: 0 auto 20px;">
            ${icon('check')}
          </div>
          <h2 style="font-size: 24px; color: #172033; margin-bottom: 16px;">Doação de Itens Agendada com Sucesso! 📦</h2>
          <p style="font-size: 15px; line-height: 1.6; color: #45536b; max-width: 600px; margin: 0 auto 24px;">
            Agradecemos imensamente pela sua generosidade! Entraremos em contato em até 24 horas para agendar a coleta dos itens no endereço informado.
          </p>
          <div style="background: #f6f8ff; padding: 16px; border-radius: 12px; max-width: 450px; margin: 0 auto 24px; text-align: left; font-size: 13px; color: #344056;">
            <p><strong>Doador:</strong> ${itemSuccessData.name}</p>
            <p><strong>Endereço:</strong> ${itemSuccessData.address}, ${itemSuccessData.city}</p>
            <p><strong>Total de itens:</strong> ${itemSuccessData.totalCount} unidades</p>
          </div>
          <p style="font-size: 16px; font-weight: 600; color: #3154f4; margin-bottom: 24px;">Sua doação faz toda a diferença!</p>
          <button class="primary-button" type="button" id="btn-new-item-donation" style="margin: 0 auto; background: #3154f4; color: #fff;">Fazer Nova Doação de Itens</button>
        </div>
      `
    } else {
      const catItems = {
        'Alimentos': ['Arroz', 'Feijão', 'Macarrão', 'Óleo', 'Açúcar', 'Leite', 'Café', 'Enlatados'],
        'Roupas': ['Camisetas', 'Calças', 'Jaquetas', 'Sapatos', 'Meias', 'Roupas Infantis'],
        'Cobertores e Cama': ['Cobertores', 'Lençóis', 'Travesseiros', 'Edredons', 'Toalhas'],
        'Higiene': ['Sabonete', 'Shampoo', 'Pasta de dente', 'Escova de dente', 'Papel higiênico', 'Fraldas']
      }

      const currentItemsList = catItems[itemCategory] || []
      
      let totalItems = 0
      let summaryRows = []
      Object.keys(itemCounts).forEach(k => {
        let cnt = itemCounts[k]
        if (cnt > 0) {
          totalItems += cnt
          summaryRows.push(`<div style="display: flex; justify-content: space-between; font-size: 13px; color: #45536b; padding: 4px 0;"><span>${k}</span><span>${cnt} unidade${cnt > 1 ? 's' : ''}</span></div>`)
        }
      })

      mainContent = `
        <div class="content-card" style="margin-top: 25px; overflow: hidden;">
          <div style="background: #3154f4; color: #fff; padding: 28px 32px;">
            <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 8px;">
              ${icon('box', '')}
              <h2 style="font-size: 22px; font-weight: 700; margin: 0;">Doar Itens</h2>
            </div>
            <p style="font-size: 14px; margin: 0;">Doe itens essenciais como alimentos, roupas, cobertores e produtos de higiene.</p>
          </div>

          <div style="padding: 32px;">
            <div style="margin-bottom: 28px;">
              <label style="display: block; font-weight: 600; font-size: 14px; color: #172033; margin-bottom: 12px;">Selecione a categoria</label>
              <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px;" class="item-cat-grid">
                <button type="button" class="item-cat-btn ${itemCategory === 'Alimentos' ? 'is-selected' : ''}" data-cat="Alimentos" style="padding: 20px 12px; border: 2px solid ${itemCategory === 'Alimentos' ? '#3154f4' : '#dfe6f0'}; border-radius: 12px; background: ${itemCategory === 'Alimentos' ? '#f2f5ff' : '#fff'}; cursor: pointer; text-align: center;">
                  <div style="color: #ff6f0b; margin-bottom: 8px; display: grid; place-items: center;">${icon('food')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">Alimentos</span>
                </button>
                <button type="button" class="item-cat-btn ${itemCategory === 'Roupas' ? 'is-selected' : ''}" data-cat="Roupas" style="padding: 20px 12px; border: 2px solid ${itemCategory === 'Roupas' ? '#3154f4' : '#dfe6f0'}; border-radius: 12px; background: ${itemCategory === 'Roupas' ? '#f2f5ff' : '#fff'}; cursor: pointer; text-align: center;">
                  <div style="color: #3154f4; margin-bottom: 8px; display: grid; place-items: center;">${icon('clothes')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">Roupas</span>
                </button>
                <button type="button" class="item-cat-btn ${itemCategory === 'Cobertores e Cama' ? 'is-selected' : ''}" data-cat="Cobertores e Cama" style="padding: 20px 12px; border: 2px solid ${itemCategory === 'Cobertores e Cama' ? '#3154f4' : '#dfe6f0'}; border-radius: 12px; background: ${itemCategory === 'Cobertores e Cama' ? '#f2f5ff' : '#fff'}; cursor: pointer; text-align: center;">
                  <div style="color: #a338ef; margin-bottom: 8px; display: grid; place-items: center;">${icon('bed')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">Cobertores e Cama</span>
                </button>
                <button type="button" class="item-cat-btn ${itemCategory === 'Higiene' ? 'is-selected' : ''}" data-cat="Higiene" style="padding: 20px 12px; border: 2px solid ${itemCategory === 'Higiene' ? '#3154f4' : '#dfe6f0'}; border-radius: 12px; background: ${itemCategory === 'Higiene' ? '#f2f5ff' : '#fff'}; cursor: pointer; text-align: center;">
                  <div style="color: #0abf68; margin-bottom: 8px; display: grid; place-items: center;">${icon('hygiene')}</div>
                  <span style="font-size: 13px; font-weight: 600; color: #172033;">Higiene</span>
                </button>
              </div>
            </div>

            <div style="margin-bottom: 28px; background: #fafbfd; border: 1px solid #e3e9f2; border-radius: 12px; padding: 20px;">
              <h3 style="font-size: 15px; font-weight: 600; color: #172033; margin-bottom: 16px;">Itens de ${itemCategory}</h3>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;" class="item-counter-grid">
                ${currentItemsList.map(itemName => `
                  <div style="background: #fff; border: 1px solid #dfe6f0; border-radius: 10px; padding: 12px 16px; display: flex; align-items: center; justify-content: space-between;">
                    <span style="font-size: 14px; font-weight: 500; color: #172033;">${itemName}</span>
                    <div style="display: flex; align-items: center; gap: 12px;">
                      <button type="button" class="item-minus-btn" data-item="${itemName}" style="width: 30px; height: 30px; border-radius: 50%; background: #f2f5ff; color: #3154f4; display: grid; place-items: center; cursor: pointer; border: 0;">${icon('minus')}</button>
                      <span style="font-size: 15px; font-weight: 600; min-width: 20px; text-align: center;">${itemCounts[itemName] || 0}</span>
                      <button type="button" class="item-plus-btn" data-item="${itemName}" style="width: 30px; height: 30px; border-radius: 50%; background: #3154f4; color: #fff; display: grid; place-items: center; cursor: pointer; border: 0;">${icon('plus')}</button>
                    </div>
                  </div>
                `).join('')}
              </div>
            </div>

            <div style="margin-bottom: 28px; background: #f2f5ff; border: 1px solid #dce5ff; border-radius: 12px; padding: 20px;">
              <h3 style="font-size: 15px; font-weight: 600; color: #3154f4; margin-bottom: 12px;">Resumo da Doação</h3>
              <div style="min-height: 40px; margin-bottom: 12px;">
                ${summaryRows.length > 0 ? summaryRows.join('') : '<span style="font-size: 13px; color: #667085;">Nenhum item selecionado ainda.</span>'}
              </div>
              <div style="border-top: 1px solid #dce5ff; padding-top: 12px; display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 14px; font-weight: 600; color: #172033;">Total de itens:</span>
                <strong style="font-size: 16px; font-weight: 700; color: #3154f4;">${totalItems}</strong>
              </div>
            </div>

            <form id="item-donation-form" novalidate>
              <div style="margin-bottom: 28px;">
                <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 16px; color: #3154f4;">
                  ${icon('mapPin')}
                  <h3 style="font-size: 15px; font-weight: 600; margin: 0;">Informações para Coleta</h3>
                </div>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px;" class="form-grid">
                  <div>
                    <label for="item-donor-name" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">Nome Completo *</label>
                    <input type="text" id="item-donor-name" required value="${usuario && usuario.nome ? usuario.nome : ''}" placeholder="Seu nome completo" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                  </div>
                  <div>
                    <label for="item-donor-phone" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">Telefone *</label>
                    <input type="text" id="item-donor-phone" required value="${usuario && usuario.telefone ? usuario.telefone : ''}" placeholder="(00) 00000-0000" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                  </div>
                </div>
                <div style="margin-bottom: 16px;">
                  <label for="item-donor-email" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">E-mail *</label>
                  <input type="email" id="item-donor-email" required value="${usuario && usuario.email ? usuario.email : ''}" placeholder="seu@email.com" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
                <div style="margin-bottom: 16px;">
                  <label for="item-donor-address" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">Endereço para Coleta *</label>
                  <input type="text" id="item-donor-address" required placeholder="Rua, número, complemento" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
                <div style="margin-bottom: 16px;">
                  <label for="item-donor-city" style="display: block; font-size: 13px; font-weight: 600; color: #172033; margin-bottom: 6px;">Cidade *</label>
                  <input type="text" id="item-donor-city" required placeholder="Sua cidade" style="width: 100%; height: 46px; padding: 0 14px; border: 1px solid #dfe6f0; border-radius: 10px; font-size: 14px;">
                </div>
                <div style="background: #f2f5ff; border: 1px solid #dce5ff; padding: 12px 16px; border-radius: 10px; font-size: 12px; color: #3154f4; display: flex; align-items: center; gap: 10px;">
                  ${icon('mapPin')}
                  <span>Entraremos em contato em até 24 horas para agendar a coleta dos itens.</span>
                </div>
              </div>

              <div style="text-align: center; padding-top: 20px; border-top: 1px solid #dfe6f0;">
                <button type="submit" style="background: #3154f4; color: #fff; border: 0; width: 100%; height: 50px; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer; box-shadow: 0 4px 12px rgba(49, 84, 244, 0.25);">Confirmar Doação de ${totalItems} ${totalItems === 1 ? 'Item' : 'Itens'}</button>
                <p style="font-size: 12px; color: #667085; margin-top: 16px;">Nossa equipe verificará os itens no momento da coleta.</p>
              </div>
            </form>
          </div>
        </div>
      `
    }
  } else if (activeSection === 'Necessidades') {
    // Filter necessidades
    const filteredList = necessidadesList.filter(item => {
      if (necessidadesFilter === 'urgentes') return item.urgente
      if (necessidadesFilter === 'verificadas') return item.verificado
      return true
    })

    mainContent = `
      <div class="content-card" style="margin-top: 25px; padding: 32px;">
        <div style="margin-bottom: 24px;">
          <h2 style="font-size: 22px; font-weight: 700; color: #172033; margin-bottom: 8px;">Necessidades Cadastradas</h2>
          <p style="font-size: 14px; color: #45536b;">Veja quem precisa de ajuda e como você pode fazer a diferença diretamente.</p>
        </div>

        <div style="display: flex; gap: 12px; margin-bottom: 28px; flex-wrap: wrap;">
          <button type="button" class="filter-tab ${necessidadesFilter === 'todas' ? 'is-active-tab' : ''}" data-filter="todas" style="padding: 10px 20px; border-radius: 20px; font-size: 13px; font-weight: 600; cursor: pointer; border: ${necessidadesFilter === 'todas' ? '0' : '1px solid #dfe6f0'}; background: ${necessidadesFilter === 'todas' ? '#a338ef' : '#fff'}; color: ${necessidadesFilter === 'todas' ? '#fff' : '#45536b'};">Todas (${necessidadesList.length})</button>
          <button type="button" class="filter-tab ${necessidadesFilter === 'urgentes' ? 'is-active-tab' : ''}" data-filter="urgentes" style="padding: 10px 20px; border-radius: 20px; font-size: 13px; font-weight: 600; cursor: pointer; border: ${necessidadesFilter === 'urgentes' ? '0' : '1px solid #dfe6f0'}; background: ${necessidadesFilter === 'urgentes' ? '#a338ef' : '#fff'}; color: ${necessidadesFilter === 'urgentes' ? '#fff' : '#45536b'};">Urgentes (${necessidadesList.filter(i => i.urgente).length})</button>
          <button type="button" class="filter-tab ${necessidadesFilter === 'verificadas' ? 'is-active-tab' : ''}" data-filter="verificadas" style="padding: 10px 20px; border-radius: 20px; font-size: 13px; font-weight: 600; cursor: pointer; border: ${necessidadesFilter === 'verificadas' ? '0' : '1px solid #dfe6f0'}; background: ${necessidadesFilter === 'verificadas' ? '#a338ef' : '#fff'}; color: ${necessidadesFilter === 'verificadas' ? '#fff' : '#45536b'};">Verificadas (${necessidadesList.filter(i => i.verificado).length})</button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 20px;">
          ${filteredList.map(item => `
            <div style="background: #fff; border: 1px solid #e1e7f0; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.03);">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; flex-wrap: wrap; gap: 10px;">
                <div>
                  <h3 style="font-size: 18px; font-weight: 700; color: #172033; margin-bottom: 4px;">${item.title}</h3>
                  <div style="display: flex; align-items: center; gap: 12px; font-size: 13px; color: #667085;">
                    <span>📍 ${item.location}</span>
                    <span>🕒 ${item.time}</span>
                  </div>
                </div>
                <div style="display: flex; gap: 8px;">
                  ${item.verificado ? '<span style="background: #e6f9f0; color: #007d4b; font-size: 12px; font-weight: 600; padding: 4px 10px; border-radius: 20px; display: inline-flex; align-items: center; gap: 4px;">✓ Verificado</span>' : ''}
                  ${item.urgente ? '<span style="background: #fee7e8; color: #b8323a; font-size: 12px; font-weight: 600; padding: 4px 10px; border-radius: 20px; display: inline-flex; align-items: center; gap: 4px;">! Urgente</span>' : ''}
                </div>
              </div>

              <p style="font-size: 14px; color: #45536b; margin-bottom: 16px; line-height: 1.5;">${item.description}</p>

              <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 20px;">
                ${item.tags.map(tag => `<span style="background: #f2f5ff; color: #3154f4; font-size: 12px; font-weight: 500; padding: 4px 12px; border-radius: 8px;">${tag}</span>`).join('')}
              </div>

              <div style="display: flex; gap: 12px; align-items: center;">
                <button type="button" class="btn-quero-ajudar" data-need-id="${item.id}" style="flex: 1; height: 46px; background: linear-gradient(90deg, #a338ef, #e90070); color: #fff; border: 0; border-radius: 10px; font-size: 14px; font-weight: 600; cursor: pointer; box-shadow: 0 4px 12px rgba(163, 56, 239, 0.25);">Quero Ajudar</button>
                <button type="button" class="btn-ver-detalhes" data-need-id="${item.id}" style="padding: 0 20px; height: 46px; background: #f2f5ff; color: #3154f4; border: 1px solid #dce5ff; border-radius: 10px; font-size: 14px; font-weight: 600; cursor: pointer;">Ver Detalhes</button>
              </div>
            </div>
          `).join('')}
        </div>

        <div style="margin-top: 32px; background: #f2f5ff; border: 1px solid #dce5ff; padding: 20px; border-radius: 12px; display: flex; gap: 16px; align-items: flex-start;">
          <div style="color: #3154f4; margin-top: 2px;">${icon('shield')}</div>
          <div>
            <h4 style="font-size: 15px; font-weight: 600; color: #172033; margin-bottom: 4px;">Como funciona a verificação?</h4>
            <p style="font-size: 13px; color: #45536b; line-height: 1.5; margin: 0;">Todas as necessidades marcadas como "Verificadas" passaram por um processo de validação onde nossa equipe confirma a identidade e a situação da pessoa ou instituição. Isso garante que sua doação chegue para quem realmente precisa. A verificação é feita através de documentos, visitas presenciais e contato telefônico.</p>
          </div>
        </div>
      </div>
    `
  } else if (activeSection === 'Doações') {
    mainContent = renderMinhasDoacoes(usuario)
  } else if (activeSection === 'Solicitações') {
    mainContent = renderSolicitacoes(usuario)
  } else if (activeSection === 'Perfil') {
    mainContent = renderPerfil(usuario)
  }

  document.querySelector('#app').innerHTML = `
    ${headerHtml}
    <main>
      <div class="page-shell">
        ${navHtml}
        ${mainContent}
      </div>
    </main>

    <footer class="site-footer">
      <p>© 2026 AjudaMais - Facilitando o acesso a recursos básicos para pessoas necessitadas</p>
      <span>Desenvolvido com <b aria-label="amor">♥</b> para fazer a diferença</span>
    </footer>

    <a class="cookie-button" href="termos.html" style="display:inline-flex;align-items:center;text-decoration:none;">Termos de Uso e Privacidade</a>
    <button class="chat-button" type="button" data-action="chat" aria-label="Abrir ajuda">
      ${icon('chat')}
    </button>
    <aside class="chat-panel" aria-live="polite" aria-hidden="true">
      <div class="chat-header">
        <div>
          <strong>AjudaMais</strong>
          <span>Estamos aqui para ajudar</span>
        </div>
        <button type="button" data-action="close-chat" aria-label="Fechar ajuda">${icon('close')}</button>
      </div>
      <p>Olá! Como podemos ajudar você hoje?</p>
      <button type="button" class="chat-option" data-action="chat-message">Tenho uma dúvida ${icon('arrow')}</button>
    </aside>
    <div class="toast" role="status" aria-live="polite"></div>
  `

  bindEvents(usuario)
  restaurarRascunho(activeSection)
  marcarCamposSujos()
}

// ---- Dados reais do banco (MySQL via API) --------------------------------

let dataLoading = false
// Indica que ao menos uma busca no banco já terminou (dados prontos para pintar).
let dadosCarregados = false
let reloadQueued = false
// Verdadeiro quando o usuário já digitou em algum campo: nesse caso o painel
// não pode ser redesenhado por baixo, senão o formulário perde o conteúdo.
let formDirty = false

function marcarCamposSujos() {
  document.querySelectorAll('#app input, #app textarea, #app select').forEach((el) => {
    if (el.dataset.dirtyBound) return
    el.dataset.dirtyBound = '1'
    el.addEventListener('input', () => { formDirty = true })
    el.addEventListener('change', () => { formDirty = true })
  })
}

// Redesenha a tela mantendo o que a pessoa já digitou. Usado por botões que
// mudam só uma parte do visual (valor, forma de pagamento, categoria, +/- itens).
function renderPreservando(usuario) {
  const snapshot = {}
  const extras = { descs: [], qtys: [] }
  document.querySelectorAll('#app input, #app textarea, #app select').forEach((el) => {
    if (el.id) {
      snapshot[el.id] = el.type === 'checkbox' ? el.checked : el.value
    } else if (el.classList.contains('req-item-desc')) {
      extras.descs.push(el.value)
    } else if (el.classList.contains('req-item-qty')) {
      extras.qtys.push(el.value)
    }
  })
  renderApp(usuario)
  Object.keys(snapshot).forEach((id) => {
    const el = document.getElementById(id)
    if (!el) return
    if (el.type === 'checkbox') el.checked = snapshot[id]
    else el.value = snapshot[id]
  })
  document.querySelectorAll('.req-item-desc').forEach((el, i) => {
    if (extras.descs[i] !== undefined) el.value = extras.descs[i]
  })
  document.querySelectorAll('.req-item-qty').forEach((el, i) => {
    if (extras.qtys[i] !== undefined) el.value = extras.qtys[i]
  })
}

// Recarrega dados do banco e redesenha a tela (usado depois de salvar).
function recarregar(usuario) {
  formDirty = false
  return buscarDados().then((changed) => { renderApp(usuario); return changed })
}

function carregarDados(usuario) {
  return buscarDados().then((changed) => {
    const canRender = ['Início', 'Doações', 'Solicitações', 'Perfil', 'Necessidades'].includes(activeSection)
    if (changed && canRender && !formDirty) renderApp(usuario)
  })
}

// Busca os dados do banco e mantém em memória. Não desenha nada: quem chama
// decide quando pintar a tela. Evita apagar formulários já preenchidos.
function buscarDados() {
  if (typeof Api === 'undefined') return Promise.resolve(false)
  if (dataLoading) { reloadQueued = true; return Promise.resolve(false) }
  dataLoading = true
  return Promise.all([
    Api.get('/stats'),
    Api.get('/donations/recent'),
    Api.get('/requests', { limit: 50 }),
    Api.get('/categories'),
    Api.isLogged() ? Api.get('/donations/mine') : Promise.resolve({ ok: false }),
    Api.isLogged() ? Api.get('/requests/mine/list') : Promise.resolve({ ok: false }),
    Api.isLogged() ? Api.get('/users/me') : Promise.resolve({ ok: false })
  ]).then(([statsRes, donationsRes, requestsRes, categoriesRes, mineRes, reqMineRes, meRes]) => {
    dataLoading = false
    dadosCarregados = true
    let changed = false

    if (mineRes.ok && mineRes.data && Array.isArray(mineRes.data.donations)) {
      minhasDoacoes = mineRes.data.donations
      changed = true
    }
    if (reqMineRes.ok && reqMineRes.data && Array.isArray(reqMineRes.data.requests)) {
      minhasSolicitacoes = reqMineRes.data.requests
      changed = true
    }
    if (meRes.ok && meRes.data && Array.isArray(meRes.data.addresses)) {
      meusEnderecos = meRes.data.addresses
      changed = true
    }

    if (categoriesRes.ok && categoriesRes.data && Array.isArray(categoriesRes.data.categories)) {
      categories = categoriesRes.data.categories
    }

    if (statsRes.ok && statsRes.data) { stats = statsRes.data; changed = true }

    if (donationsRes.ok && donationsRes.data && Array.isArray(donationsRes.data.donations)) {
      recentDonations = donationsRes.data.donations.map((d) => ({
        id: d.id,
        initials: d.initials,
        name: d.name,
        detail: d.detail,
        time: timeAgo(d.created_at)
      }))
      changed = true
    }

    if (requestsRes.ok && requestsRes.data && Array.isArray(requestsRes.data.requests)) {
      necessidadesList = requestsRes.data.requests.map((r) => ({
        id: r.id,
        title: r.title,
        location: [r.city, r.state_code].filter(Boolean).join(', ') ||
          (r.institution_name || 'Local não informado'),
        time: timeAgo(r.created_at),
        description: r.description || 'Sem descrição informada.',
        tags: (r.items || []).map((i) => i.description).slice(0, 4),
        urgente: r.priority === 'urgente' || r.priority === 'alta',
        verificado: Boolean(r.institution_name),
        category: r.category_name || 'Outros',
        category_slug: r.category_slug,
        percent_complete: r.percent_complete,
        institution_name: r.institution_name,
        beneficiary_count: r.beneficiary_count,
        needed_by: r.needed_by
      }))
      changed = true
    }

    if (reloadQueued) { reloadQueued = false; carregarDados(usuario) }
    return changed
  }).catch(() => { dataLoading = false; return false })
}

// ---- Minhas Doações ------------------------------------------------------

function statusLabel(status) {
  const map = {
    pendente: 'Pendente', confirmada: 'Confirmada', em_transito: 'Em trânsito',
    recebida: 'Recebida', cancelada: 'Cancelada', recusada: 'Recusada',
    aberta: 'Aberta', parcialmente_atendida: 'Parcialmente atendida',
    atendida: 'Atendida', expirada: 'Expirada', bloqueada: 'Bloqueada', rascunho: 'Rascunho'
  }
  return map[status] || status
}

function statusColor(status) {
  if (status === 'pendente') return 'background:#fff4e0;color:#9a5a00;'
  if (status === 'confirmada' || status === 'em_transito') return 'background:#f2f5ff;color:#3154f4;'
  if (status === 'recebida') return 'background:#e6f9f0;color:#007d4b;'
  return 'background:#fee7e8;color:#c8323a;'
}

function renderMinhasDoacoes(usuario) {
  if (!usuario) {
    return `<div class="content-card" style="margin-top:25px;padding:40px;text-align:center;">
      <h2 style="font-size:20px;color:#172033;margin-bottom:12px;">Minhas Doações</h2>
      <p style="font-size:14px;color:#45536b;margin-bottom:20px;">Entre na sua conta para acompanhar suas doações.</p>
      <a class="primary-button" href="login.html?next=index.html" style="background:#3154f4;color:#fff;text-decoration:none;">Entrar</a>
    </div>`
  }
  const rows = minhasDoacoes.length
    ? minhasDoacoes.map((d) => `
      <div style="background:#fff;border:1px solid #e1e7f0;border-radius:12px;padding:18px 20px;display:flex;justify-content:space-between;gap:16px;align-items:center;flex-wrap:wrap;">
        <div>
          <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px;">
            <strong style="font-size:14px;color:#172033;">${d.code}</strong>
            <span style="${statusColor(d.status)}font-size:11px;font-weight:600;padding:3px 10px;border-radius:20px;">${statusLabel(d.status)}</span>
          </div>
          <p style="font-size:13px;color:#45536b;margin:0 0 4px;">
            ${d.donation_type === 'dinheiro'
              ? 'Dinheiro • ' + formatMoney(d.amount) + (d.payment_method ? ' • ' + d.payment_method : '')
              : 'Itens • ' + formatNumber(d.items_quantity) + ' unidade(s)'}
          </p>
          <p style="font-size:12px;color:#667085;margin:0;">${d.institution_name ? 'Para ' + d.institution_name : 'Sem instituição definida (a administração direciona)'} • ${timeAgo(d.created_at)}</p>
        </div>
        ${d.status === 'pendente' ? `<button type="button" class="btn-cancelar-doacao" data-id="${d.id}" style="padding:10px 18px;border:1px solid #f0c2c5;background:#fff;color:#c8323a;border-radius:10px;font-size:13px;font-weight:600;cursor:pointer;">Cancelar</button>` : ''}
      </div>`).join('')
    : `<p style="font-size:14px;color:#667085;">Você ainda não fez doações. ${''}</p>`

  return `
    <div class="content-card" style="margin-top:25px;padding:32px;">
      <div style="margin-bottom:24px;">
        <h2 style="font-size:22px;font-weight:700;color:#172033;margin-bottom:8px;">Minhas Doações</h2>
        <p style="font-size:14px;color:#45536b;">Acompanhe o status de cada doação registrada no AjudaMais.</p>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">${rows}</div>
    </div>
  `
}

// ---- Solicitações de ajuda ----------------------------------------------

function renderSolicitacoes(usuario) {
  if (!usuario) {
    return `<div class="content-card" style="margin-top:25px;padding:40px;text-align:center;">
      <h2 style="font-size:20px;color:#172033;margin-bottom:12px;">Solicitações de Ajuda</h2>
      <p style="font-size:14px;color:#45536b;margin-bottom:20px;">Entre na sua conta para pedir ou acompanhar ajuda.</p>
      <a class="primary-button" href="login.html?next=index.html" style="background:#3154f4;color:#fff;text-decoration:none;">Entrar</a>
    </div>`
  }

  const list = minhasSolicitacoes.length
    ? minhasSolicitacoes.map((r) => `
      <div style="background:#fff;border:1px solid #e1e7f0;border-radius:12px;padding:16px 20px;display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;">
        <div>
          <strong style="font-size:14px;color:#172033;display:block;margin-bottom:4px;">${r.title}</strong>
          <span style="font-size:12px;color:#667085;">${r.items_count} item(ns) • ${r.city || 'Cidade não informada'} • ${timeAgo(r.created_at)}</span>
        </div>
        <span style="${statusColor(r.status === 'aberta' || r.status === 'parcialmente_atendida' ? 'confirmada' : r.status === 'atendida' ? 'recebida' : (r.status === 'cancelada' || r.status === 'expirada' || r.status === 'bloqueada') ? 'cancelada' : 'pendente')}font-size:11px;font-weight:600;padding:3px 10px;border-radius:20px;">${statusLabel(r.status)}</span>
      </div>`).join('')
    : `<p style="font-size:14px;color:#667085;">Nenhuma solicitação registrada ainda.</p>`

  const categoryOptions = categories.map((c) => `<option value="${c.id}">${c.name}</option>`).join('')

  return `
    <div class="content-card" style="margin-top:25px;padding:32px;">
      <div style="margin-bottom:24px;">
        <h2 style="font-size:22px;font-weight:700;color:#172033;margin-bottom:8px;">Pedir Ajuda</h2>
        <p style="font-size:14px;color:#45536b;">Descreva o que você precisa. Sua solicitação fica visível para doadores e instituições.</p>
      </div>

      <form id="request-form" style="display:flex;flex-direction:column;gap:16px;margin-bottom:32px;" novalidate>
        <div>
          <label for="req-title" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Título *</label>
          <input id="req-title" type="text" required placeholder="Ex.: Cesta básica para família de 4 pessoas" style="width:100%;height:46px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">
        </div>
        <div>
          <label for="req-description" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Descrição</label>
          <textarea id="req-description" rows="3" placeholder="Conte sua situação" style="width:100%;padding:12px 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;font-family:inherit;"></textarea>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;" class="form-grid">
          <div>
            <label for="req-category" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Categoria</label>
            <select id="req-category" style="width:100%;height:46px;padding:0 12px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;background:#fff;">
              <option value="">Selecione</option>
              ${categoryOptions}
            </select>
          </div>
          <div>
            <label for="req-priority" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Prioridade</label>
            <select id="req-priority" style="width:100%;height:46px;padding:0 12px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;background:#fff;">
              <option value="normal">Normal</option>
              <option value="alta">Alta</option>
              <option value="urgente">Urgente</option>
              <option value="baixa">Baixa</option>
            </select>
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;" class="form-grid">
          <div>
            <label for="req-city" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Cidade</label>
            <input id="req-city" type="text" placeholder="Sua cidade" style="width:100%;height:46px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">
          </div>
          <div>
            <label for="req-uf" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">UF</label>
            <input id="req-uf" type="text" maxlength="2" placeholder="SP" style="width:100%;height:46px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;text-transform:uppercase;">
          </div>
          <div>
            <label for="req-people" style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Pessoas atendidas</label>
            <input id="req-people" type="number" min="1" placeholder="4" style="width:100%;height:46px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">
          </div>
        </div>
        <div>
          <label style="display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;">Itens necessários *</label>
          <div id="req-items" style="display:flex;flex-direction:column;gap:10px;">
            <div class="req-item-row" style="display:grid;grid-template-columns:1fr 110px;gap:10px;">
              <input type="text" class="req-item-desc" placeholder="Ex.: Cesta básica" style="width:100%;height:44px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">
              <input type="number" class="req-item-qty" min="1" value="1" style="width:100%;height:44px;padding:0 12px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">
            </div>
          </div>
          <button type="button" id="req-add-item" style="margin-top:10px;background:#f2f5ff;color:#3154f4;border:1px solid #dce5ff;border-radius:8px;padding:8px 14px;font-size:13px;font-weight:600;cursor:pointer;">+ Adicionar item</button>
        </div>
        <div>
          <button type="submit" style="background:#3154f4;color:#fff;border:0;padding:0 32px;height:48px;border-radius:12px;font-size:15px;font-weight:600;cursor:pointer;">Publicar solicitação</button>
        </div>
      </form>

      <h3 style="font-size:16px;font-weight:700;color:#172033;margin-bottom:14px;">Minhas solicitações</h3>
      <div style="display:flex;flex-direction:column;gap:12px;">${list}</div>
    </div>
  `
}

// ---- Perfil --------------------------------------------------------------

function renderPerfil(usuario) {
  if (!usuario) {
    return `<div class="content-card" style="margin-top:25px;padding:40px;text-align:center;">
      <h2 style="font-size:20px;color:#172033;margin-bottom:12px;">Meu Perfil</h2>
      <p style="font-size:14px;color:#45536b;margin-bottom:20px;">Entre na sua conta para ver e editar seus dados.</p>
      <a class="primary-button" href="login.html?next=index.html" style="background:#3154f4;color:#fff;text-decoration:none;">Entrar</a>
    </div>`
  }

  const addrRows = meusEnderecos.length
    ? meusEnderecos.map((a) => `
      <div style="background:#fff;border:1px solid #e1e7f0;border-radius:10px;padding:14px 16px;display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap;">
        <div>
          <strong style="font-size:13px;color:#172033;display:block;margin-bottom:2px;">${a.label || 'Endereço'}</strong>
          <span style="font-size:12px;color:#667085;">${[a.street, a.number, a.city, a.state_code].filter(Boolean).join(', ')}</span>
        </div>
        <button type="button" class="btn-del-address" data-id="${a.id}" style="border:1px solid #f0c2c5;background:#fff;color:#c8323a;border-radius:8px;padding:6px 12px;font-size:12px;font-weight:600;cursor:pointer;">Remover</button>
      </div>`).join('')
    : `<p style="font-size:13px;color:#667085;">Nenhum endereço cadastrado.</p>`

  const inputStyle = 'width:100%;height:46px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;';
  const labelStyle = 'display:block;font-size:13px;font-weight:600;color:#172033;margin-bottom:6px;';

  return `
    <div class="content-card" style="margin-top:25px;padding:32px;">
      <h2 style="font-size:22px;font-weight:700;color:#172033;margin-bottom:8px;">Meu Perfil</h2>
      <p style="font-size:14px;color:#45536b;margin-bottom:24px;">Dados lidos do banco. Edite e salve para atualizar seu cadastro.</p>

      <form id="profile-form" style="display:flex;flex-direction:column;gap:16px;margin-bottom:32px;" novalidate>
        <div>
          <label for="pf-name" style="${labelStyle}">Nome completo</label>
          <input id="pf-name" type="text" value="${usuario.nome || ''}" style="${inputStyle}">
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;" class="form-grid">
          <div>
            <label for="pf-display" style="${labelStyle}">Como quer ser chamado</label>
            <input id="pf-display" type="text" value="${usuario.display_name || ''}" placeholder="Ex.: Ana" style="${inputStyle}">
          </div>
          <div>
            <label for="pf-phone" style="${labelStyle}">Celular</label>
            <input id="pf-phone" type="text" value="${usuario.telefone || ''}" placeholder="(00) 00000-0000" style="${inputStyle}">
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;" class="form-grid">
          <div>
            <label for="pf-email" style="${labelStyle}">E-mail</label>
            <input id="pf-email" type="email" value="${usuario.email || ''}" disabled style="${inputStyle}background:#f6f8fb;color:#667085;">
          </div>
          <div>
            <label for="pf-cpf" style="${labelStyle}">CPF</label>
            <input id="pf-cpf" type="text" value="${usuario.cpf_masked || ''}" disabled style="${inputStyle}background:#f6f8fb;color:#667085;">
          </div>
        </div>
        <div>
          <label for="pf-birth" style="${labelStyle}">Data de nascimento</label>
          <input id="pf-birth" type="date" value="${usuario.birth_date ? String(usuario.birth_date).slice(0, 10) : ''}" style="${inputStyle}">
        </div>
        <div>
          <button type="submit" style="background:#3154f4;color:#fff;border:0;padding:0 32px;height:46px;border-radius:12px;font-size:15px;font-weight:600;cursor:pointer;">Salvar dados</button>
        </div>
      </form>

      <h3 style="font-size:16px;font-weight:700;color:#172033;margin-bottom:14px;">Meus endereços</h3>
      <div style="display:flex;flex-direction:column;gap:10px;margin-bottom:20px;">${addrRows}</div>

      <form id="address-form" style="display:grid;grid-template-columns:1fr 120px 1fr;gap:12px;margin-bottom:36px;" class="form-grid" novalidate>
        <input id="ad-street" type="text" placeholder="Rua e número" style="${inputStyle}">
        <input id="ad-label" type="text" placeholder="Apelido" style="${inputStyle}">
        <input id="ad-city" type="text" placeholder="Cidade" style="${inputStyle}">
        <button type="submit" style="background:#f2f5ff;color:#3154f4;border:1px solid #dce5ff;border-radius:10px;height:46px;font-size:14px;font-weight:600;cursor:pointer;">Adicionar endereço</button>
      </form>

      <h3 style="font-size:16px;font-weight:700;color:#172033;margin-bottom:14px;">Alterar senha</h3>
      <form id="password-form" style="display:flex;flex-direction:column;gap:14px;max-width:420px;" novalidate>
        <input id="pw-current" type="password" placeholder="Senha atual" autocomplete="current-password" style="${inputStyle}">
        <input id="pw-new" type="password" placeholder="Nova senha (mínimo 8 caracteres)" autocomplete="new-password" style="${inputStyle}">
        <div>
          <button type="submit" style="background:#172033;color:#fff;border:0;padding:0 28px;height:44px;border-radius:10px;font-size:14px;font-weight:600;cursor:pointer;">Alterar senha</button>
        </div>
      </form>
    </div>
  `
}


function bindEvents(usuario) {
  const toast = document.querySelector('.toast')
  let toastTimer

  function showToast(message) {
    if (!toast) return
    toast.textContent = message
    toast.classList.add('is-visible')
    window.clearTimeout(toastTimer)
    toastTimer = window.setTimeout(() => toast.classList.remove('is-visible'), 3200)
  }

  function closeMobileMenu() {
    const nav = document.querySelector('.dashboard-nav')
    const toggle = document.querySelector('.menu-toggle')
    if (nav) nav.classList.remove('is-open')
    if (toggle) toggle.setAttribute('aria-expanded', 'false')
  }

  document.querySelectorAll('.nav-link').forEach((link) => {
    link.addEventListener('click', () => {
      const secao = link.dataset.section
      if (secao === activeSection) return
      // Salva o que foi digitado antes de trocar de tela.
      guardarRascunho(activeSection)
      activeSection = secao
      donationSuccess = false
      itemSuccess = false
      formDirty = false
      closeMobileMenu()
      const precisa = ['Doações', 'Solicitações', 'Perfil'].includes(secao)
      if (precisa && !dadosCarregados) {
        // Primeira visita: espera o banco e desenha uma única vez.
        buscarDados().then(() => { if (activeSection === secao) renderApp(usuario) })
        return
      }
      renderApp(usuario)
    })
  })

  const menuToggle = document.querySelector('.menu-toggle')
  if (menuToggle) {
    menuToggle.addEventListener('click', (event) => {
      const button = event.currentTarget
      const nav = document.querySelector('.dashboard-nav')
      const isOpen = nav.classList.toggle('is-open')
      button.setAttribute('aria-expanded', String(isOpen))
    })
  }

  const gotoDonateBtn = document.querySelector('[data-action="goto-donate"]')
  if (gotoDonateBtn) {
    gotoDonateBtn.addEventListener('click', () => {
      activeSection = 'Doar Dinheiro'
      renderApp(usuario)
    })
  }

  // Preset buttons (Dinheiro)
  document.querySelectorAll('.preset-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      selectedAmount = Number(btn.dataset.val)
      renderPreservando(usuario)
    })
  })

  const customInput = document.getElementById('custom-amount')
  if (customInput) {
    customInput.addEventListener('input', (e) => {
      let val = e.target.value.replace(/\D/g, '')
      selectedAmount = val ? Number(val) / 100 : 0
    })
    customInput.addEventListener('blur', () => {
      renderPreservando(usuario)
    })
  }

  // Payment methods (Dinheiro)
  document.querySelectorAll('.pay-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      selectedPayment = btn.dataset.pay
      renderPreservando(usuario)
    })
  })

  const donationForm = document.getElementById('donation-form')
  if (donationForm) {
    donationForm.addEventListener('submit', (e) => {
      e.preventDefault()
      if (selectedAmount <= 0) {
        showToast('Por favor, escolha ou digite um valor para a doação.')
        return
      }
      const name = document.getElementById('donor-name').value.trim()
      const email = document.getElementById('donor-email').value.trim()
      if (!name || !email) {
        showToast('Por favor, preencha todos os campos obrigatórios do doador.')
        return
      }
      if (typeof Api === 'undefined' || !Api.isLogged()) {
        showToast('Entre na sua conta para registrar a doação.')
        setTimeout(() => { window.location.href = 'login.html?next=index.html' }, 900)
        return
      }

      const methodMap = { card: 'cartao', transfer: 'transferencia', pix: 'pix' }
      const submitBtn = donationForm.querySelector('button[type="submit"]')
      if (submitBtn) submitBtn.disabled = true

      Api.post('/donations', {
        donation_type: 'dinheiro',
        amount: selectedAmount,
        payment_method: methodMap[selectedPayment] || 'pix',
        donor_name: name,
        donor_email: email,
        donor_phone: document.getElementById('donor-phone').value.trim() || null,
        request_id: pendingRequestId || undefined,
        message: pendingNeedTitle ? `Doação para a necessidade: ${pendingNeedTitle}` : null
      }).then((r) => {
        if (submitBtn) submitBtn.disabled = false
        if (!r.ok) {
          if (r.status === 401) {
            localStorage.removeItem('ajudamais_token')
            showToast('Sessão expirada. Entre novamente para doar.')
            return
          }
          showToast(r.message)
          return
        }
        const donation = r.data && r.data.donation
        successData = {
          amount: Number(donation ? donation.amount : selectedAmount),
          name: name,
          paymentMethod: selectedPayment,
          code: donation ? donation.code : null
        }
        donationSuccess = true
        pendingRequestId = null
        pendingNeedTitle = ''
        limparRascunho('Doar Dinheiro')
        renderApp(usuario)
        recarregar(usuario)
        showToast('Doação registrada! Código: ' + (successData.code || '—'))
      })
    })
  }

  const newDonationBtn = document.getElementById('btn-new-donation')
  if (newDonationBtn) {
    newDonationBtn.addEventListener('click', () => {
      donationSuccess = false
      selectedAmount = 0
      renderApp(usuario)
    })
  }

  // Doar Itens Events
  document.querySelectorAll('.item-cat-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      itemCategory = btn.dataset.cat
      renderPreservando(usuario)
    })
  })

  document.querySelectorAll('.item-plus-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      let item = btn.dataset.item
      itemCounts[item] = (itemCounts[item] || 0) + 1
      renderPreservando(usuario)
    })
  })

  document.querySelectorAll('.item-minus-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      let item = btn.dataset.item
      if ((itemCounts[item] || 0) > 0) {
        itemCounts[item]--
        renderPreservando(usuario)
      }
    })
  })

  const itemDonationForm = document.getElementById('item-donation-form')
  if (itemDonationForm) {
    itemDonationForm.addEventListener('submit', (e) => {
      e.preventDefault()
      let totalCount = 0
      Object.keys(itemCounts).forEach(k => totalCount += itemCounts[k])
      if (totalCount <= 0) {
        showToast('Por favor, selecione ao menos um item para doar.')
        return
      }
      const name = document.getElementById('item-donor-name').value.trim()
      const phone = document.getElementById('item-donor-phone').value.trim()
      const email = document.getElementById('item-donor-email').value.trim()
      const address = document.getElementById('item-donor-address').value.trim()
      const city = document.getElementById('item-donor-city').value.trim()
      if (!name || !phone || !email || !address || !city) {
        showToast('Por favor, preencha todos os campos obrigatórios para a coleta.')
        return
      }
      if (typeof Api === 'undefined' || !Api.isLogged()) {
        showToast('Entre na sua conta para registrar a doação.')
        setTimeout(() => { window.location.href = 'login.html?next=index.html' }, 900)
        return
      }

      const submitBtn = itemDonationForm.querySelector('button[type="submit"]')
      if (submitBtn) submitBtn.disabled = true

      // 1) Endereço de coleta vira uma linha em `addresses` do doador.
      Api.post('/users/me/addresses', {
        label: 'Coleta de doação',
        address_type: 'coleta',
        street: address,
        city: city,
        is_primary: false
      }).then((addrRes) => {
        const dropoffId = addrRes.ok && addrRes.data && addrRes.data.address
          ? addrRes.data.address.id
          : null

        // 2) Doação de itens com as quantidades reais escolhidas na tela.
        const items = Object.keys(itemCounts)
          .filter((k) => itemCounts[k] > 0)
          .map((k) => ({
            description: k,
            quantity: itemCounts[k],
            unit_code: 'un',
            item_condition: 'usado',
            category_id: categoryIdFor(itemCategory)
          }))

        return Api.post('/donations', {
          donation_type: 'itens',
          donor_name: name,
          donor_email: email,
          donor_phone: phone,
          dropoff_address_id: dropoffId,
          request_id: pendingRequestId || undefined,
          message: pendingNeedTitle ? `Doação para a necessidade: ${pendingNeedTitle}` : null,
          items: items
        })
      }).then((r) => {
        if (submitBtn) submitBtn.disabled = false
        if (!r.ok) {
          if (r.status === 401) {
            showToast('Sessão expirada. Entre novamente para doar.')
            return
          }
          showToast(r.message)
          return
        }
        itemSuccessData = {
          name,
          address,
          city,
          totalCount,
          code: r.data && r.data.donation ? r.data.donation.code : null
        }
        itemSuccess = true
        pendingRequestId = null
        pendingNeedTitle = ''
        Object.keys(itemCounts).forEach(k => itemCounts[k] = 0)
        limparRascunho('Doar Itens')
        renderApp(usuario)
        recarregar(usuario)
        showToast('Doação de itens registrada! Código: ' + (itemSuccessData.code || '—'))
      })
    })
  }

  const newItemDonationBtn = document.getElementById('btn-new-item-donation')
  if (newItemDonationBtn) {
    newItemDonationBtn.addEventListener('click', () => {
      itemSuccess = false
      Object.keys(itemCounts).forEach(k => itemCounts[k] = 0)
      renderApp(usuario)
    })
  }

  // Necessidades Filters and Actions
  document.querySelectorAll('.filter-tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      necessidadesFilter = tab.dataset.filter
      renderPreservando(usuario)
    })
  })

  document.querySelectorAll('.btn-quero-ajudar').forEach((btn) => {
    btn.addEventListener('click', () => {
      const needId = Number(btn.dataset.needId)
      const need = necessidadesList.find(n => n.id === needId)
      if (need) {
        // A doação fica vinculada à necessidade escolhida (request_id).
        pendingRequestId = need.id
        pendingNeedTitle = need.title
        // Direct to appropriate page based on need category
        if (need.category === 'Alimentos' || need.category === 'Higiene' || need.category === 'Roupas') {
          activeSection = 'Doar Itens'
          itemCategory = need.category === 'Higiene' ? 'Higiene' : need.category === 'Roupas' ? 'Roupas' : 'Alimentos'
          // Pre-select 1 unit of first item in category
          if (itemCategory === 'Alimentos') itemCounts['Arroz'] = 1
          else if (itemCategory === 'Roupas') itemCounts['Camisetas'] = 1
          else if (itemCategory === 'Higiene') itemCounts['Sabonete'] = 1
        } else {
          activeSection = 'Doar Dinheiro'
          selectedAmount = 50
        }
        renderApp(usuario)
        showToast(`Redirecionando para doação para: ${need.title}`)
      }
    })
  })

  document.querySelectorAll('.btn-ver-detalhes').forEach((btn) => {
    btn.addEventListener('click', () => {
      const needId = Number(btn.dataset.needId)
      const need = necessidadesList.find(n => n.id === needId)
      if (need) {
        showToast(`Detalhes de ${need.title}: ${need.description}`)
      }
    })
  })

  const profileBtn = document.querySelector('[data-action="profile"]')
  if (profileBtn) {
    profileBtn.addEventListener('click', () => {
      activeSection = 'Perfil'
      renderApp(usuario)
      recarregar(usuario)
    })
  }

  // ---- Minhas doações: cancelar doação pendente --------------------------
  document.querySelectorAll('.btn-cancelar-doacao').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.id)
      if (!window.confirm('Cancelar esta doação pendente?')) return
      btn.disabled = true
      Api.del('/donations/' + id).then((r) => {
        btn.disabled = false
        if (!r.ok) { showToast(r.message); return }
        showToast('Doação cancelada.')
        recarregar(usuario)
      })
    })
  })

  // ---- Solicitações: adicionar linha de item -----------------------------
  const addItemBtn = document.getElementById('req-add-item')
  if (addItemBtn) {
    addItemBtn.addEventListener('click', () => {
      const container = document.getElementById('req-items')
      const row = document.createElement('div')
      row.className = 'req-item-row'
      row.style.cssText = 'display:grid;grid-template-columns:1fr 110px;gap:10px;'
      row.innerHTML = '<input type="text" class="req-item-desc" placeholder="Ex.: Cobertor" style="width:100%;height:44px;padding:0 14px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">' +
        '<input type="number" class="req-item-qty" min="1" value="1" style="width:100%;height:44px;padding:0 12px;border:1px solid #dfe6f0;border-radius:10px;font-size:14px;">'
      container.appendChild(row)
    })
  }

  // ---- Solicitações: publicar (POST /api/requests) -----------------------
  const requestForm = document.getElementById('request-form')
  if (requestForm) {
    requestForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const title = document.getElementById('req-title').value.trim()
      if (title.length < 5) {
        showToast('Informe um título com pelo menos 5 caracteres.')
        return
      }
      const items = Array.from(document.querySelectorAll('.req-item-row')).map((row) => ({
        description: row.querySelector('.req-item-desc').value.trim(),
        quantity_requested: Number(row.querySelector('.req-item-qty').value) || 0
      })).filter((i) => i.description.length >= 2 && i.quantity_requested > 0)

      if (!items.length) {
        showToast('Informe ao menos um item necessário.')
        return
      }

      const submitBtn = requestForm.querySelector('button[type="submit"]')
      if (submitBtn) submitBtn.disabled = true

      const categoryId = document.getElementById('req-category').value
      Api.post('/requests', {
        title,
        description: document.getElementById('req-description').value.trim() || null,
        category_id: categoryId ? Number(categoryId) : null,
        priority: document.getElementById('req-priority').value,
        city: document.getElementById('req-city').value.trim() || null,
        state_code: document.getElementById('req-uf').value.trim() || null,
        beneficiary_count: Number(document.getElementById('req-people').value) || null,
        items
      }).then((r) => {
        if (submitBtn) submitBtn.disabled = false
        if (!r.ok) { showToast(r.message); return }
        showToast('Solicitação publicada!')
        limparRascunho('Solicitações')
        recarregar(usuario)
      })
    })
  }

  // ---- Perfil: salvar dados (PATCH /api/users/me) ------------------------
  const profileForm = document.getElementById('profile-form')
  if (profileForm) {
    profileForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const birth = document.getElementById('pf-birth').value
      const body = {
        full_name: document.getElementById('pf-name').value.trim(),
        display_name: document.getElementById('pf-display').value.trim() || null,
        birth_date: birth || null
      }
      const phone = document.getElementById('pf-phone').value.trim()
      if (phone) body.phone = phone

      const submitBtn = profileForm.querySelector('button[type="submit"]')
      if (submitBtn) submitBtn.disabled = true

      AuthService.atualizarPerfil(body).then((r) => {
        if (submitBtn) submitBtn.disabled = false
        if (!r.ok) { showToast(r.message); return }
        showToast('Dados atualizados!')
        renderApp(r.user)
      })
    })
  }

  // ---- Perfil: adicionar endereço ---------------------------------------
  const addressForm = document.getElementById('address-form')
  if (addressForm) {
    addressForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const street = document.getElementById('ad-street').value.trim()
      const city = document.getElementById('ad-city').value.trim()
      if (!street || !city) {
        showToast('Informe a rua e a cidade do endereço.')
        return
      }
      const submitBtn = addressForm.querySelector('button[type="submit"]')
      if (submitBtn) submitBtn.disabled = true
      Api.post('/users/me/addresses', {
        label: document.getElementById('ad-label').value.trim() || null,
        address_type: 'residencial',
        street, city
      }).then((r) => {
        if (submitBtn) submitBtn.disabled = false
        if (!r.ok) { showToast(r.message); return }
        showToast('Endereço adicionado!')
        recarregar(usuario)
      })
    })
  }

  document.querySelectorAll('.btn-del-address').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!window.confirm('Remover este endereço?')) return
      Api.del('/users/me/addresses/' + btn.dataset.id).then((r) => {
        if (!r.ok) { showToast(r.message); return }
        showToast('Endereço removido.')
        recarregar(usuario)
      })
    })
  })

  // ---- Perfil: alterar senha --------------------------------------------
  const passwordForm = document.getElementById('password-form')
  if (passwordForm) {
    passwordForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const current = document.getElementById('pw-current').value
      const next = document.getElementById('pw-new').value
      if (next.length < 8) {
        showToast('A nova senha precisa ter ao menos 8 caracteres.')
        return
      }
      const submitBtn = passwordForm.querySelector('button[type="submit"]')
      if (submitBtn) submitBtn.disabled = true
      Api.post('/users/me/password', { current_password: current, new_password: next }).then((r) => {
        if (submitBtn) submitBtn.disabled = false
        if (!r.ok) { showToast(r.message); return }
        passwordForm.reset()
        showToast('Senha alterada com sucesso!')
      })
    })
  }

  const chatMsgBtn = document.querySelector('[data-action="chat-message"]')
  if (chatMsgBtn) {
    chatMsgBtn.addEventListener('click', () => {
      showToast('Atendimento conectado! Envie sua dúvida para suporte@ajudamais.org.')
    })
  }

  const chatBtn = document.querySelector('[data-action="chat"]')
  if (chatBtn) {
    chatBtn.addEventListener('click', () => {
      const panel = document.querySelector('.chat-panel')
      if (panel) {
        panel.classList.add('is-open')
        panel.setAttribute('aria-hidden', 'false')
      }
    })
  }

  const closeChatBtn = document.querySelector('[data-action="close-chat"]')
  if (closeChatBtn) {
    closeChatBtn.addEventListener('click', () => {
      const panel = document.querySelector('.chat-panel')
      if (panel) {
        panel.classList.remove('is-open')
        panel.setAttribute('aria-hidden', 'true')
      }
    })
  }

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      closeMobileMenu()
      const panel = document.querySelector('.chat-panel')
      if (panel) panel.classList.remove('is-open')
    }
  })
}

// Carrega o usuário logado (se houver), desenha o painel e busca os dados reais.
AuthService.usuarioAtual().then(function (usuario) {
  if (typeof renderApp === 'function') renderApp(usuario)
  if (typeof carregarDados === 'function') carregarDados(usuario)
})
