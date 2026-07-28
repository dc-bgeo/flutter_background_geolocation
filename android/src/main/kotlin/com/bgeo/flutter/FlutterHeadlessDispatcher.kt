package com.bgeo.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import com.bgeo.BGGeoHeadlessDispatcher
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import org.json.JSONObject

/**
 * Engine headless sink: boots (once) a background FlutterEngine on the Dart
 * dispatcher entrypoint and forwards events over com.bgeo/headless. Reached
 * both programmatically (plugin init) and via the manifest meta-data
 * com.bgeo.HEADLESS_DISPATCHER for processes where Flutter never loaded —
 * so it must keep a public no-arg constructor.
 */
class FlutterHeadlessDispatcher : BGGeoHeadlessDispatcher {

    override fun dispatch(context: Context, event: String, payload: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val dispatcherHandle = prefs.getLong(KEY_DISPATCHER, 0)
        val taskHandle = prefs.getLong(KEY_TASK, 0)
        if (dispatcherHandle == 0L || taskHandle == 0L) return  // nothing registered

        val eventMap = HashMap<String, Any?>(payload.toMap()).apply { put("name", event) }
        mainHandler.post {
            acquireWakeLock(context)
            pending.add(mapOf("taskHandle" to taskHandle, "event" to eventMap))
            if (backgroundEngine == null) bootEngine(context.applicationContext, dispatcherHandle)
            else if (isolateReady) flush()
        }
    }

    private fun bootEngine(appContext: Context, dispatcherHandle: Long) {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(appContext)
            loader.ensureInitializationComplete(appContext, null)
        }
        val callback = FlutterCallbackInformation.lookupCallbackInformation(dispatcherHandle)
        if (callback == null) {
            Log.w(TAG, "stale dispatcherHandle=$dispatcherHandle (app rebuilt?) — dropping headless queue")
            pending.clear()
            releaseWakeLock()
            appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
            return
        }
        val engine = FlutterEngine(appContext)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.bgeo/headless").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "headlessInit" -> { isolateReady = true; flush(); result.success(null) }
                    "headlessTaskFinished" -> { releaseWakeLock(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
        engine.dartExecutor.executeDartCallback(
            DartExecutor.DartCallback(appContext.assets, loader.findAppBundlePath(), callback)
        )
        backgroundEngine = engine
    }

    private fun flush() {
        val ch = channel ?: return
        while (pending.isNotEmpty()) ch.invokeMethod("headlessEvent", pending.removeAt(0))
    }

    private fun acquireWakeLock(context: Context) {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        (wakeLock ?: pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "bgeo:headless")
            .apply { setReferenceCounted(false) }.also { wakeLock = it })
            .acquire(WAKELOCK_TIMEOUT_MS)   // extends the timeout; a single release() is always safe
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.let { runCatching { it.release() } }
    }

    companion object {
        private const val TAG = "BGeoHeadless"
        private const val PREFS = "com.bgeo.flutter.headless"
        private const val KEY_DISPATCHER = "dispatcherHandle"
        private const val KEY_TASK = "taskHandle"
        private const val WAKELOCK_TIMEOUT_MS = 30_000L
        private val mainHandler = Handler(Looper.getMainLooper())
        private var backgroundEngine: FlutterEngine? = null
        private var channel: MethodChannel? = null
        private var isolateReady = false
        private val pending = mutableListOf<Map<String, Any?>>()
        private var wakeLock: PowerManager.WakeLock? = null

        fun storeHandles(context: Context, dispatcher: Long, task: Long) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putLong(KEY_DISPATCHER, dispatcher).putLong(KEY_TASK, task).apply()
        }
    }
}
