(() => {
  const paths = { 'zh-Hant': '/', 'zh-Hans': '/zh-Hans/', en: '/en/' };
  const names = { 'zh-Hant': '繁體中文', 'zh-Hans': '简体中文', en: 'English' };
  const current = document.documentElement.lang;
  if (!Object.hasOwn(paths, current)) return;
  const key = 'container-desk.language.v1';
  const valid = value => typeof value === 'string' && Object.hasOwn(paths, value);
  const readPreference = () => {
    try { const value = localStorage.getItem(key); return valid(value) ? value : null; } catch { return null; }
  };
  const remember = language => { try { localStorage.setItem(key, language); } catch { /* Storage is optional. */ } };
  let manuallyChosen = false;
  document.querySelectorAll('.languages a').forEach(link => link.addEventListener('click', () => {
    const language = link.getAttribute('lang');
    if (valid(language)) { manuallyChosen = true; remember(language); }
  }));
  const copy = {
    'zh-Hant': { title: '切換顯示語言？', region: '依目前的網路位置，建議使用', browser: '依瀏覽器的語言設定，建議使用', preference: '你先前選擇的語言是', question: '要前往對應的語言頁面嗎？', stay: '留在此頁', go: '切換至', note: '會在此瀏覽器記住你的選擇，你仍可隨時從上方切換語言。' },
    'zh-Hans': { title: '切换显示语言？', region: '根据当前的网络位置，建议使用', browser: '根据浏览器的语言设置，建议使用', preference: '你之前选择的语言是', question: '要前往对应的语言页面吗？', stay: '留在此页', go: '切换至', note: '会在此浏览器记住你的选择，你仍可随时从上方切换语言。' },
    en: { title: 'Switch language?', region: 'Based on your network location, we suggest', browser: 'Based on your browser settings, we suggest', preference: 'Your previously selected language is', question: 'Would you like to visit that version?', stay: 'Stay on this page', go: 'Switch to', note: 'Your choice is saved in this browser. You can change it anytime in the language menu.' },
  }[current];
  function offer(language, source) {
    if (!valid(language) || language === current || manuallyChosen) return;
    const dialog = document.createElement('dialog');
    dialog.className = 'locale-dialog';
    dialog.setAttribute('aria-labelledby', 'locale-title');
    dialog.setAttribute('aria-describedby', 'locale-description');
    // All text is assigned via textContent; navigation is restricted to known local paths.
    const icon = document.createElement('img'); icon.src = '/assets/app-icon-vm-package.png'; icon.alt = ''; icon.width = 64; icon.height = 64;
    const title = document.createElement('h2'); title.id = 'locale-title'; title.textContent = copy.title;
    const message = document.createElement('p'); message.id = 'locale-description'; message.textContent = `${copy[source]} ${names[language]}。 ${copy.question}`.replace('。 ', current === 'en' ? '. ' : '。');
    const note = document.createElement('p'); note.className = 'locale-note'; note.textContent = copy.note;
    const actions = document.createElement('div'); actions.className = 'locale-actions';
    const stay = document.createElement('button'); stay.type = 'button'; stay.className = 'button locale-stay'; stay.textContent = copy.stay; stay.autofocus = true;
    const go = document.createElement('a'); go.className = 'button'; go.textContent = `${copy.go} ${names[language]}`; go.hreflang = language;
    go.href = paths[language] + location.search + location.hash;
    const dismiss = () => { remember(current); dialog.close(); };
    stay.addEventListener('click', dismiss);
    dialog.addEventListener('cancel', event => { event.preventDefault(); dismiss(); });
    go.addEventListener('click', () => remember(language));
    dialog.addEventListener('close', () => dialog.remove(), { once: true });
    actions.append(stay, go); dialog.append(icon, title, message, actions, note); document.body.append(dialog);
    if (!dialog.showModal) { dialog.remove(); return; }
    dialog.showModal();
    // Reuse the site's motion system, including live Reduce Motion cancellation.
    if (typeof enter === 'function') enter(dialog, 6, 220);
  }
  function browserLanguage() {
    const language = (navigator.languages?.[0] || navigator.language || 'en').toLowerCase();
    if (/^zh(?:-|$)/.test(language)) {
      return /(?:^|-)hant(?:-|$)|(?:^|-)(tw|hk|mo)(?:-|$)/.test(language) ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }
  async function suggest() {
    const preferred = readPreference();
    if (preferred) { offer(preferred, 'preference'); return; }
    let language = null;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);
    try {
      const response = await fetch('/api/locale', { cache: 'no-store', signal: controller.signal });
      if (response.ok) { const data = await response.json(); if (valid(data.language)) language = data.language; }
    } catch { /* The page and language menu remain usable if detection fails. */ }
    finally { clearTimeout(timeout); }
    if (readPreference() || manuallyChosen) return;
    offer(language || browserLanguage(), language ? 'region' : 'browser');
  }
  suggest();
})();
