package com.nupcovoc;

import android.app.Activity;
import android.graphics.Color;
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
    if (html != null && !html.isEmpty()) {
      webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    } else if (url != null && !url.isEmpty()) {
      webView.loadUrl(url);
    }

    root.addView(toolbar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    root.addView(webView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

    setContentView(root);
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


