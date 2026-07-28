package com.bgeo.flutter

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.bgeo.BGGeoCallback
import com.bgeo.BGGeoEngine
import com.bgeo.BGGeoHttpStore
import com.bgeo.BGGeoLogger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject

/**
 * Android native bridge over the closed-source `com.bgeo` engine AAR. Ported
 * from the RN TurboModule `BackgroundGeolocationModule.kt`
 * (react-native/android/src/main/java/com/bgeo/rn/BackgroundGeolocationModule.kt):
 * `Promise` -> `MethodChannel.Result`, `ReadableMap` -> `Map` (via
 * JsonConverters' `.toJSONObject()`/`.toMap()`), `PermissionAwareActivity` ->
 * `ActivityCompat.requestPermissions` + `RequestPermissionsResultListener`.
 */
class BGeoFlutterPlugin :
    FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    // Buffered here (not delivered) while eventSink is null, i.e. a live Dart side with
    // no active EventChannel listener. Capped at 64, oldest-first, matching iOS
    // (BGeoFlutterPlugin.m _pendingEvents). Only ever touched on the main thread (see
    // onAttachedToEngine).
    private val pendingEvents = ArrayDeque<Map<String, Any?>>()
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) { // app foregrounded
            BGGeoLogger.foreground = true
            BGGeoHttpStore.flushLogs()
        }
        override fun onStop(owner: LifecycleOwner) { BGGeoLogger.foreground = false }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        contextRef = binding.applicationContext
        BGGeoEngine.init(binding.applicationContext)
        BGGeoEngine.headlessDispatcher = FlutterHeadlessDispatcher()
        methods = MethodChannel(binding.binaryMessenger, "com.bgeo/methods")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "com.bgeo/events")
        events.setStreamHandler(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(lifecycleObserver)

        // Attach the live emitter as soon as the plugin exists (matches iOS, whose
        // init sets [BGGeoEngine shared].eventEmitter immediately, and the RN
        // TurboModule -- BackgroundGeolocationModule.kt:73-77 -- which subscribes as
        // soon as the emit callback exists rather than lazily). With a live Dart side
        // but no active EventChannel listener, events now buffer (cap 64, see
        // pendingEvents) instead of being diverted to headless dispatch. Headless
        // routing only kicks in once the plugin itself detaches (onDetachedFromEngine),
        // i.e. the engine-only/killed-app process -- the intended path.
        BGGeoEngine.eventEmitter = { name, body ->
            mainHandler.post {
                val envelope = mapOf("event" to name, "params" to body.toMap())
                val sink = eventSink
                if (sink != null) {
                    sink.success(envelope)
                } else if (pendingEvents.size < 64) {
                    pendingEvents.addLast(envelope)
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Route subsequent events to the headless dispatcher.
        BGGeoEngine.eventEmitter = null
        ProcessLifecycleOwner.get().lifecycle.removeObserver(lifecycleObserver)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    // ---- EventChannel: sink attaches/detaches independently of the engine emitter,
    // which is set once in onAttachedToEngine (see above) ------------------------
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
        while (pendingEvents.isNotEmpty()) {
            sink.success(pendingEvents.removeFirst())
        }
    }

    override fun onCancel(arguments: Any?) {
        // Deliberately does NOT null BGGeoEngine.eventEmitter: that would re-divert
        // events to headless dispatch while the app process is still alive -- the exact
        // asymmetry with iOS this buffering fix removes. Just drop the sink; the
        // emitter above buffers subsequent events until the next onListen.
        eventSink = null
    }

    // ---- ActivityAware (permission chain needs an Activity) ----------------
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(permissionListener)
    }
    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    private fun resultCallback(result: MethodChannel.Result): BGGeoCallback = object : BGGeoCallback {
        override fun success(result2: JSONObject?) { mainHandler.post { result.success(result2?.toMap()) } }
        override fun error(code: String, message: String) {
            mainHandler.post { result.error(code, message, null) }
        }
    }

    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> { // RN ready(): applyConfig ->
                BGGeoEngine.applyConfig((call.arguments as? Map<*, *>)?.toJSONObject())
                BGGeoEngine.licenseErrorCode()?.let { // license gate ->
                    result.error(it, "BGeo license check failed ($it)", null); return
                }
                BGGeoEngine.resumeTrackingIfEnabled() // Transistor auto-resume
                result.success(BGGeoEngine.stateMap().toMap())
            }
            "setConfig" -> {
                BGGeoEngine.applyConfig((call.arguments as? Map<*, *>)?.toJSONObject())
                result.success(BGGeoEngine.stateMap().toMap())
            }
            "start" -> {
                BGGeoEngine.licenseErrorCode()?.let { // license gate like ready, then
                    result.error(it, "BGeo license check failed ($it)", null); return
                }
                BGGeoEngine.startTracking()
                result.success(BGGeoEngine.stateMap().toMap())
            }
            "stop" -> { BGGeoEngine.stopTracking(); result.success(BGGeoEngine.stateMap().toMap()) }
            "getState" -> result.success(BGGeoEngine.stateMap().toMap())
            "changePace" -> if (BGGeoEngine.changePace(call.arguments as Boolean)) result.success(null)
                            else result.error("DISABLED", "Cannot changePace while tracking is disabled", null)
            "getCurrentPosition" -> BGGeoEngine.getCurrentPosition((call.arguments as? Map<*, *>)?.toJSONObject(), resultCallback(result))
            "watchPosition" -> { BGGeoEngine.startWatch((call.arguments as? Map<*, *>)?.toJSONObject()); result.success(null) }
            "stopWatchPosition" -> { BGGeoEngine.stopWatch(); result.success(null) }
            "requestPermission" -> requestPermission(result) // full RN chain, see below
            "requestTemporaryFullAccuracy" -> result.success(0) // Android: always "full"
            "getProviderState" -> result.success(BGGeoEngine.providerState().toMap())
            "isPowerSaveMode" -> result.success(BGGeoEngine.isPowerSaveMode())
            "getOdometer" -> result.success(BGGeoEngine.currentOdometer())
            "setOdometer" -> BGGeoEngine.setOdometer((call.arguments as Number).toDouble(), resultCallback(result))
            "sync" -> BGGeoEngine.sync(resultCallback(result))
            "getLocations" -> BGGeoEngine.getLocations(resultCallback(result))
            "destroyLocations" -> BGGeoEngine.destroyLocations(resultCallback(result))
            "getCount" -> result.success(BGGeoEngine.pendingCount())
            "destroyLocation" -> if (BGGeoEngine.destroyLocation(call.arguments as String)) result.success(null)
                                 else result.error("NOT_FOUND", "No queued location with uuid ${call.arguments}", null)
            "insertLocation" -> {
                val location = call.arguments as? Map<*, *>
                if (location == null) {
                    result.error("INVALID_LOCATION", "expected a location object", null); return
                }
                BGGeoEngine.insertLocation(location.toJSONObject(), resultCallback(result))
            }
            "getAuthState" -> result.success(BGGeoEngine.authStateMap().toMap())
            "log" -> {
                val a = call.arguments as Map<*, *>
                BGGeoLogger.log(
                    level = (a["level"] as Number).toInt(),
                    event = (a["event"] as? String)?.ifEmpty { "app" } ?: "app",
                    message = (a["message"] as? String)?.ifEmpty { null },
                    data = (a["dataJson"] as? String)?.ifEmpty { null },
                    // `tag` is a logcat category not present in the RN/JS surface (added to the
                    // engine after that module was written) -- "BGGeo" mirrors the engine's own
                    // internal default (see error/warn/info/debug/verbose$default in the AAR).
                    tag = "BGGeo",
                    src = "dart",
                )
                result.success(null)
            }
            "getLog" -> getLog((call.arguments as Number).toInt(), result) // verbatim RN getLog body
            "destroyLog" -> result.success(com.bgeo.BGGeoDb.deleteAllLogs())
            "uploadLog" -> { val pending = BGGeoHttpStore.pendingLogCount(); BGGeoHttpStore.flushLogs(); result.success(pending) }
            "addGeofence" -> {
                val geofence = call.arguments as? Map<*, *>
                if (geofence == null) {
                    result.error("INVALID_GEOFENCE", "expected {geofences: [...]}", null); return
                }
                BGGeoEngine.addGeofences(org.json.JSONArray().put(geofence.toJSONObject()), resultCallback(result))
            }
            "addGeofences" -> {
                val args = call.arguments as? Map<*, *>
                val geofences = args?.get("geofences") as? List<*>
                if (geofences == null) { // shape-gate INVALID_GEOFENCE, then
                    result.error("INVALID_GEOFENCE", "expected {geofences: [...]}", null); return
                }
                BGGeoEngine.addGeofences(geofences.toJSONArray(), resultCallback(result))
            }
            "removeGeofence" -> BGGeoEngine.removeGeofence(call.arguments as String, resultCallback(result))
            "removeGeofences" -> BGGeoEngine.removeGeofences(resultCallback(result))
            "getGeofences" -> BGGeoEngine.getGeofences(resultCallback(result))
            "geofenceExists" -> BGGeoEngine.geofenceExists(call.arguments as String, object : BGGeoCallback {
                override fun success(result2: JSONObject?) { mainHandler.post { result.success(result2?.optBoolean("exists") ?: false) } }
                override fun error(code: String, message: String) { mainHandler.post { result.error(code, message, null) } }
            })
            "registerHeadlessTask" -> {
                val a = call.arguments as Map<*, *>
                FlutterHeadlessDispatcher.storeHandles(
                    contextRef!!, (a["dispatcherHandle"] as Number).toLong(), (a["taskHandle"] as Number).toLong())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- permission chain (verbatim port of RN lines 174-317) --------------
    // reactApplicationContext.currentActivity -> activityBinding?.activity;
    // PermissionAwareActivity.requestPermissions -> ActivityCompat.requestPermissions
    // (the Activity forwards its onRequestPermissionsResult to every listener
    // registered via ActivityPluginBinding.addRequestPermissionsResultListener,
    // which is how `permissionListener` below receives the result);
    // pendingPermissionPromise: Promise? -> pendingPermissionResult: MethodChannel.Result?.

    private val permissionListener =
        PluginRegistry.RequestPermissionsResultListener { requestCode, _, grantResults ->
            when (requestCode) {
                FINE_REQUEST -> {
                    val granted = grantResults.isNotEmpty() &&
                        grantResults.any { it == PackageManager.PERMISSION_GRANTED }
                    val activity = activityBinding?.activity
                    // Escalate to background ("Allow all the time") as a separate Android 10+ prompt.
                    if (granted && BGGeoEngine.wantsAlways() &&
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        !BGGeoEngine.hasBackground() && activity != null
                    ) {
                        ActivityCompat.requestPermissions(
                            activity,
                            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                            BACKGROUND_REQUEST,
                        )
                    } else {
                        requestActivityRecognitionOrFinish(activity)
                    }
                    true
                }
                BACKGROUND_REQUEST -> {
                    requestActivityRecognitionOrFinish(activityBinding?.activity)
                    true
                }
                ACTIVITY_RECOGNITION_REQUEST -> {
                    finishPermission()
                    true
                }
                else -> false
            }
        }

    /**
     * Activity Recognition is a separate Android 10+ runtime permission. Request it
     * as the final step of the chain; if already granted (or pre-Q) just finish.
     */
    private fun requestActivityRecognitionOrFinish(activity: Activity?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !BGGeoEngine.hasActivityRecognition() && activity != null
        ) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                ACTIVITY_RECOGNITION_REQUEST,
            )
        } else {
            finishPermission()
        }
    }

    private fun finishPermission() {
        // Permissions may have just been granted: if tracking was already requested
        // (enabled=true persisted by an earlier start() that bailed on the missing
        // permission), bring the service up now.
        BGGeoEngine.resumeTrackingIfEnabled()
        BGGeoEngine.emitProviderChange()
        maybeShowAuthorizationAlert()
        pendingPermissionResult?.success(BGGeoEngine.numericStatus())
        pendingPermissionResult = null
    }

    /**
     * Android counterpart of the iOS `locationAuthorizationAlert`: when the
     * permission flow ends with location services off or insufficient authorization,
     * show a dialog (same config strings) that routes the user to app Settings.
     * Honours `disableLocationAuthorizationAlert`.
     */
    private fun maybeShowAuthorizationAlert() {
        val alert = BGGeoEngine.locationAuthorizationAlert() ?: return
        if (BGGeoEngine.disableLocationAuthorizationAlert()) return
        val activity = activityBinding?.activity ?: return

        val sufficient =
            if (BGGeoEngine.wantsAlways()) BGGeoEngine.hasBackground() else BGGeoEngine.hasFineOrCoarse()
        val servicesEnabled = BGGeoEngine.locationServicesEnabled()
        val title: String = if (!servicesEnabled) {
            alert["titleWhenOff"] as? String ?: "Location access required"
        } else if (!sufficient) {
            alert["titleWhenNotEnabled"] as? String ?: "Location access required"
        } else {
            return // authorization is adequate -> nothing to show
        }

        val message = alert["instructions"] as? String ?: ""
        val cancel = alert["cancelButton"] as? String ?: "Cancel"
        val settings = alert["settingsButton"] as? String ?: "Settings"

        AlertDialog.Builder(activity)
            .setTitle(title)
            .setMessage(message)
            .setNegativeButton(cancel) { d, _ -> d.dismiss() }
            .setPositiveButton(settings) { d, _ ->
                d.dismiss()
                runCatching {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", activity.packageName, null),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                }
            }
            .setCancelable(false)
            .show()
    }

    private fun requestPermission(result: MethodChannel.Result) {
        // Resolve immediately only when EVERYTHING we need is granted — background
        // location AND activity recognition. (Resolving on background alone skipped
        // the ACTIVITY_RECOGNITION request, so the Physical Activity prompt never
        // appeared once location had been granted.)
        if (BGGeoEngine.hasBackground() && BGGeoEngine.hasActivityRecognition()) {
            BGGeoEngine.emitProviderChange()
            result.success(BGGeoEngine.numericStatus())
            return
        }

        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("0", "Cannot request permission: current activity is null", null)
            return
        }

        pendingPermissionResult = result
        // Start the chain at the first missing step so we still reach the
        // ACTIVITY_RECOGNITION request even when location was already granted.
        when {
            !BGGeoEngine.hasFineOrCoarse() -> ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                FINE_REQUEST,
            )
            BGGeoEngine.wantsAlways() &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                !BGGeoEngine.hasBackground() -> ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                BACKGROUND_REQUEST,
            )
            else -> requestActivityRecognitionOrFinish(activity)
        }
    }

    // getLog: verbatim port of RN lines 396-414 (BGGeoDb.newestLogs -> ISO-8601 map
    // list), resolving result.success(mapOf("entries" to entriesList)) directly
    // (no JSONObject/WritableMap round-trip needed on the Flutter side).
    private fun getLog(limit: Int, result: MethodChannel.Result) {
        val rows = com.bgeo.BGGeoDb.newestLogs(limit.coerceIn(1, 5000))
        val iso = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
            .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
        val entries = rows.map { row ->
            val entry = LinkedHashMap<String, Any?>()
            entry["ts"] = iso.format(java.util.Date(row.tsMs))
            entry["level"] = row.level
            entry["src"] = row.src
            entry["event"] = row.event
            row.message?.let { entry["message"] = it }
            row.data?.let { raw -> entry["data"] = runCatching { JSONObject(raw).toMap() }.getOrNull() ?: raw }
            entry
        }
        result.success(mapOf("entries" to entries))
    }

    companion object {
        private const val FINE_REQUEST = 0xB1
        private const val BACKGROUND_REQUEST = 0xB2
        private const val ACTIVITY_RECOGNITION_REQUEST = 0xB3
        private var contextRef: Context? = null
    }
}
