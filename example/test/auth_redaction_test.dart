/// onAuthorization's raw event carries `{success, accessToken, refreshToken}`
/// — live JWTs. This must never reach the Logs screen/bgeo.db//device/logs
/// verbatim.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:bgeo_background_geolocation_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redactAuthorizationLogData strips token values from the logged payload', () {
    final event = AuthorizationEvent(
      success: true,
      accessToken: 'ACCESS.SECRET.JWT',
      refreshToken: 'REFRESH_SECRET',
      raw: const {
        'success': true,
        'accessToken': 'ACCESS.SECRET.JWT',
        'refreshToken': 'REFRESH_SECRET',
      },
    );

    final redacted = redactAuthorizationLogData(event);

    expect(redacted, {'success': true, 'hasAccessToken': true, 'hasRefreshToken': true});
    expect(redacted.toString(), isNot(contains('ACCESS.SECRET.JWT')));
    expect(redacted.toString(), isNot(contains('REFRESH_SECRET')));
  });

  test('redactAuthorizationLogData reports false token presence when absent', () {
    final event = AuthorizationEvent(success: false, raw: const {'success': false});

    expect(redactAuthorizationLogData(event),
        {'success': false, 'hasAccessToken': false, 'hasRefreshToken': false});
  });
}
