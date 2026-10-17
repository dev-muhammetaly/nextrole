/* No analytics, advertising, or third-party scripts are loaded here. */
(() => {
  const key = 'nextrole.privacy.v1';
  let previousFocus;
  function close(choice) {
    try { localStorage.setItem(key, JSON.stringify({optional: choice, date: new Date().toISOString()})); } catch (_) { /* Storage may be blocked; keep browsing usable. */ }
    document.getElementById('privacy-notice')?.remove();
    previousFocus?.focus?.();
  }
  window.nextroleShowPrivacy = () => {
    if (document.getElementById('privacy-notice')) return;
    previousFocus = document.activeElement;
    const notice = document.createElement('section');
    notice.id = 'privacy-notice'; notice.className = 'privacy-dialog';
    notice.setAttribute('role', 'dialog'); notice.setAttribute('aria-labelledby', 'privacy-title');
    notice.innerHTML = '<h2 id="privacy-title">Your privacy, your choice.</h2><p>We use essential storage for account sessions and your preferences. No analytics or advertising trackers are installed. Optional storage is currently unused. <a href="/cookies.html">Read the storage policy</a>.</p><div class="actions"><button type="button" id="reject-optional">Essential only</button><button type="button" id="accept-optional">Allow optional</button></div>';
    document.body.append(notice);
    notice.querySelector('#reject-optional').onclick = () => close(false);
    notice.querySelector('#accept-optional').onclick = () => close(true);
    notice.querySelector('button').focus();
  };
  let saved;
  try { saved = JSON.parse(localStorage.getItem(key)); } catch (_) { saved = null; }
  if (!saved || typeof saved.optional !== 'boolean') window.nextroleShowPrivacy();
  document.querySelectorAll('[data-privacy]').forEach(button => button.addEventListener('click', window.nextroleShowPrivacy));
  document.querySelectorAll('[data-share]').forEach(button => button.addEventListener('click', async () => {
    const status = document.getElementById('share-status');
    try {
      if (navigator.share) await navigator.share({title:'Nextrole', text:'Find work that feels like you — a portfolio demo.', url:location.origin + '/'});
      else { await navigator.clipboard.writeText(location.origin + '/'); status.textContent = 'Link copied. Ready to share.'; }
    } catch (error) { if (error.name !== 'AbortError') status.textContent = 'Copy the address from your browser to share this page.'; }
  }));
})();
