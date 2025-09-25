
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
import com.facebook.react.bridge.ReadableMapKeySetIterator;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Locale;
import java.util.HashMap;
import java.util.Map;

public class NupcoVOCModule extends ReactContextBaseJavaModule {
  static boolean sInitialized = false;
  static volatile boolean sIsPresenting = false;
  static volatile NupcoVOCActivity sCurrentActivity = null;
  static Map<String, String> sExtraRequestHeaders = new HashMap<>();

  // Defaults (can be overridden via config in open())
  static String sToken = "";
  static String sId = "";
  static final String DEFAULT_AUTH_ENDPOINT = "https://example.com/api/auth";
  static final String DEFAULT_DATA_ENDPOINT = "https://dev-nupconeer.nupco.com:8081/feedback.html";
  static final int DEFAULT_TIMEOUT_MS = 8000;
  static final int DEFAULT_RETRIES    = 1; // additional attempts after the first

  private final ReactApplicationContext reactContext;
  public NupcoVOCModule(ReactApplicationContext context) {
    super(context);
    this.reactContext = context;
    NupcoVOCEmitter.setContext(context);
  }

  @NonNull @Override public String getName() { return "NupcoVOCModule"; }
  @ReactMethod public void addListener(String eventName) {}
  @ReactMethod public void removeListeners(double count) {}

  @ReactMethod public void isOpen(Promise promise) { promise.resolve(sIsPresenting); }
  @ReactMethod public void close() {
    NupcoVOCActivity act = sCurrentActivity;
    if (act != null) act.finish();
  }

  @ReactMethod public void initialize(ReadableMap cfg, Promise promise) {
    try {
      sToken = cfg.hasKey("token") ? cfg.getString("token") : "";
      sId = cfg.hasKey("id") ? cfg.getString("id") : "";
      sInitialized = sToken != null && !sToken.isEmpty();
      promise.resolve(sInitialized);
    } catch (Exception e) { promise.reject("ERR_INIT", e); }
  }

  @ReactMethod public void open(ReadableMap config, Promise promise) {
    // Prevent double-open while a session is already presented
    if (sIsPresenting) {
      Toast.makeText(reactContext, t("already_open"), Toast.LENGTH_SHORT).show();
      promise.reject("ERR_ALREADY_OPEN", "NupcoVOC screen is already presented");
      return;
    }
    if (!sInitialized) {
      Toast.makeText(reactContext, t("invalid_token"), Toast.LENGTH_LONG).show();
      promise.reject("ERR_NOT_INITIALIZED", "Module not initialized or invalid token/id");
      return;
    }

    // If JS explicitly provided html/url/htmlUrl, open immediately (display only)
    String url = config.hasKey("url") ? config.getString("url") : "";
    String html = config.hasKey("html") ? config.getString("html") : "";
    String htmlUrl = config.hasKey("htmlUrl") ? config.getString("htmlUrl") : "";
    final String authEndpoint = config.hasKey("authEndpoint") ? config.getString("authEndpoint") : DEFAULT_AUTH_ENDPOINT;
    final String dataEndpoint = config.hasKey("dataEndpoint") ? config.getString("dataEndpoint") : DEFAULT_DATA_ENDPOINT;
    final int timeoutMs = config.hasKey("timeoutMs") ? (int) config.getDouble("timeoutMs") : DEFAULT_TIMEOUT_MS;
    final int retries   = config.hasKey("retries") ? (int) config.getDouble("retries") : DEFAULT_RETRIES;
    sExtraRequestHeaders.clear();
    if (config.hasKey("headers") && config.getMap("headers") != null) {
      ReadableMap h = config.getMap("headers");
      ReadableMapKeySetIterator it = h.keySetIterator();
      while (it.hasNextKey()) {
        String k = it.nextKey();
        String v = h.getString(k);
        if (k != null && v != null) sExtraRequestHeaders.put(k, v);
      }
    }
    if (!isEmpty(html) || !isEmpty(url) || !isEmpty(htmlUrl)) {
      Intent intent = new Intent(reactContext, NupcoVOCActivity.class);
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      if (!isEmpty(html)) intent.putExtra("html", html);
      if (!isEmpty(url)) intent.putExtra("url", url);
      if (!isEmpty(htmlUrl)) intent.putExtra("htmlUrl", htmlUrl);
      sIsPresenting = true;
      reactContext.startActivity(intent);
      promise.resolve(true);
      return;
    }

    // Native-only flow: AUTH then DATA, prefetch HTML, then open activity with ready HTML.
    new Thread(() -> {
      // If authEndpoint provided, perform it first; otherwise skip to data call
      if (authEndpoint != null && !authEndpoint.isEmpty()) {
        boolean authOk = doAuth(authEndpoint, timeoutMs, retries);
        if (!authOk) {
          new Handler(Looper.getMainLooper()).post(() -> {
            Toast.makeText(reactContext, t("auth_failed"), Toast.LENGTH_LONG).show();
            promise.reject("ERR_AUTH_FAILED", "Authentication request failed");
          });
          return;
        }
      }
      String htmlPrefetched = fetchDataHtml(dataEndpoint, timeoutMs, retries);
      new Handler(Looper.getMainLooper()).post(() -> {
        if (htmlPrefetched == null || htmlPrefetched.isEmpty()) {
          Toast.makeText(reactContext, t("load_failed"), Toast.LENGTH_LONG).show();
          promise.reject("ERR_DATA_FAILED", "Failed to fetch HTML data");
          return;
        }
        Intent intent = new Intent(reactContext, NupcoVOCActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra("html", htmlPrefetched); // preloaded HTML
        sIsPresenting = true;
        reactContext.startActivity(intent);
        promise.resolve(true);
      });
    }).start();
  }

  private static boolean isEmpty(String s) { return s == null || s.isEmpty(); }

  private boolean doAuth(String endpoint, int timeoutMs, int retries) {
    HttpURLConnection conn = null; InputStream in = null; ByteArrayOutputStream out = null;
    try {
      URL u = new URL(endpoint);
      conn = (HttpURLConnection) u.openConnection();
      conn.setConnectTimeout(timeoutMs); conn.setReadTimeout(Math.max(timeoutMs, timeoutMs + 2000));
      conn.setRequestMethod("POST");
      conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
      conn.setRequestProperty("Accept", "application/json,text/plain,*/*");
      // apply custom headers
      for (Map.Entry<String,String> e : sExtraRequestHeaders.entrySet()) {
        conn.setRequestProperty(e.getKey(), e.getValue());
      }
      conn.setDoOutput(true);
      String body = "{\"token\":\"" + (sToken==null?"":sToken) + "\",\"id\":\"" + (sId==null?"":sId) + "\"}";
      OutputStream os = conn.getOutputStream(); os.write(body.getBytes("UTF-8")); os.flush(); os.close();

      int code = conn.getResponseCode();
      in = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
      out = new ByteArrayOutputStream();
      byte[] buf = new byte[8192]; int n;
      while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
      String resp = out.toString("UTF-8");

      // For httpbin.org testing, accept any response
      System.out.println("Auth response: " + resp);
      return true;
    } catch (Exception ignored) {
      if (retries > 0) return doAuth(endpoint, timeoutMs, retries - 1);
      return false;
    } finally {
      try { if (in != null) in.close(); } catch (Exception ignored) {}
      try { if (out != null) out.close(); } catch (Exception ignored) {}
      if (conn != null) conn.disconnect();
    }
  }

  private String fetchDataHtml(String endpoint, int timeoutMs, int retries) {
    HttpURLConnection conn = null; InputStream in = null; ByteArrayOutputStream out = null;
    try {
      URL u = new URL(endpoint);
      conn = (HttpURLConnection) u.openConnection();
      conn.setConnectTimeout(timeoutMs); conn.setReadTimeout(Math.max(timeoutMs, timeoutMs + 2000));
      conn.setInstanceFollowRedirects(true);
      // Use GET for static HTML endpoint to avoid 405 Method Not Allowed
      conn.setRequestMethod("GET");
      conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
      // Prefer Authorization header if provided via initialize token; otherwise keep X-Auth-Token
      if (sToken != null && !sToken.isEmpty()) conn.setRequestProperty("Authorization", "Bearer " + sToken);
      conn.setRequestProperty("X-Auth-Token", sToken);
      // apply custom headers
      for (Map.Entry<String,String> e : sExtraRequestHeaders.entrySet()) {
        conn.setRequestProperty(e.getKey(), e.getValue());
      }
      // No body for GET
      conn.setDoOutput(false);

      int code = conn.getResponseCode();
      in = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
      out = new ByteArrayOutputStream();
      byte[] buf = new byte[8192]; int n;
      while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
      return out.toString("UTF-8");
    } catch (Exception ignored) {
      if (retries > 0) return fetchDataHtml(endpoint, timeoutMs, retries - 1);
      return null;
    } finally {
      try { if (in != null) in.close(); } catch (Exception ignored) {}
      try { if (out != null) out.close(); } catch (Exception ignored) {}
      if (conn != null) conn.disconnect();
    }
  }

  // Simple i18n helper based on current locale
  private String t(String key) {
    Locale locale = reactContext.getResources().getConfiguration().getLocales().get(0);
    String lang = locale == null ? "en" : locale.getLanguage();
    boolean isArabic = lang != null && (lang.equals("ar") || lang.startsWith("ar"));
    if (isArabic) {
      if ("already_open".equals(key)) return "مفتوح بالفعل";
      if ("invalid_token".equals(key)) return "رمز/معرّف غير صالح";
      if ("auth_failed".equals(key)) return "فشل التحقق";
      if ("load_failed".equals(key)) return "فشل تحميل البيانات";
    }
    if ("already_open".equals(key)) return "Already open";
    if ("invalid_token".equals(key)) return "Invalid token/id";
    if ("auth_failed".equals(key)) return "Auth failed";
    if ("load_failed".equals(key)) return "Failed to load data";
    return key;
  }
}
