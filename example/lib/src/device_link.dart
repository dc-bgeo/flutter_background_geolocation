/// Link this install to a BGeo account using a registration code from the web
/// console, then point the SDK's native uploader at the demo server with JWT
/// auth (native refresh via refreshUrl survives killed-app uploads).
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_store.dart';

const _key = 'bgeo:link';
const _installUuidKey = 'bgeo:installUuid';

class StoredLink {
  final String serverUrl;
  final String deviceId;
  String accessToken;
  String refreshToken;
  final String installUuid;

  StoredLink({
    required this.serverUrl,
    required this.deviceId,
    required this.accessToken,
    required this.refreshToken,
    required this.installUuid,
  });

  Map<String, Object?> toJson() => {
        'serverUrl': serverUrl,
        'deviceId': deviceId,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'installUuid': installUuid,
      };

  factory StoredLink.fromJson(Map<String, Object?> json) => StoredLink(
        serverUrl: json['serverUrl'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        installUuid: json['installUuid'] as String? ?? '',
      );
}

Future<String> _installUuid() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_installUuidKey);
  if (existing != null) return existing;
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rand = Random().nextInt(1 << 32).toRadixString(36);
  final fresh = '$stamp-$rand';
  await prefs.setString(_installUuidKey, fresh);
  return fresh;
}

Future<void> _applySdkConfig(StoredLink link) async {
  await BackgroundGeolocation.setConfig(Config(
    url: '${link.serverUrl}/device/locations',
    autoSync: true,
    batchSync: true,
    maxBatchSize: 50,
    // Native logger upload endpoint; the level itself lives in baseConfig /
    // Settings overrides (so the Settings toggle survives re-linking).
    logUrl: '${link.serverUrl}/device/logs',
    authorization: Authorization(
      strategy: 'JWT',
      accessToken: link.accessToken,
      refreshToken: link.refreshToken,
      refreshUrl: '${link.serverUrl}/device/auth/refresh',
      refreshPayload: const {'refresh_token': '{refreshToken}'},
    ),
  ));
}

/// Restore a persisted link on app start (returns null when not linked).
Future<StoredLink?> restoreLink() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return null;
  final link = StoredLink.fromJson(jsonDecode(raw) as Map<String, Object?>);
  await _applySdkConfig(link);
  appStore.setLink(serverUrl: link.serverUrl, linked: true, deviceId: link.deviceId);
  return link;
}

/// Exchange a registration code for device tokens and configure the SDK.
Future<StoredLink> linkDevice(String serverUrl, String code) async {
  final uuid = await _installUuid();
  final res = await http.post(
    Uri.parse('$serverUrl/device/register'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({
      'code': code.trim(),
      'device': {
        'uuid': uuid,
        'model': Platform.isIOS ? 'iPhone' : 'Android',
        'platform': Platform.isIOS ? 'ios' : 'android',
        'osVersion': Platform.operatingSystemVersion,
        'appVersion': '0.0.1',
        'name': 'BGeoExample (${Platform.isIOS ? 'ios' : 'android'})',
      },
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    Object? body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    final detail = body is Map ? (body['detail'] ?? body['error']) : null;
    throw Exception(detail ?? 'register failed (${res.statusCode})');
  }
  final tokens = jsonDecode(res.body) as Map<String, Object?>;
  final link = StoredLink(
    serverUrl: serverUrl,
    deviceId: tokens['device_id'] as String? ?? '',
    accessToken: tokens['access_token'] as String? ?? '',
    refreshToken: tokens['refresh_token'] as String? ?? '',
    installUuid: uuid,
  );
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, jsonEncode(link.toJson()));
  await _applySdkConfig(link);
  appStore.setLink(serverUrl: serverUrl, linked: true, deviceId: link.deviceId);
  return link;
}

/// Persist rotated tokens surfaced by the native uploader (onAuthorization).
Future<void> persistRotatedTokens(AuthorizationEvent event) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return;
  final link = StoredLink.fromJson(jsonDecode(raw) as Map<String, Object?>);
  final access = event.accessToken;
  final refresh = event.refreshToken;
  if (access != null && access.isNotEmpty) link.accessToken = access;
  if (refresh != null && refresh.isNotEmpty) link.refreshToken = refresh;
  await prefs.setString(_key, jsonEncode(link.toJson()));
}

Future<void> unlinkDevice() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
  // NOTE: `Config.toMap()` omits nulls, so Dart cannot express RN's
  // `authorization: undefined` ("clear this key"). Empty strings are the closest
  // available signal; if that turns out not to clear native auth state the fix
  // belongs in the plugin, not here. See
  // docs/superpowers/specs/2026-07-28-flutter-example-console-design.md.
  await BackgroundGeolocation.setConfig(const Config(
    url: '',
    logUrl: '',
    authorization: Authorization(
      strategy: '',
      accessToken: '',
      refreshToken: '',
      refreshUrl: '',
    ),
  ));
  appStore.setLink(linked: false, clearDeviceId: true);
}

/// Current tokens for the JS-side history/geofence calls.
Future<StoredLink?> currentLink() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  return raw == null ? null : StoredLink.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

/// Authorized request against the linked demo server with one 401-refresh retry.
/// Returns parsed JSON, or null when not linked / the request failed.
Future<Map<String, Object?>?> deviceFetch(
  String path, {
  String method = 'GET',
  Object? body,
}) async {
  final link = await currentLink();
  if (link == null) return null;

  Future<http.Response> send(String token) {
    final uri = Uri.parse('${link.serverUrl}$path');
    final headers = {
      'content-type': 'application/json',
      'authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'PUT':
        return http.put(uri, headers: headers, body: encoded);
      case 'POST':
        return http.post(uri, headers: headers, body: encoded);
      default:
        return http.get(uri, headers: headers);
    }
  }

  try {
    var res = await send(link.accessToken);
    if (res.statusCode == 401) {
      final fresh = await refreshTokens();
      if (fresh == null) return null;
      res = await send(fresh.accessToken);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map ? decoded.map((k, v) => MapEntry(k.toString(), v)) : null;
  } catch (_) {
    return null;
  }
}

/// Mirror the SDK's geofence set to the console (snapshot replace).
Future<bool> putGeofences(List<Map<String, Object?>> geofences) async {
  final res = await deviceFetch('/device/geofences', method: 'PUT', body: {'geofences': geofences});
  return res != null;
}

/// Refresh helper shared with the history loader (Dart-side twin of the native
/// refresh cycle).
Future<StoredLink?> refreshTokens() async {
  final link = await currentLink();
  if (link == null) return null;
  final res = await http.post(
    Uri.parse('${link.serverUrl}/device/auth/refresh'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({'refresh_token': link.refreshToken}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) return null;
  final tokens = jsonDecode(res.body) as Map<String, Object?>;
  link.accessToken = tokens['access_token'] as String? ?? link.accessToken;
  link.refreshToken = tokens['refresh_token'] as String? ?? link.refreshToken;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, jsonEncode(link.toJson()));
  await _applySdkConfig(link);
  return link;
}
