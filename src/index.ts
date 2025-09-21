import { NativeEventEmitter, NativeModules } from 'react-native';

type Cfg = { html?: string; url?: string; htmlUrl?: string; useDefaultHtmlUrl?: boolean };
export type VOCEvent = { action: string; data?: string | null };

const Native = NativeModules.NupcoVOCModule;
if (!Native) {
  console.warn('[NupcoVOC] Native module not found. Did you run pod install / build android?');
}

const emitter = new NativeEventEmitter(Native);

export const open = (cfg: Cfg = {}) => {
  if (!Native?.open) throw new Error('NupcoVOCModule.open not found');
  return Native.open(cfg);
};

export const addListener = (cb: (e: VOCEvent) => void) => {
  const sub = emitter.addListener('NupcoVOCEvent', cb);
  return () => sub.remove();
};

export default { open, addListener };
