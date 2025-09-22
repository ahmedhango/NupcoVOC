
package com.nupcovoc;

import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class NupcoVOCModule extends ReactContextBaseJavaModule {
  static boolean sInitialized = false;

  // Native-only config
  static final String TOKEN         = "1111";
  static final String ID            = "12";
  static final String AUTH_ENDPOINT = "https://example.com/api/auth";
  static final String DATA_ENDPOINT = "https://example.com/api/inline-html";

  private final ReactApplicationContext reactContext;
  public NupcoVOCModule(ReactApplicationContext context) {
    super(context);
    this.reactContext = context;
    NupcoVOCEmitter.setContext(context);
  }

  @NonNull @Override public String getName() { return "NupcoVOCModule"; }
  @ReactMethod public void addListener(String eventName) {}
  @ReactMethod public void removeListeners(double count) {}

  @ReactMethod public void initialize(ReadableMap cfg, Promise promise) {
    try {
      String token = cfg.hasKey("token") ? cfg.getString("token") : "";
      String id = cfg.hasKey("id") ? cfg.getString("id") : "";
      boolean ok = TOKEN.equals(token) && ID.equals(id);
      sInitialized = ok;
      promise.resolve(ok);
    } catch (Exception e) { promise.reject("ERR_INIT", e); }
  }

  @ReactMethod public void open(ReadableMap config, Promise promise) {
    if (!sInitialized) {
      Toast.makeText(reactContext, "Invalid token/id", Toast.LENGTH_LONG).show();
      promise.resolve(false);
      return;
    }

    // If JS explicitly provided html/url/htmlUrl, open immediately (display only)
    String url = config.hasKey("url") ? config.getString("url") : "";
    String html = config.hasKey("html") ? config.getString("html") : "";
    String htmlUrl = config.hasKey("htmlUrl") ? config.getString("htmlUrl") : "";
    if (!isEmpty(html) || !isEmpty(url) || !isEmpty(htmlUrl)) {
      Intent intent = new Intent(reactContext, NupcoVOCActivity.class);
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      if (!isEmpty(html)) intent.putExtra("html", html);
      if (!isEmpty(url)) intent.putExtra("url", url);
      if (!isEmpty(htmlUrl)) intent.putExtra("htmlUrl", htmlUrl);
      reactContext.startActivity(intent);
      promise.resolve(true);
      return;
    }

    // Native-only flow: AUTH then DATA, prefetch HTML, then open activity with ready HTML.
    new Thread(() -> {
      boolean authOk = doAuth();
      if (!authOk) {
        new Handler(Looper.getMainLooper()).post(() -> {
          Toast.makeText(reactContext, "Auth failed", Toast.LENGTH_LONG).show();
          promise.resolve(false);
        });
        return;
      }
      String htmlPrefetched = fetchDataHtml();
      new Handler(Looper.getMainLooper()).post(() -> {
        if (htmlPrefetched == null || htmlPrefetched.isEmpty()) {
          Toast.makeText(reactContext, "Failed to load data", Toast.LENGTH_LONG).show();
          promise.resolve(false);
          return;
        }
        Intent intent = new Intent(reactContext, NupcoVOCActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra("html", htmlPrefetched); // preloaded HTML
        reactContext.startActivity(intent);
        promise.resolve(true);
      });
    }).start();
  }

  private static boolean isEmpty(String s) { return s == null || s.isEmpty(); }

  private boolean doAuth() {
    HttpURLConnection conn = null; InputStream in = null; ByteArrayOutputStream out = null;
    try {
      URL u = new URL(AUTH_ENDPOINT);
      conn = (HttpURLConnection) u.openConnection();
      conn.setConnectTimeout(8000); conn.setReadTimeout(10000);
      conn.setRequestMethod("POST");
      conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
      conn.setRequestProperty("Accept", "application/json,text/plain,*/*");
      conn.setDoOutput(true);
      String body = "{\"token\":\"" + TOKEN + "\",\"id\":\"" + ID + "\"}";
      OutputStream os = conn.getOutputStream(); os.write(body.getBytes("UTF-8")); os.flush(); os.close();

      int code = conn.getResponseCode();
      in = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
      out = new ByteArrayOutputStream();
      byte[] buf = new byte[8192]; int n;
      while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
      String resp = out.toString("UTF-8");

      if (resp == null) return false;
      if (resp.contains("تمام")) return true;
      if (resp.trim().equalsIgnoreCase("ok")) return true;
      // naive JSON check
      return resp.matches("(?s).*\\bok\\s*:\\s*true\\b.*") || resp.matches("(?s).*\\bstatus\\s*:\\s*\"?ok\"?.*");
    } catch (Exception ignored) {
      return false;
    } finally {
      try { if (in != null) in.close(); } catch (Exception ignored) {}
      try { if (out != null) out.close(); } catch (Exception ignored) {}
      if (conn != null) conn.disconnect();
    }
  }

  private String fetchDataHtml() {
    HttpURLConnection conn = null; InputStream in = null; ByteArrayOutputStream out = null;
    try {
      URL u = new URL(DATA_ENDPOINT);
      conn = (HttpURLConnection) u.openConnection();
      conn.setConnectTimeout(8000); conn.setReadTimeout(10000);
      conn.setInstanceFollowRedirects(true);
      conn.setRequestMethod("POST");
      conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
      conn.setRequestProperty("Content-Type", "application/json");
      conn.setRequestProperty("X-Auth-Token", TOKEN);
      conn.setDoOutput(true);
      String body = "{\"id\":\"" + ID + "\"}";
      OutputStream os = conn.getOutputStream(); os.write(body.getBytes("UTF-8")); os.flush(); os.close();

      int code = conn.getResponseCode();
      in = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
      out = new ByteArrayOutputStream();
      byte[] buf = new byte[8192]; int n;
      while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
      return out.toString("UTF-8");
    } catch (Exception ignored) {
      return null;
    } finally {
      try { if (in != null) in.close(); } catch (Exception ignored) {}
      try { if (out != null) out.close(); } catch (Exception ignored) {}
      if (conn != null) conn.disconnect();
    }
  }
}
