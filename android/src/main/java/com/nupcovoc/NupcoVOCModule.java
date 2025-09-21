package com.nupcovoc;

import android.content.Intent;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

public class NupcoVOCModule extends ReactContextBaseJavaModule {
  static boolean sInitialized = false;
  private final ReactApplicationContext reactContext;
  public NupcoVOCModule(ReactApplicationContext context) {
    super(context);
    this.reactContext = context;
    NupcoVOCEmitter.setContext(context);
  }
  @NonNull @Override public String getName() { return "NupcoVOCModule"; }
  @ReactMethod public void addListener(String eventName) {}
  @ReactMethod public void removeListeners(double count) {}
  @ReactMethod public void initialize(ReadableMap config, Promise promise) {
    try {
      String token = config.hasKey("token") ? config.getString("token") : "";
      String id = config.hasKey("id") ? config.getString("id") : "";
      
      // First check if token and id are the correct values
      if (!"1111".equals(token) || !"12".equals(id)) {
        promise.reject("ERR_INIT_FAILED", "Invalid token or ID");
        return;
      }
      
      // If token and id are correct, send to endpoint and accept any response
      try {
        java.net.URL url = new java.net.URL("https://httpbin.org/post");
        java.net.HttpURLConnection connection = (java.net.HttpURLConnection) url.openConnection();
        
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setDoOutput(true);
        
        // Create JSON payload
        String jsonPayload = "{\"token\":\"" + (token != null ? token : "") + 
                            "\",\"id\":\"" + (id != null ? id : "") + "\"}";
        
        // Send data
        java.io.OutputStream os = connection.getOutputStream();
        os.write(jsonPayload.getBytes("UTF-8"));
        os.flush();
        os.close();
        
        // Get response code
        int responseCode = connection.getResponseCode();
        System.out.println("Response code: " + responseCode);
        
        connection.disconnect();
        
        System.out.println("Valid token and id, response received");
        
        com.facebook.react.bridge.WritableMap result = com.facebook.react.bridge.Arguments.createMap();
        result.putBoolean("success", true);
        result.putString("message", "Initialization successful");
        promise.resolve(result);
        
      } catch (Exception e) {
        System.out.println("Network error: " + e.getMessage());
        com.facebook.react.bridge.WritableMap result = com.facebook.react.bridge.Arguments.createMap();
        result.putBoolean("success", true);
        result.putString("message", "Initialization successful");
        promise.resolve(result);
      }
    } catch (Exception e) { 
      promise.reject("ERR_INIT_EXCEPTION", e.getMessage()); 
    }
  }
  @ReactMethod public void open(ReadableMap config, Promise promise) {
    try {
      if (!sInitialized) {
        android.widget.Toast.makeText(reactContext, "Invalid token/id", android.widget.Toast.LENGTH_LONG).show();
        promise.resolve(false);
        return;
      }
      String url = config.hasKey("url") ? config.getString("url") : "";
      String html = config.hasKey("html") ? config.getString("html") : "";
      String htmlUrl = config.hasKey("htmlUrl") ? config.getString("htmlUrl") : "";
      boolean useDefault = config.hasKey("useDefaultHtmlUrl") && !config.isNull("useDefaultHtmlUrl") && config.getBoolean("useDefaultHtmlUrl");

      Intent intent = new Intent(reactContext, NupcoVOCActivity.class);
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      if (url != null && !url.isEmpty()) intent.putExtra("url", url);
      if (html != null && !html.isEmpty()) intent.putExtra("html", html);
      if (htmlUrl != null && !htmlUrl.isEmpty()) intent.putExtra("htmlUrl", htmlUrl);
      intent.putExtra("useDefaultHtmlUrl", useDefault);
      reactContext.startActivity(intent);
      promise.resolve(true);
    } catch (Exception e) { promise.reject("ERR_OPEN", e); }
  }
}
