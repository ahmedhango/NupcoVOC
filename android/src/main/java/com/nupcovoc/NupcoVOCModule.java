package com.nupcovoc;

import android.content.Intent;

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

  @Override public String getName() { return "NupcoVOCModule"; }

  @ReactMethod
  public void open(ReadableMap config, Promise promise) {
    try {
      String url = config.hasKey("url") ? config.getString("url") : "";
      String html = config.hasKey("html") ? config.getString("html") : "";
      String htmlUrl = config.hasKey("htmlUrl") ? config.getString("htmlUrl") : "";
      Intent intent = new Intent(reactContext, NupcoVOCActivity.class);
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      intent.putExtra("url", url);
      intent.putExtra("html", html);
      intent.putExtra("htmlUrl", htmlUrl);
      reactContext.startActivity(intent);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject("ERR_OPEN", e);
    }
  }
}


