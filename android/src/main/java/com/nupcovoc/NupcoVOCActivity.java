
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
import android.widget.ProgressBar;
import android.view.Gravity;
import android.graphics.drawable.GradientDrawable;

public class NupcoVOCActivity extends Activity {
  public static final String BRIDGE_NAME = "NupcoVOC";
  private WebView webView;
  private ProgressBar progressBar;

  @Override protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    NupcoVOCModule.sCurrentActivity = this;

    String url = getIntent().getStringExtra("url");
    String html = getIntent().getStringExtra("html");
    String htmlUrl = getIntent().getStringExtra("htmlUrl");

    LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setBackgroundColor(Color.WHITE);

    FrameLayout toolbar = new FrameLayout(this);
    // Add close button (X)
    android.widget.Button closeButton = new android.widget.Button(this);
    closeButton.setText("✕");
    closeButton.setTextSize(18);
    closeButton.setTextColor(android.graphics.Color.BLACK);
    closeButton.setBackgroundColor(android.graphics.Color.TRANSPARENT);
    closeButton.setOnClickListener(v -> {
      NupcoVOCEmitter.emit("cancel", null);
      finish();
    });
    FrameLayout.LayoutParams closeParams = new FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    closeParams.gravity = android.view.Gravity.TOP | android.view.Gravity.END;
    closeParams.setMargins(0, 16, 16, 0);
    toolbar.addView(closeButton, closeParams);

    webView = new WebView(this);
    configureWebView(webView);
    progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleLarge);
    FrameLayout progressHolder = new FrameLayout(this);
    progressHolder.addView(progressBar, new FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    progressHolder.setForegroundGravity(android.view.Gravity.CENTER);

    root.addView(toolbar, new LinearLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    FrameLayout content = new FrameLayout(this);
    content.addView(webView, new FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    content.addView(progressHolder, new FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    // floating close over web content too - removed
    root.addView(content, new LinearLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
    setContentView(root);
    NupcoVOCEmitter.emit("opened", null);

    if (html != null && !html.isEmpty()) {
      webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    } else if (url != null && !url.isEmpty()) {
      webView.loadUrl(url, NupcoVOCModule.sExtraRequestHeaders);
    } else if (htmlUrl != null && !htmlUrl.isEmpty()) {
      webView.loadUrl(htmlUrl, NupcoVOCModule.sExtraRequestHeaders);
    } else {
      webView.loadDataWithBaseURL(null, "", "text/html", "utf-8", null);
    }
  }

  @Override
  public void onBackPressed() {
    if (webView != null && webView.canGoBack()) {
      webView.goBack();
    } else {
      // Emit cancel event before closing
      NupcoVOCEmitter.emit("cancel", null);
      super.onBackPressed();
    }
  }

  @Override
  protected void onDestroy() {
    // Reset presenting flag and cleanup
    NupcoVOCModule.sIsPresenting = false;
    NupcoVOCEmitter.emit("closed", null);
    NupcoVOCModule.sCurrentActivity = null;
    if (webView != null) {
      try { ((ViewGroup) webView.getParent()).removeView(webView); } catch (Throwable ignored) {}
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
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) s.setSafeBrowsingEnabled(true);
    wv.setWebChromeClient(new WebChromeClient());
    wv.addJavascriptInterface(new JsBridge(), BRIDGE_NAME);
    wv.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) { return false; }
      @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
        if (progressBar != null) progressBar.setVisibility(android.view.View.VISIBLE);
      }
      @Override public void onPageFinished(WebView view, String url) {
        if (progressBar != null) progressBar.setVisibility(android.view.View.GONE);
        NupcoVOCEmitter.emit("loaded", null);
      }
      @Override public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
        if (progressBar != null) progressBar.setVisibility(android.view.View.GONE);
        NupcoVOCEmitter.emit("error", description);
      }
    });
  }

  class JsBridge {
    @JavascriptInterface public void onSubmit(String payload) { NupcoVOCEmitter.emit("submit", payload); finish(); }
    @JavascriptInterface public void onCancel() { NupcoVOCEmitter.emit("cancel", null); finish(); }
    @JavascriptInterface public void onEvent(String name, String data) { NupcoVOCEmitter.emit(name == null ? "event" : name, data); }
  }
}
