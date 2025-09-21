
package com.nupcovoc;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public final class NupcoVOCEmitter {
  private static ReactApplicationContext reactContext;
  private NupcoVOCEmitter() {}
  static void setContext(ReactApplicationContext ctx) { reactContext = ctx; }
  public static void emit(String action, @Nullable String data) {
    if (reactContext == null) return;
    WritableMap map = Arguments.createMap();
    map.putString("action", action == null ? "event" : action);
    if (data != null) map.putString("data", data); else map.putNull("data");
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
      .emit("NupcoVOCEvent", map);
  }
}
