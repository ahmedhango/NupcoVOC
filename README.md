# Nupco VOC (React Native)

Native WebView modal with a minimal JS bridge. Supports inline HTML, remote URLs, and a fully native flow (AUTH → DATA → HTML) on both Android and iOS.

## 1) Installation

```bash
npm i nupco-voc
# or
yarn add nupco-voc
```

iOS pods:
```bash
cd ios && pod install && cd ..
```

Requirements:
- Android minSdk 21 (target/compile 34)
- iOS 12+

## 2) Quick start

```ts
import VOC, { open, addListener, initialize, isOpen, close } from 'nupco-voc';

// 1) Initialize once (store token/id natively for the native flow)
await initialize({ token: 'YOUR_TOKEN', id: 'YOUR_ID' });

// 2) Listen to events
const unsub = addListener(e => {
  switch (e.action) {
    case 'opened':
    case 'loaded':
      break;
    case 'error':
      console.log('VOC error:', e.data);
      break;
    case 'submit':
      console.log('Submitted payload:', e.data);
      break;
    case 'cancel':
    case 'closed':
      break;
  }
});

// 3) Open
await open({
  // Option A: Show existing content
  // url: 'https://example.com',
  // htmlUrl: 'https://example.com/inline.html',
  // html: '<!doctype html><html>...</html>',

  // Option B: Native flow (no url/html/htmlUrl)
  // The module will: optional AUTH → DATA (returns HTML) → present
  // authEndpoint: 'https://api.example.com/auth',
  // dataEndpoint: 'https://api.example.com/inline-html',

  headers: { Authorization: 'Bearer 123' },
  timeoutMs: 8000,
  retries: 1,
});

// Utilities
const opened = await isOpen();
if (opened) close();

// Cleanup
unsub();
```

## 3) API

### initialize(cfg)
- Input: `{ token: string; id: string }`
- Stores credentials natively for the native flow on both platforms.

### open(cfg)
```ts
{
  html?: string;                     // inline HTML string to display
  url?: string;                      // open a remote page in WebView
  htmlUrl?: string;                  // fetch remote HTML file and display
  headers?: Record<string,string>;   // applied to native requests + WebView loads
  authEndpoint?: string;             // optional AUTH (POST) in native flow
  dataEndpoint?: string;             // required for native flow; must return HTML
  timeoutMs?: number;                // request timeout (ms)
  retries?: number;                  // number of retries per request
}
```
Behavior:
- If any of `html | url | htmlUrl` is provided → displayed directly (headers applied when possible).
- Otherwise (native flow) → the module uses stored `token/id` to call `authEndpoint` (if set) then `dataEndpoint`, expects HTML, and presents it.

### addListener(cb)
Each event is `{ action: string, data?: string }`:
- `opened` when modal is presented
- `loaded` when WebView finishes loading
- `error` when WebView/network fails (reason in `data`)
- `submit` when the embedded page calls `NupcoVOC.onSubmit(payload)`
- `cancel` when `NupcoVOC.onCancel()` is called
- `closed` when modal is dismissed

### isOpen() → Promise<boolean>
Returns the current presentation state.

### close()
Programmatically dismisses the modal.

## 4) Headers & Auth
- `headers` are attached to:
  - Android/iOS native requests (AUTH/DATA) in the native flow
  - WebView requests for `url` and `htmlUrl`
- In native flow, the module also sends:
  - `Authorization: Bearer <token>` (from `initialize`) and `X-Auth-Token`
  - JSON body `{ token, id }` for `authEndpoint` and `{ id }` for `dataEndpoint`

## 5) Security & UX
- Android WebView hardened: file access disabled, file URL access restricted, SafeBrowsing on.
- Loading indicators and a floating close button on both platforms.
- Android supports hardware back to navigate within WebView.

## 6) Troubleshooting
- iOS: run `pod install` after installing the package.
- Call `initialize({ token, id })` before using the native flow.
- Ensure `dataEndpoint` returns a full HTML string.
- Use `addListener` and watch for `error` events for diagnostics.

## 7) License
MIT
