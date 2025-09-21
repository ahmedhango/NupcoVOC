'use strict';

const { NativeEventEmitter, NativeModules } = require('react-native');

const Native = NativeModules.NupcoVOCModule;
if (!Native) {
  console.warn('[NupcoVOC] Native module not found. Did you run pod install / build android?');
}

const emitter = new NativeEventEmitter(Native);

// Legacy names (kept for backward-compat)
function openWebView(cfg = {}) {
  if (!Native || !Native.open) throw new Error('NupcoVOCModule.open not found');
  return Native.open(cfg);
}
function addWebViewListener(cb) {
  const sub = emitter.addListener('NupcoVOCEvent', cb);
  return () => sub.remove();
}

// Modern aliases
const open = openWebView;
const addListener = addWebViewListener;

// Default export includes both
const defaultExport = { openWebView, addWebViewListener, open, addListener };

module.exports = Object.assign({}, defaultExport, {
  default: defaultExport,
  openWebView,
  addWebViewListener,
  open,
  addListener
});
