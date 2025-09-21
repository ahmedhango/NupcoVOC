import { NativeEventEmitter, NativeModules } from 'react-native';

type Cfg = { html?: string; url?: string; htmlUrl?: string; useDefaultHtmlUrl?: boolean };
export type VOCEvent = { action: string; data?: string | null };

const Native = NativeModules.NupcoVOCModule;
if (!Native) console.warn('[NupcoVOC] Native module not found. Did you run pod install / build android?');

const emitter = new NativeEventEmitter(Native);

// Legacy names (kept for backward-compat)
export const openWebView = (cfg: Cfg = {}) => {
  if (!Native?.open) throw new Error('NupcoVOCModule.open not found');
  return Native.open(cfg);
};
export const addWebViewListener = (cb: (e: VOCEvent) => void) => {
  const sub = emitter.addListener('NupcoVOCEvent', cb);
  return () => sub.remove();
};

// Modern aliases
export const open = openWebView;
export const addListener = addWebViewListener;

// Default export includes both
const defaultExport = { openWebView, addWebViewListener, open, addListener };
export default defaultExport;
