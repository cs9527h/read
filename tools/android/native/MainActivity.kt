package app.readen.read

import android.content.Context
import android.os.BatteryManager
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Reader-only hardware integration. Flutter controls exactly when the keys
 * are intercepted; outside the reader Android keeps normal volume behavior.
 * No dangerous permissions, background service, or global brightness change.
 */
class MainActivity : FlutterActivity() {
    private var volumePagingEnabled = false
    private var volumeEvents: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "read/volume_keys").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeEvents = null
                }
            }
        )

        MethodChannel(messenger, "read/device_control").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "setVolumePaging" -> {
                    volumePagingEnabled = call.argument<Boolean>("enabled") == true
                    result.success(null)
                }
                "getBatteryLevel" -> {
                    val battery = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val level = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    result.success(if (level in 0..100) level else null)
                }
                "setWindowBrightness" -> {
                    val value = call.argument<Double>("value")
                    if (value == null || !value.isFinite()) {
                        result.error("bad_brightness", "Brightness value missing", null)
                    } else {
                        val params = window.attributes
                        params.screenBrightness = if (value < 0) {
                            WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        } else {
                            value.toFloat().coerceIn(0.01f, 1f)
                        }
                        window.attributes = params
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (volumePagingEnabled &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
             keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            if (event.repeatCount == 0) {
                volumeEvents?.success(
                    if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down"
                )
            }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (volumePagingEnabled &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
             keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) return true
        return super.onKeyUp(keyCode, event)
    }

    override fun onDestroy() {
        volumePagingEnabled = false
        volumeEvents = null
        super.onDestroy()
    }
}
