# Nupco VOC (React Native Native Module)

In-app VOC modal powered by a native WebView + JS bridge.

## Install

```bash
npm i nupco-voc
# or
yarn add nupco-voc
```

iOS:
```bash
cd ios && pod install && cd ..
```

## Usage

```ts
import NupcoVOC, { open, addListener } from 'nupco-voc';

const unsub = addListener(evt => {
  if (evt.action === 'submit') console.log('Submit:', evt.data);
  if (evt.action === 'cancel') console.log('Cancel');
});

await open({ htmlUrl: 'https://example.com/inline.html' });
// or open({ url: 'https://example.com' });
// or open({ html: '<!doctype html>...</html>' });

unsub();
```

## Android
- Activity `com.nupcovoc.NupcoVOCActivity` is declared in the library manifest.
- Min SDK 21, compile/target 34.
- Uses `addJavascriptInterface` with @JavascriptInterface (API 17+).

## iOS
- `NupcoVOC.podspec` links `WebKit` and `React-Core`.
- Bridge injected at DocumentStart, main-frame only.
- Removes message handler on close.
