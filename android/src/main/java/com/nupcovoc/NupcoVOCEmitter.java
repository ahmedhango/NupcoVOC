package com.nupcovoc;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class NupcoVOCEmitter {
  private static ReactApplicationContext reactContext;

  public static void setContext(ReactApplicationContext ctx) {
    reactContext = ctx;
  }

  public static void emit(String action, String data) {
    if (reactContext == null) return;
    WritableMap map = Arguments.createMap();
    map.putString("action", action);
    if (data != null) map.putString("data", data);
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
      .emit("NupcoVOCEvent", map);
  }
}


