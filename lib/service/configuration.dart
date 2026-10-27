import 'dart:io';

class BehConfig {
  // static String server = "http://61.7.199.180";

  // DEV Server
  static String server = "https://beh.devforu.link";

  // PRODUCTION Server
  // static String server = "http://172.16.10.40/";

  static String outsourceServer = "https://www.bangkokeyehospital.com";

  static String pathImage(String path) {
    return "${BehConfig.server}/bucket/static/public/$path";
  }

  static String https({required String service, required String path}) {
    // return "https://beh.devforu.link/$service/api/$path";
    return "$server/$service/api/$path";
  }

  /// `wss://beh.devforu.link/general-api/api/v3/websocket/{token}`
  static String webSocket({required String path}) {
    final base = server.replaceFirst(RegExp(r'^http'), 'ws');
    return "$base/${PortConfig.generalPort}/api/$path";
  }

  static String httpsOutsource({required String path}) {
    // return "https://beh.devforu.link/$service/api/$path";
    return "$outsourceServer/admin/api/$path";
  }

  static String outsourcePathImage(String path) {
    return "https://admin.bangkokeyehospital.com/storage/app/$path";
  }

  // static const token =
  //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6IkFudW4uViIsIkVNUCI6IkVNUDAwMDAyMSIsImV4cCI6MTcyMTg4MTQ5MywiYXBwX2lkIjoibmV3LWhpcyIsImlzcyI6ImF1dGhlbnRpY2F0aW9uLXNlcnZpY2UifQ.9_AQUsMHJpE0yWpe8V9t0tjjml-IqrkMvhVAKQ9FZy8";
}

class PortConfig {
  static const String patientPort = "patient-api";
  static const String hrPort = "hr-api";
  static const String medPort = "med-api";
  static const String pharmacyPort = "pharmacy-api";
  static const String financePort = "finance-api";
  static const String authPort = "auth-api";
  static const String customerPort = "customer-api";
  static const String generalPort = "general-api";
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) => true;
  }
}
