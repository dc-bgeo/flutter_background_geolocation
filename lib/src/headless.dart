import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'models.dart';

const MethodChannel _headlessChannel = MethodChannel('com.bgeo/headless');

/// Background-isolate entrypoint. Native (FlutterHeadlessDispatcher) boots a
/// background FlutterEngine on this function, then delivers events over
/// com.bgeo/headless. Payload: {taskHandle, event: {name, ...fields}}.
@pragma('vm:entry-point')
void headlessDispatcherEntry() {
  WidgetsFlutterBinding.ensureInitialized();
  _headlessChannel.setMethodCallHandler((call) async {
    if (call.method != 'headlessEvent') return;
    final args = call.arguments as Map;
    final handle = CallbackHandle.fromRawHandle(args['taskHandle'] as int);
    final task = PluginUtilities.getCallbackFromHandle(handle);
    if (task == null) return;
    final raw = (args['event'] as Map).map((k, v) => MapEntry(k.toString(), v));
    final name = raw.remove('name') as String? ?? '';
    await (task as HeadlessTask)(HeadlessEvent(name: name, params: raw));
    await _headlessChannel.invokeMethod('headlessTaskFinished');
  });
  // Tell native the isolate is ready so it can flush queued events.
  _headlessChannel.invokeMethod('headlessInit');
}

int dispatcherHandle() =>
    PluginUtilities.getCallbackHandle(headlessDispatcherEntry)!.toRawHandle();

int taskHandleOf(HeadlessTask task) {
  final h = PluginUtilities.getCallbackHandle(task);
  if (h == null) {
    throw ArgumentError(
        'registerHeadlessTask requires a top-level or static function '
        '(closures/instance methods cannot run in a killed-app isolate)');
  }
  return h.toRawHandle();
}
