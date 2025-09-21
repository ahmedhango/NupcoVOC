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

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    String url = getIntent().getStringExtra("url");
    String html = getIntent().getStringExtra("html");
    String htmlUrl = getIntent().getStringExtra("htmlUrl");

    // Build UI
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
    toolbar.addView(close, new FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
    ));

    webView = new WebView(this);
    configureWebView(webView);

    root.addView(toolbar, new LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    root.addView(webView, new LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
    ));
    setContentView(root);

    // Load content with precedence: html > url > htmlUrl > native fallback
    if (html != null && html.length() > 0) {
      webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    } else if (url != null && url.length() > 0) {
      webView.loadUrl(url);
    } else if (htmlUrl != null && htmlUrl.length() > 0) {
      fetchAndLoadAsync(htmlUrl, buildNativeHtml());
    } else {
      webView.loadDataWithBaseURL(null, buildNativeHtml(), "text/html", "utf-8", null);
    }
  }

  @Override
  public void onBackPressed() {
    if (webView != null && webView.canGoBack()) {
      webView.goBack();
    } else {
      super.onBackPressed();
    }
  }

  @Override
  protected void onDestroy() {
    if (webView != null) {
      // Proper WebView cleanup
      ((ViewGroup) webView.getParent()).removeView(webView);
      webView.removeAllViews();
      webView.destroy();
      webView = null;
    }
    super.onDestroy();
  }

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
      @Override
      public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        // Keep navigation inside WebView
        return false;
      }
    });
  }

  private String buildNativeHtml() {
    return "<!doctype html><html><head><meta charset=\\\"utf-8\\\"/>"
        + "<meta name=\\\"viewport\\\" content=\\\"width=device-width, initial-scale=1\\\"/>"
        + "<title>Nupco VOC</title>"
        + "<style>body{font-family:sans-serif;padding:16px}"
        + "button{padding:10px 16px;margin:8px;border:0;border-radius:6px}"
        + ".primary{background:#1976d2;color:#fff}.danger{background:#e53935;color:#fff}</style>"
        + "</head><body>"
        + "<h2>تقييم الخدمة</h2>"
        + "<p>برجاء إدخال تقييمك وتعليقك ثم اضغط إرسال.</p>"
        + "<label>التقييم (1-5): <input id=\\\"rating\\\" type=\\\"number\\\" min=\\\"1\\\" max=\\\"5\\\"/></label>"
        + "<br/><label>التعليق:<br/><textarea id=\\\"fb\\\" rows=\\\"4\\\" style=\\\"width:100%\\\"></textarea></label>"
        + "<div><button class=\\\"danger\\\" onclick=\\\"" + BRIDGE_NAME + ".onCancel()\\\">إلغاء</button>"
        + "<button class=\\\"primary\\\" onclick=\\\"(function(){var r=document.getElementById('rating').value;"
        + "var t=document.getElementById('fb').value;var p=JSON.stringify({rating:r,feedback:t,timestamp:Date.now()});"
        + BRIDGE_NAME + ".onSubmit(p)})()\\\">إرسال</button></div>"
        + "</body></html>";
  }

  private void fetchAndLoadAsync(final String url, final String fallbackHtml) {
    final Handler main = new Handler(Looper.getMainLooper());
    new Thread(() -> {
      String result = null;
      InputStream in = null;
      ByteArrayOutputStream out = null;
      HttpURLConnection conn = null;
      try {
        URL u = new URL(url);
        conn = (HttpURLConnection) u.openConnection();
        conn.setConnectTimeout(8000);
        conn.setReadTimeout(10000);
        conn.setInstanceFollowRedirects(true);
        conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        conn.connect();
        in = conn.getInputStream();
        out = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        result = out.toString("UTF-8");
      } catch (Exception ignored) {
      } finally {
        try { if (in != null) in.close(); } catch (Exception ignored) {}
        try { if (out != null) out.close(); } catch (Exception ignored) {}
        if (conn != null) conn.disconnect();
      }
      final String html = (result != null && result.length() > 0) ? result : fallbackHtml;
      main.post(() -> {
        if (webView != null) {
          webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
        }
      });
    }).start();
  }

  /** JS bridge exposed to the page */
  class JsBridge {
    @JavascriptInterface public void onSubmit(String payload) {
      NupcoVOCEmitter.emit("submit", payload);
      finish();
    }
    @JavascriptInterface public void onCancel() {
      NupcoVOCEmitter.emit("cancel", null);
      finish();
    }
    @JavascriptInterface public void onEvent(String name, String data) {
      NupcoVOCEmitter.emit(name == null ? "event" : name, data);
    }
  }
}
