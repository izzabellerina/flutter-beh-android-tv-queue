// ═══════════════════════════════════════════════════════════════════
// COMPLETE CHECKED
// ═══════════════════════════════════════════════════════════════════

class LoginModel {
  Map data;

  LoginModel({this.data = const {}});

  String get token => data['token'] ?? '';

  DateTime get expiredAt =>
      DateTime.tryParse(data['expired_at'] ?? '') ?? DateTime(1970);

  String get provider => data['provider'] ?? '';

  String get appId => data['app_id'] ?? '';

  void setLoginModel(Map data) {
    this.data = data;
  }
}
