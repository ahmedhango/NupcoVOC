import {NativeEventEmitter, NativeModules} from "react-native";

export type OpenCfg = {
  html?: string;
  url?: string;
  htmlUrl?: string;
  headers?: Record<string, string>;
  authEndpoint?: string;
  dataEndpoint?: string;
  timeoutMs?: number;
  retries?: number;
};
export type VOCEvent = {action: string; data?: string | null};

const Native = NativeModules.NupcoVOCModule;
if (!Native)
  console.warn(
    "[NupcoVOC] Native module not found. Did you run pod install / build android?"
  );

const emitter = new NativeEventEmitter(Native);

export const openWebView = (cfg: OpenCfg = {}) => {
  if (!Native?.open) throw new Error("NupcoVOCModule.open not found");
  return Native.open(cfg);
};
export const addWebViewListener = (cb: (e: VOCEvent) => void) => {
  const sub = emitter.addListener("NupcoVOCEvent", cb);
  return () => sub.remove();
};

export const open = openWebView;
export const addListener = addWebViewListener;

export const initialize = (cfg: {token: string; id: string}) => {
  if (!Native?.initialize)
    throw new Error("NupcoVOCModule.initialize not found");
  return Native.initialize(cfg);
};

export const isOpen = async (): Promise<boolean> => {
  if (!Native?.isOpen) return false as any;
  return Native.isOpen();
};

export const close = () => {
  if (!Native?.close) return;
  Native.close();
};

const defaultExport = {
  openWebView,
  addWebViewListener,
  open,
  addListener,
  initialize,
  isOpen,
  close,
};
export default defaultExport;
