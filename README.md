# NupcoVOC (React Native) — v1.0.0

## Usage
```ts
import NupcoVOC, { initialize, openWebView, addWebViewListener } from 'NupcoVOC';

const ok = await initialize({ token: '1111', id: '12' });
if (ok) {
  const unsub = addWebViewListener(e => {
    if (e.action === 'submit') console.log('Submit', e.data);
  });
  await openWebView({ url: 'https://example.com/inline.html' });
  // هيظهر زر "Init Alert" جوّه الصفحة. لما تضغطه هيتطلع native alert.
  // ...
  unsub();
} else {
  Alert.alert('Error', 'Invalid token/id');
}
```
