/// Named route identifiers for the app shell.
///
/// Route generation lives in `app.dart` (it needs access to the shared
/// `AppServices`); this file is just the stable list of route names so screens
/// can navigate without string typos.
class AppRoutes {
  static const String mainMenu = '/';
  static const String levelSelect = '/levels';
  static const String freePlay = '/freeplay';
  static const String settings = '/settings';

  const AppRoutes._();
}
