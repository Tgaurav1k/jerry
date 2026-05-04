import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

// ─── Token storage ────────────────────────────────────────────────────────────

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _roleKey = 'user_role';
  static const _userIdKey = 'user_id';
  static const _deviceIdKey = 'device_id';

  final FlutterSecureStorage _store;
  const TokenStorage(this._store);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String userId,
  }) async {
    await Future.wait([
      _store.write(key: _accessKey, value: accessToken),
      _store.write(key: _refreshKey, value: refreshToken),
      _store.write(key: _roleKey, value: role),
      _store.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<String?> getAccessToken() => _store.read(key: _accessKey);
  Future<String?> getRefreshToken() => _store.read(key: _refreshKey);
  Future<String?> getRole() => _store.read(key: _roleKey);
  Future<String?> getUserId() => _store.read(key: _userIdKey);
  Future<String?> getDeviceId() => _store.read(key: _deviceIdKey);

  Future<void> saveDeviceId(String deviceId) =>
      _store.write(key: _deviceIdKey, value: deviceId);

  Future<void> clear() => _store.deleteAll();

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

// ─── Dio HTTP client with JWT interceptor ─────────────────────────────────────

class ApiClient {
  late final Dio _dio;
  final TokenStorage _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: '${Env.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final token = await _storage.getAccessToken();
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final resp = await _dio.fetch(opts);
              return handler.resolve(resp);
            } catch (e) {
              return handler.next(error);
            }
          }
          await _storage.clear();
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.getRefreshToken();
    final deviceId = await _storage.getDeviceId();
    if (refresh == null) return false;
    try {
      final resp = await Dio().post(
        '${Env.apiBaseUrl}/api/v1/auth/refresh',
        data: {
          'refreshToken': refresh,
          if (deviceId != null) 'deviceId': deviceId,
        },
      );
      final data = resp.data['data'];
      final role = await _storage.getRole();
      final userId = await _storage.getUserId();
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        role: role ?? '',
        userId: userId ?? '',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Dio get dio => _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    final resp = await _dio.get(path, queryParameters: params);
    return resp.data;
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final resp = await _dio.post(path, data: data);
    return resp.data;
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    final resp = await _dio.patch(path, data: data);
    return resp.data;
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    final resp = await _dio.put(path, data: data);
    return resp.data;
  }

  Future<dynamic> postForm(String path, FormData formData) async {
    final resp = await _dio.post(path, data: formData);
    return resp.data;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(storage);
});

// ─── Socket.IO client ─────────────────────────────────────────────────────────

class SocketService {
  io.Socket? _socket;
  final TokenStorage _storage;

  SocketService(this._storage);

  Future<io.Socket> connect() async {
    if (_socket != null && _socket!.connected) return _socket!;
    final token = await _storage.getAccessToken();
    _socket = io.io(
      Env.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );
    return _socket!;
  }

  io.Socket? get socket => _socket;
  void disconnect() { _socket?.disconnect(); _socket = null; }
  bool get isConnected => _socket?.connected ?? false;
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return SocketService(storage);
});
