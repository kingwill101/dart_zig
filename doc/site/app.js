const root = document.body.dataset.root;
const menu = document.querySelector('.menu-button');
menu.addEventListener('click', () => {
  const open = document.body.classList.toggle('nav-open');
  menu.setAttribute('aria-expanded', String(open));
});
const input = document.querySelector('#search');
const results = document.querySelector('#search-results');
input.addEventListener('input', () => {
  results.replaceChildren();
  const query = input.value.trim().toLowerCase();
  results.hidden = !query;
  if (!query) return;
  const words = query.split(/\s+/);
  const matches = window.DOC_PAGES.filter(page => words.every(word =>
    (page.title + ' ' + page.text).toLowerCase().includes(word)))
    .sort((a, b) => Number(b.title.toLowerCase().includes(query)) - Number(a.title.toLowerCase().includes(query)))
    .slice(0, 8);
  for (const page of matches) {
    const link = document.createElement('a');
    link.href = root + page.path;
    const title = document.createElement('strong');
    title.textContent = page.title;
    const description = document.createElement('small');
    description.textContent = page.section;
    link.append(title, description);
    results.append(link);
  }
  if (!matches.length) {
    const message = document.createElement('p');
    message.textContent = 'No matching guide. Try signals, ownership, or generation.';
    results.append(message);
  }
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape') {
    results.hidden = true;
    document.body.classList.remove('nav-open');
    menu.setAttribute('aria-expanded', 'false');
  }
  if (event.key === '/' && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
    event.preventDefault(); input.focus();
  }
});
document.addEventListener('click', event => {
  if (!event.target.closest('.search-wrap')) results.hidden = true;
});
input.addEventListener('focus', () => {
  if (input.value.trim()) input.dispatchEvent(new Event('input'));
});
if (navigator.clipboard) for (const pre of document.querySelectorAll('pre')) {
  const code = pre.querySelector('code');
  if (!code) continue;
  const button = document.createElement('button');
  button.className = 'copy'; button.textContent = 'Copy';
  button.setAttribute('aria-label', 'Copy code snippet');
  button.addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(code.textContent); button.textContent = 'Copied'; }
    catch { button.textContent = 'Select to copy'; }
    setTimeout(() => button.textContent = 'Copy', 1800);
  });
  pre.append(button);
}
