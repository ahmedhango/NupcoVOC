# NupcoVOC (React Native) — v1.0.0
Native WebView modal + JS bridge for surveys (iOS/Android).

## Install
```
npm i NupcoVOC
cd ios && pod install && cd ..
```

## Usage (legacy names kept)
```ts
import NupcoVOC, { openWebView, addWebViewListener } from 'NupcoVOC';

const unsub = addWebViewListener(evt => { /* submit/cancel */ });
await openWebView({ url: 'https://example.com/inline.html' });
unsub();
```

## Modern aliases
```ts
import NupcoVOC, { open, addListener } from 'NupcoVOC';
```

## Config
- html?: string
- url?: string
- htmlUrl?: string
- useDefaultHtmlUrl?: boolean  // if true and no source provided → uses https://httpbin.org/html
