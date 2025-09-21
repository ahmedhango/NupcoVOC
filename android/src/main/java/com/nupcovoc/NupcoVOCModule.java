
package com.nupcovoc;

import android.content.Intent;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

public class NupcoVOCModule extends ReactContextBaseJavaModule {
  private final ReactApplicationContext reactContext;
  public NupcoVOCModule(ReactApplicationContext context) {
    super(context);
    this.reactContext = context;
    NupcoVOCEmitter.setContext(context);
  }
  @NonNull @Override public String getName() { return "NupcoVOCModule"; }
  @ReactMethod public void addListener(String eventName) {}
  @ReactMethod public void removeListeners(double count) {}
  @ReactMethod public void open(ReadableMap config, Promise promise) {
    try {
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
