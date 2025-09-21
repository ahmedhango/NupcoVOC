package com.nupcovoc;

import android.app.Activity;
import android.graphics.Color;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;

public class NupcoVOCActivity extends Activity {
  public static final String BRIDGE_NAME = "NupcoVOC";

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    String url = getIntent().getStringExtra("url");
    String html = getIntent().getStringExtra("html");
    String htmlUrl = getIntent().getStringExtra("htmlUrl");
    if (htmlUrl == null || htmlUrl.isEmpty()) {
      // Native integration default source
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
    close.setOnClickListener(v -> finish());
    int pad = (int) (16 * getResources().getDisplayMetrics().density);
    close.setPadding(pad, pad, pad, pad);
    toolbar.addView(close, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

    WebView webView = new WebView(this);
    WebSettings s = webView.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setLoadWithOverviewMode(true);
    s.setUseWideViewPort(true);
    webView.setWebChromeClient(new WebChromeClient());
    webView.addJavascriptInterface(new JsBridge(), BRIDGE_NAME);
    webView.setWebViewClient(new WebViewClient());
    // Always load HTML from native source instead of JS-provided html
    String nativeHtml = "<!doctype html><html><head><meta charset=\"utf-8\"/>"
      + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>"
      + "<title>Nupco VOC</title>"
      + "<style>body{font-family:sans-serif;padding:16px}button{padding:10px 16px;margin:8px;border:0;border-radius:6px}"
      + ".primary{background:#1976d2;color:#fff}.danger{background:#e53935;color:#fff}</style>"
      + "</head><body>"
      + "<h2>تقييم الخدمة</h2>"
      + "<p>برجاء إدخال تقييمك وتعليقك ثم اضغط إرسال.</p>"
      + "<label>التقييم (1-5): <input id=\"rating\" type=\"number\" min=\"1\" max=\"5\"/></label>"
      + "<br/><label>التعليق:<br/><textarea id=\"fb\" rows=\"4\" style=\"width:100%\"></textarea></label>"
      + "<div><button class=\"danger\" onclick=\"" + BRIDGE_NAME + ".onCancel()\">إلغاء</button>"
      + "<button class=\"primary\" onclick=\"(function(){var r=document.getElementById('rating').value;var t=document.getElementById('fb').value;"
      + "var p=JSON.stringify({rating:r,feedback:t,timestamp:Date.now()});" + BRIDGE_NAME + ".onSubmit(p)})()\">إرسال</button></div>"
      + "</body></html>";
    if (htmlUrl != null && !htmlUrl.isEmpty()) {
      new FetchHtmlTask(webView, nativeHtml).execute(htmlUrl);
    } else {
      webView.loadDataWithBaseURL(null, nativeHtml, "text/html", "utf-8", null);
    }

    root.addView(toolbar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    root.addView(webView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

    setContentView(root);
  }

  static class FetchHtmlTask extends AsyncTask<String, Void, String> {
    private final WebView webView;
    private final String fallback;

    FetchHtmlTask(WebView webView, String fallback) {
      this.webView = webView;
      this.fallback = fallback;
    }

    @Override protected String doInBackground(String... urls) {
      java.io.InputStream in = null;
      java.io.ByteArrayOutputStream out = null;
      try {
        java.net.URL url = new java.net.URL(urls[0]);
        java.net.HttpURLConnection conn = (java.net.HttpURLConnection) url.openConnection();
        conn.setConnectTimeout(8000);
        conn.setReadTimeout(10000);
        conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        conn.connect();
        in = conn.getInputStream();
        out = new java.io.ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        return out.toString("UTF-8");
      } catch (Exception e) {
        return null;
      } finally {
        try { if (in != null) in.close(); } catch (Exception ignored) {}
        try { if (out != null) out.close(); } catch (Exception ignored) {}
      }
    }

    @Override protected void onPostExecute(String s) {
      String html = (s != null && !s.isEmpty()) ? s : fallback;
      webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    }
  }

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
      NupcoVOCEmitter.emit(name, data);
    }
  }
}


