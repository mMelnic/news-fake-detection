class TempCredentials {
  static final TempCredentials _instance = TempCredentials._internal();

  factory TempCredentials() => _instance;

  TempCredentials._internal();

  String? email;
  String? password;

  void clear() {
    email = null;
    password = null;
  }
}