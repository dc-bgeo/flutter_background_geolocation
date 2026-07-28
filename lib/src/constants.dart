// desiredAccuracy
const int desiredAccuracyNavigation = -2;
const int desiredAccuracyHigh = -1;
const int desiredAccuracyMedium = 10;
const int desiredAccuracyLow = 100;
const int desiredAccuracyVeryLow = 1000;
const int desiredAccuracyLowest = 3000;

// logLevel
const int logLevelOff = 0;
const int logLevelError = 1;
const int logLevelWarning = 2;
const int logLevelInfo = 3;
const int logLevelDebug = 4;
const int logLevelVerbose = 5;

// authorization status (onProviderChange.status) — 3 === Always
const int authorizationStatusNotDetermined = 0;
const int authorizationStatusRestricted = 1;
const int authorizationStatusDenied = 2;
const int authorizationStatusAlways = 3;
const int authorizationStatusWhenInUse = 4;

// accuracyAuthorization
const int accuracyAuthorizationFull = 0;
const int accuracyAuthorizationReduced = 1;

// license error codes (ready()/start() rejections in release builds)
const String licenseMissing = 'LICENSE_MISSING';
const String licenseInvalid = 'LICENSE_INVALID';
const String licenseExpired = 'LICENSE_EXPIRED';
const String licenseAppMismatch = 'LICENSE_APP_MISMATCH';

// activity types
const String activityTypeStill = 'still';
const String activityTypeOnFoot = 'on_foot';
const String activityTypeWalking = 'walking';
const String activityTypeRunning = 'running';
const String activityTypeOnBicycle = 'on_bicycle';
const String activityTypeInVehicle = 'in_vehicle';
const String activityTypeUnknown = 'unknown';
