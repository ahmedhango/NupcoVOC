# NupcoVOC v1.0.0 — Native-only Integration (JS Displays Only)

- **كل التكامل والـ endpoints ثابتة جوّه النيتف** (Android/iOS).
- الـ JS دوره يعرض بس (يفتح الـ WebView) أو يمرر `html/url/htmlUrl` لو حابب تعرض حاجة تانية.
- النيتف يعمل **AUTH → DATA** مسبقًا، وبعدين يفتح الويب فيو بالـ **HTML المحمّل** (بدون انتظار).

## Usage (JS)
```ts
import NupcoVOC, { initialize, openWebView, addWebViewListener } from 'NupcoVOC';

// لازم init ينجح عشان نفتح
const ok = await initialize({ token: '1111', id: '12' });
if (!ok) throw new Error('Invalid token/id');

// اسمع الايفينتس
const unsub = addWebViewListener(e => {
  if (e.action === 'submit') console.log('SUBMIT', e.data);
  if (e.action === 'cancel') console.log('CANCEL');
});

// بدون أي config: النيتف هيعمل AUTH→DATA ثم يفتح وبالفعل الصفحة محمّلة
await openWebView({});

// لو عايز، ممكن تمرّر html جاهز أو url/htmlUrl بدل الفلو الأصلي:
await openWebView({ html: '<h3>Custom</h3>' });
// أو
await openWebView({ url: 'https://example.com/page' });

unsub();
```

### تغيير الـ endpoints (داخل النيتف فقط)
- **Android:** `NupcoVOCModule.java` → `AUTH_ENDPOINT`, `DATA_ENDPOINT`, `TOKEN`, `ID`
- **iOS:** `NupcoVOCModule.m` → `kAuthEndpoint`, `kDataEndpoint`, `kToken`, `kID`

> مفيش أي إعدادات endpoints من الـ JS — كله ثابت جوّه النيتف.
