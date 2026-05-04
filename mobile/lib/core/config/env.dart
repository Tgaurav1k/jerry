import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  // NestJS backend
  static String get apiBaseUrl => dotenv.get('API_BASE_URL', fallback: 'http://10.0.2.2:3000');
  static String get socketUrl  => dotenv.get('SOCKET_URL',   fallback: 'http://10.0.2.2:3000');

  static String get agoraAppId  => dotenv.get('AGORA_APP_ID', fallback: '');
  static String get environment => dotenv.get('ENVIRONMENT', fallback: 'development');
  static bool   get isDevelopment => environment.toLowerCase() == 'development';

  // Dev demo credentials (non-sensitive, dev only)
  static String get demoUserEmail      => dotenv.get('DEMO_USER_EMAIL',      fallback: '');
  static String get demoUserPassword   => dotenv.get('DEMO_USER_PASSWORD',   fallback: '');
  static String get demoLawyerEmail    => dotenv.get('DEMO_LAWYER_EMAIL',    fallback: '');
  static String get demoLawyerPassword => dotenv.get('DEMO_LAWYER_PASSWORD', fallback: '');
  static String get superadminEmail    => dotenv.get('SUPERADMIN_EMAIL',     fallback: '');
  static String get superadminPassword => dotenv.get('SUPERADMIN_PASSWORD',  fallback: '');
}
