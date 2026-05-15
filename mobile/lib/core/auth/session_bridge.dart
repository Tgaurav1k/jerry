/// Bridges [ApiClient] (no Riverpod ref) and widgets: reset socket + chat after
/// logout or auth failure so the next login reconnects with the correct JWT.
class SessionBridge {
  SessionBridge._();

  static void Function()? _onSessionCleared;

  static void register(void Function()? callback) {
    _onSessionCleared = callback;
  }

  static void notifySessionCleared() {
    _onSessionCleared?.call();
  }
}
