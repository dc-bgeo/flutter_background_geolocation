#import "BGeoFlutterPlugin.h"
#import <BGeoCore/BGGeoEngine.h>
#import <BGeoCore/BGGeoLogger.h>

@implementation BGeoFlutterPlugin {
  FlutterEventSink _eventSink;
  NSMutableArray<NSArray *> *_pendingEvents;   // buffered until Dart listens, cap 64
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *methods =
      [FlutterMethodChannel methodChannelWithName:@"com.bgeo/methods"
                                  binaryMessenger:[registrar messenger]];
  BGeoFlutterPlugin *instance = [[BGeoFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:methods];
  FlutterEventChannel *events =
      [FlutterEventChannel eventChannelWithName:@"com.bgeo/events"
                                binaryMessenger:[registrar messenger]];
  [events setStreamHandler:instance];
}

- (instancetype)init {
  if (self = [super init]) {
    __weak BGeoFlutterPlugin *weakSelf = self;
    // Engine work runs on the main run loop (engine requirement: CLLocation
    // managers + NSTimers). Flutter platform channels already run on main.
    [BGGeoEngine shared].eventEmitter = ^(NSString *name, NSDictionary *body) {
      [weakSelf dispatchEvent:name body:body];
    };
  }
  return self;
}

- (void)dispatchEvent:(NSString *)name body:(NSDictionary *)body {
  @synchronized(self) {
    if (_eventSink == nil) {
      _pendingEvents = _pendingEvents ?: [NSMutableArray array];
      if (_pendingEvents.count < 64) [_pendingEvents addObject:@[ name, body ?: @{} ]];
      return;
    }
  }
  _eventSink(@{@"event" : name, @"params" : body ?: @{}});
}

- (FlutterError *)onListenWithArguments:(id)args eventSink:(FlutterEventSink)sink {
  NSArray<NSArray *> *queued;
  @synchronized(self) { _eventSink = sink; queued = [_pendingEvents copy]; _pendingEvents = nil; }
  for (NSArray *e in queued) [self dispatchEvent:e[0] body:e[1]];
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)args {
  @synchronized(self) { _eventSink = nil; }
  return nil;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  BGGeoEngine *engine = [BGGeoEngine shared];
  NSString *m = call.method;
  if ([m isEqualToString:@"ready"]) {
    [engine applyConfig:call.arguments];
    NSString *err = [engine licenseErrorCode];
    if (err) { result([FlutterError errorWithCode:err
        message:[NSString stringWithFormat:@"BGeo license check failed (%@)", err] details:nil]); return; }
    result([engine stateDictionary]);
  } else if ([m isEqualToString:@"setConfig"]) {
    [engine applyConfig:call.arguments];
    result([engine stateDictionary]);
  } else if ([m isEqualToString:@"start"]) {
    NSString *err = [engine licenseErrorCode];
    if (err) { result([FlutterError errorWithCode:err
        message:[NSString stringWithFormat:@"BGeo license check failed (%@)", err] details:nil]); return; }
    [engine startTracking];
    result([engine stateDictionary]);
  } else if ([m isEqualToString:@"stop"]) {
    [engine stopTracking]; result([engine stateDictionary]);
  } else if ([m isEqualToString:@"getState"]) {
    result([engine stateDictionary]);
  } else if ([m isEqualToString:@"changePace"]) {
    if ([engine changePace:[call.arguments boolValue]]) result(nil);
    else result([FlutterError errorWithCode:@"DISABLED"
        message:@"Cannot changePace while tracking is disabled" details:nil]);
  } else if ([m isEqualToString:@"getCurrentPosition"]) {
    [engine getCurrentPosition:call.arguments
                       resolve:^(NSDictionary *loc) { result(loc); }
                        reject:^(NSString *c, NSString *msg) {
                          result([FlutterError errorWithCode:c message:msg details:nil]); }];
  } else if ([m isEqualToString:@"watchPosition"]) {
    [engine startWatch:call.arguments];
    result(nil);
  } else if ([m isEqualToString:@"stopWatchPosition"]) {
    [engine stopWatch];
    result(nil);
  } else if ([m isEqualToString:@"requestPermission"]) {
    [engine requestPermission:^(NSInteger status) { result(@(status)); }
                        reject:^(NSString *c, NSString *msg) {
                          result([FlutterError errorWithCode:c message:msg details:nil]); }];
  } else if ([m isEqualToString:@"requestTemporaryFullAccuracy"]) {
    [engine requestTemporaryFullAccuracy:call.arguments
                               completion:^(NSInteger accuracy) { result(@(accuracy)); }];
  } else if ([m isEqualToString:@"getProviderState"]) {
    result([engine providerState]);
  } else if ([m isEqualToString:@"isPowerSaveMode"]) {
    result(@([engine isPowerSaveMode]));
  } else if ([m isEqualToString:@"getOdometer"]) {
    result(@([engine odometer]));
  } else if ([m isEqualToString:@"setOdometer"]) {
    [engine setOdometer:[call.arguments doubleValue]
                resolve:^(NSDictionary *loc) { result(loc); }
                 reject:^(NSString *c, NSString *msg) {
                   result([FlutterError errorWithCode:c message:msg details:nil]); }];
  } else if ([m isEqualToString:@"sync"]) {
    result([engine syncQueue]);
  } else if ([m isEqualToString:@"getLocations"]) {
    result([engine queuedLocations]);
  } else if ([m isEqualToString:@"destroyLocations"]) {
    result([engine destroyQueuedLocations]);
  } else if ([m isEqualToString:@"getCount"]) {
    result(@([engine pendingQueueCount]));
  } else if ([m isEqualToString:@"destroyLocation"]) {
    NSString *uuid = call.arguments;
    if ([engine destroyQueuedLocation:uuid]) {
      result(nil);
    } else {
      result([FlutterError errorWithCode:@"NOT_FOUND"
          message:[NSString stringWithFormat:@"No queued location with uuid %@", uuid] details:nil]);
    }
  } else if ([m isEqualToString:@"insertLocation"]) {
    [engine insertQueuedLocation:call.arguments];
    result(nil);
  } else if ([m isEqualToString:@"getAuthState"]) {
    result([engine authStateDictionary]);
  } else if ([m isEqualToString:@"log"]) {
    NSDictionary *args = call.arguments;
    NSNumber *level = args[@"level"];
    NSString *event = args[@"event"];
    NSString *message = args[@"message"];
    NSString *dataJson = args[@"dataJson"];
    [BGGeoLogger log:(NSInteger)[level doubleValue]
               event:(event.length ? event : @"app")
             message:(message.length ? message : nil)
                data:(dataJson.length ? dataJson : nil)
                 src:@"dart"];
    result(nil);
  } else if ([m isEqualToString:@"getLog"]) {
    NSInteger limit = [call.arguments integerValue];
    NSInteger capped = MAX(1, MIN(limit, 5000));
    result(@{ @"entries" : [engine logEntries:capped] });
  } else if ([m isEqualToString:@"destroyLog"]) {
    result(@([engine destroyLogs]));
  } else if ([m isEqualToString:@"uploadLog"]) {
    NSInteger pending = [engine pendingLogCount];
    [engine flushLogs];
    result(@(pending));
  } else if ([m isEqualToString:@"addGeofence"]) {
    NSDictionary *geofence = call.arguments;
    if (geofence == nil) {
      result([FlutterError errorWithCode:@"INVALID_GEOFENCE"
          message:@"expected {geofences: [...]}" details:nil]);
      return;
    }
    [self handleMethodCall:[FlutterMethodCall methodCallWithMethodName:@"addGeofences"
                                                              arguments:@{ @"geofences" : @[ geofence ] }]
                     result:result];
  } else if ([m isEqualToString:@"addGeofences"]) {
    NSDictionary *geofences = call.arguments;
    if (![geofences[@"geofences"] isKindOfClass:[NSArray class]]) {
      result([FlutterError errorWithCode:@"INVALID_GEOFENCE"
          message:@"expected {geofences: [...]}" details:nil]);
      return;
    }
    NSArray *list = geofences[@"geofences"];
    // The engine gates the license (returns the LICENSE_* code as the error string).
    NSString *error = [engine addGeofences:list];
    if (error) {
      result([FlutterError errorWithCode:error
          message:[NSString stringWithFormat:@"geofence request rejected (%@)", error] details:nil]);
      return;
    }
    result(nil);
  } else if ([m isEqualToString:@"removeGeofence"]) {
    [engine removeGeofence:call.arguments];
    result(nil);
  } else if ([m isEqualToString:@"removeGeofences"]) {
    [engine removeAllGeofences];
    result(nil);
  } else if ([m isEqualToString:@"getGeofences"]) {
    result(@{ @"geofences" : [engine geofences] });
  } else if ([m isEqualToString:@"geofenceExists"]) {
    result(@([engine geofenceExists:call.arguments]));
  } else if ([m isEqualToString:@"registerHeadlessTask"]) {
    result(nil);   // iOS: engine relaunches the full app natively; no headless isolate
  } else {
    result(FlutterMethodNotImplemented);
  }
}
@end
