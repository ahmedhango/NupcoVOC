export type OpenCfg = { html?: string; url?: string; htmlUrl?: string };
export type VOCEvent = { action: string; data?: string | null };

export declare function openWebView(cfg?: OpenCfg): Promise<any>;
export declare function addWebViewListener(cb: (e: VOCEvent) => void): () => void;
export declare function initialize(cfg: { token: string; id: string }): Promise<boolean>;

export declare const open: typeof openWebView;
export declare const addListener: typeof addWebViewListener;

declare const _default: {
  openWebView: typeof openWebView;
  addWebViewListener: typeof addWebViewListener;
  open: typeof openWebView;
  addListener: typeof addWebViewListener;
  initialize: typeof initialize;
};
export default _default;
