const status = document.querySelector('#status');
const fragment = new URLSearchParams(location.hash.slice(1));
const id = fragment.get('id') ?? '';
const submitToken = fragment.get('submit') ?? '';
const encodedKey = fragment.get('key') ?? '';
history.replaceState(null, '', location.pathname);

function decode(value) {
  const binary = atob(value.replaceAll('-', '+').replaceAll('_', '/'));
  return Uint8Array.from(binary, char => char.charCodeAt(0));
}
function encode(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

const valid = /^[A-Za-z0-9_-]{16,64}$/.test(id) &&
  /^[A-Za-z0-9_-]{32,128}$/.test(submitToken) &&
  /^[A-Za-z0-9_-]{43}$/.test(encodedKey);
if (!valid || !crypto.subtle) {
  status.textContent = 'This pairing code is invalid or this browser does not support secure pairing.';
  document.querySelectorAll('button').forEach(button => { button.disabled = true; });
} else {
  for (const form of document.querySelectorAll('form')) {
    form.addEventListener('submit', async event => {
      event.preventDefault();
      const button = form.querySelector('button');
      button.disabled = true;
      status.textContent = 'Encrypting and sending…';
      try {
        const key = await crypto.subtle.importKey('raw', decode(encodedKey), 'AES-GCM', false, ['encrypt']);
        const iv = crypto.getRandomValues(new Uint8Array(12));
        const details = new URLSearchParams(new FormData(form)).toString();
        const ciphertext = new Uint8Array(await crypto.subtle.encrypt(
          { name: 'AES-GCM', iv }, key, new TextEncoder().encode(details)));
        const response = await fetch(`/v1/pairing/${id}/submission`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${submitToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ iv: encode(iv), ciphertext: encode(ciphertext) }),
          credentials: 'omit', cache: 'no-store', referrerPolicy: 'no-referrer',
        });
        if (!response.ok) throw new Error('pairing_unavailable');
        form.reset();
        document.querySelectorAll('button').forEach(item => { item.disabled = true; });
        status.textContent = 'Sent. Confirm the source on your TV.';
      } catch {
        status.textContent = 'Pairing failed or expired. Scan a new code on your TV.';
        button.disabled = false;
      }
    });
  }
}
