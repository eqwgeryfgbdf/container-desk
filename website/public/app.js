const tabs = [...document.querySelectorAll('[role="tab"]')];
const shot = document.getElementById('app-shot');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const animations = new Map();
let selection = 0;

function stopAnimation(element) {
  animations.get(element)?.cancel();
  animations.delete(element);
}
function enter(element, distance = 8, duration = 280, delay = 0) {
  stopAnimation(element);
  if (reducedMotion.matches || !element.animate) return;
  const animation = element.animate([
    { opacity: 0.3, transform: `translateY(${distance}px)` },
    { opacity: 1, transform: 'translateY(0)' }
  ], { duration, delay, easing: 'cubic-bezier(.22,1,.36,1)', fill: 'backwards' });
  animations.set(element, animation);
  animation.finished.then(() => {
    if (animations.get(element) === animation) animations.delete(element);
  }).catch(() => {}); // Rapid tab changes and reduced motion intentionally cancel animation.
}
reducedMotion.addEventListener('change', () => {
  if (reducedMotion.matches) {
    animations.forEach(animation => animation.cancel());
    animations.clear();
    document.body.classList.remove('motion-ready');
  }
});
function selectTab(tab) {
  if (tab.getAttribute('aria-selected') === 'true') return;
  const currentSelection = ++selection;
  stopAnimation(shot);
  tabs.forEach(item => { item.setAttribute('aria-selected', String(item === tab)); item.tabIndex = item === tab ? 0 : -1; });
  shot.src = tab.dataset.src;
  shot.alt = tab.dataset.alt;
  document.getElementById('full-shot').href = tab.dataset.src;
  document.getElementById('shot-panel').setAttribute('aria-labelledby', tab.id);
  // Only animate the decoded, most recently selected image; never delay selection.
  shot.decode().then(() => {
    if (selection === currentSelection) enter(shot);
  }).catch(() => {}); // A failed image must not leave the panel hidden or block other tabs.
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', event => {
    let next;
    if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
    if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;
    if (next !== undefined) { event.preventDefault(); tabs[next].focus(); selectTab(tabs[next]); }
  });
});
document.querySelectorAll('.faq details').forEach(details => {
  details.addEventListener('toggle', () => {
    const answer = details.querySelector('p');
    if (details.open) enter(answer, 4);
    else stopAnimation(answer);
  });
});
if ('IntersectionObserver' in window && !reducedMotion.matches) {
  document.body.classList.add('motion-ready');
  const observer = new IntersectionObserver(entries => entries.forEach(entry => {
    if (entry.isIntersecting) { entry.target.classList.add('shown'); observer.unobserve(entry.target); }
  }), { threshold: 0.08 });
  document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
}

// One entrance per visit; normal links remain immediately interactive.
document.querySelectorAll('.hero-logo, .hero > .eyebrow, .hero h1, .hero-intro, .hero-actions, .hero > .requirements').forEach((element, index) => {
  enter(element, 12, 520, index * 55);
});
const header = document.querySelector('.site-header');
if (header) {
  const updateHeader = () => header.classList.toggle('scrolled', window.scrollY > 24);
  addEventListener('scroll', updateHeader, { passive: true });
  updateHeader();
}
