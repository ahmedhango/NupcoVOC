
package com.nupcovoc;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class NupcoVOCActivity extends Activity {
  public static final String BRIDGE_NAME = "NupcoVOC";
  private WebView webView;

  @Override protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    String url = getIntent().getStringExtra("url");
    String html = getIntent().getStringExtra("html");
    String htmlUrl = getIntent().getStringExtra("htmlUrl");
    boolean useDefault = getIntent().getBooleanExtra("useDefaultHtmlUrl", false);
    if ((isEmpty(html) && isEmpty(url) && isEmpty(htmlUrl)) && useDefault) {
      htmlUrl = "https://httpbin.org/html";
    }

    LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setBackgroundColor(Color.WHITE);

    FrameLayout toolbar = new FrameLayout(this);
    toolbar.setBackgroundColor(Color.parseColor("#F5F5F5"));
    ImageButton close = new ImageButton(this);
    close.setImageResource(android.R.drawable.ic_menu_close_clear_cancel);
    close.setBackgroundColor(Color.TRANSPARENT);
    int pad = (int) (16 * getResources().getDisplayMetrics().density);
    close.setPadding(pad, pad, pad, pad);
    close.setOnClickListener(v -> finish());
    toolbar.addView(close, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

    webView = new WebView(this);
    configureWebView(webView);

    root.addView(toolbar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    root.addView(webView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
    setContentView(root);

    if (!isEmpty(html)) {
      webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    } else if (!isEmpty(url)) {
      webView.loadUrl(url);
    } else if (!isEmpty(htmlUrl)) {
      fetchAndLoadAsync(htmlUrl);
    } else {
      webView.loadDataWithBaseURL(null, "", "text/html", "utf-8", null);
    }
  }

  @Override public void onBackPressed() {
    if (webView != null && webView.canGoBack()) webView.goBack();
    else super.onBackPressed();
  }

  @Override protected void onDestroy() {
    if (webView != null) {
      ((ViewGroup) webView.getParent()).removeView(webView);
      webView.removeAllViews();
      webView.destroy();
      webView = null;
    }
    super.onDestroy();
  }

  private static boolean isEmpty(String s) { return s == null || s.isEmpty(); }

  @SuppressLint({"SetJavaScriptEnabled"})
  private void configureWebView(WebView wv) {
    WebSettings s = wv.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setLoadWithOverviewMode(true);
    s.setUseWideViewPort(true);
    s.setAllowFileAccess(false);
    s.setAllowContentAccess(true);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
      s.setAllowFileAccessFromFileURLs(false);
      s.setAllowUniversalAccessFromFileURLs(false);
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      s.setSafeBrowsingEnabled(true);
    }
    wv.setWebChromeClient(new WebChromeClient());
    wv.addJavascriptInterface(new JsBridge(), BRIDGE_NAME);
    wv.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) { return false; }
    });
  }

  private void fetchAndLoadAsync(final String url) {
    final Handler main = new Handler(Looper.getMainLooper());
    new Thread(() -> {
      String result = null;
      InputStream in = null; ByteArrayOutputStream out = null; HttpURLConnection conn = null;
      try {
        URL u = new URL(url);
        conn = (HttpURLConnection) u.openConnection();
        conn.setConnectTimeout(8000); conn.setReadTimeout(10000);
        conn.setInstanceFollowRedirects(true);
        conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        conn.connect();
        in = conn.getInputStream();
        out = new ByteArrayOutputStream();
        byte[] buf = new byte[8192]; int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        result = out.toString("UTF-8");
      } catch (Exception ignored) {
      } finally {
        try { if (in != null) in.close(); } catch (Exception ignored) {}
        try { if (out != null) out.close(); } catch (Exception ignored) {}
        if (conn != null) conn.disconnect();
      }
      final String html = (result != null && !result.isEmpty()) ? result : "";
      main.post(() -> { if (webView != null) webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null); });
    }).start();
  }

  class JsBridge {
    @JavascriptInterface public void onSubmit(String payload) { NupcoVOCEmitter.emit("submit", payload); finish(); }
    @JavascriptInterface public void onCancel() { NupcoVOCEmitter.emit("cancel", null); finish(); }
    @JavascriptInterface public void onEvent(String name, String data) { NupcoVOCEmitter.emit(name == null ? "event" : name, data); }
  }
}
