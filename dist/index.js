'use strict';

const { NativeEventEmitter, NativeModules } = require('react-native');

const Native = NativeModules.NupcoVOCModule;
if (!Native) {
  console.warn('[NupcoVOC] Native module not found. Did you run pod install / build android?');
}

const emitter = new NativeEventEmitter(Native);

function openWebView(cfg = {}) {
  if (!Native || !Native.open) throw new Error('NupcoVOCModule.open not found');
  return Native.open(cfg);
}
function addWebViewListener(cb) {
  const sub = emitter.addListener('NupcoVOCEvent', cb);
  return () => sub.remove();
}

function initialize(cfg) {
  if (!Native || !Native.initialize) throw new Error('NupcoVOCModule.initialize not found');
  return Native.initialize(cfg || {});
}

const open = openWebView;
const addListener = addWebViewListener;

const defaultExport = { openWebView, addWebViewListener, open, addListener, initialize };

module.exports = Object.assign({}, defaultExport, {
  default: defaultExport,
  openWebView,
  addWebViewListener,
  open,
  addListener,
  initialize
});
