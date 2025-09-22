
package com.nupcovoc;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;

public class NupcoVOCActivity extends Activity {
  public static final String BRIDGE_NAME = "NupcoVOC";
  private WebView webView;

  @Override protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    String url = getIntent().getStringExtra("url");
    String html = getIntent().getStringExtra("html");
    String htmlUrl = getIntent().getStringExtra("htmlUrl");

    LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setBackgroundColor(Color.WHITE);

    FrameLayout toolbar = new FrameLayout(this);
    ImageButton close = new ImageButton(this);
    close.setImageResource(android.R.drawable.ic_menu_close_clear_cancel);
    close.setBackgroundColor(Color.TRANSPARENT);
    int pad = (int) (16 * getResources().getDisplayMetrics().density);
    close.setPadding(pad, pad, pad, pad);
    close.setOnClickListener(v -> finish());
    toolbar.addView(close, new FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

    webView = new WebView(this);
    configureWebView(webView);

    root.addView(toolbar, new LinearLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    root.addView(webView, new LinearLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
    setContentView(root);

    if (html != null && !html.isEmpty()) {
      webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    } else if (url != null && !url.isEmpty()) {
      webView.loadUrl(url);
    } else if (htmlUrl != null && !htmlUrl.isEmpty()) {
      webView.loadUrl(htmlUrl);
    } else {
      webView.loadDataWithBaseURL(null, "", "text/html", "utf-8", null);
    }
  }

  @SuppressLint({"SetJavaScriptEnabled"})
  private void configureWebView(WebView wv) {
    WebSettings s = wv.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setLoadWithOverviewMode(true);
    s.setUseWideViewPort(true);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) s.setSafeBrowsingEnabled(true);
    wv.setWebChromeClient(new WebChromeClient());
    wv.addJavascriptInterface(new JsBridge(), BRIDGE_NAME);
    wv.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) { return false; }
    });
  }

  class JsBridge {
    @JavascriptInterface public void onSubmit(String payload) { NupcoVOCEmitter.emit("submit", payload); finish(); }
    @JavascriptInterface public void onCancel() { NupcoVOCEmitter.emit("cancel", null); finish(); }
    @JavascriptInterface public void onEvent(String name, String data) { NupcoVOCEmitter.emit(name == null ? "event" : name, data); }
  }
}
