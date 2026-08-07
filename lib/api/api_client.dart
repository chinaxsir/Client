// 文件位置: lib/api/api_client.dart

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flarum 论坛 API 客户端
class ApiClient {
  static const String _tokenKey = 'flarum_token';
  static const String _userIdKey = 'flarum_user_id';

  final Dio _dio;
  final String baseUrl;

  ApiClient({this.baseUrl = 'https://xsop.de'}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // [修改备注：新增了 getForumInfo 方法，用于请求 /api 根目录，获取包含站点名称在内的论坛全局配置]
  /// 获取论坛全局信息（包含站点标题、描述等）
  Future<Map<String, dynamic>> getForumInfo() async {
    final response = await _dio.get('/api');
    return _asMap(response.data);
  }

  /// 读取持久化的 Bearer Token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 读取持久化的当前用户 ID
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  /// 用户登录
  Future<Map<String, dynamic>> login(
    String identification,
    String password,
  ) async {
    final response = await _dio.post('/api/token', data: {
      'identification': identification,
      'password': password,
    });
    final data = _asMap(response.data);
    final token = data['token'] as String?;
    final userId = data['userId'] as int?;
    if (token != null && token.isNotEmpty) {
      await _saveAuth(token, userId);
    }
    return data;
  }

  /// 获取首页帖子列表
  Future<Map<String, dynamic>> getDiscussions({
    int page = 1,
    int pageSize = 20,
    String? tag,
    String? sort,
  }) async {
    final query = <String, dynamic>{
      'page[number]': page,
      'page[size]': pageSize,
    };
    if (tag != null) query['filter[tag]'] = tag;
    if (sort != null) query['sort'] = sort;

    final response = await _dio.get(
      '/api/discussions',
      queryParameters: query,
    );
    return _asMap(response.data);
  }

  /// 获取帖子详情及回复
  Future<Map<String, dynamic>> getDiscussion(
    int id, {
    int page = 1,
    int pageSize = 20,
    String include = 'user,posts,posts.user',
  }) async {
    final response = await _dio.get(
      '/api/discussions/$id',
      queryParameters: {
        'page[number]': page,
        'page[size]': pageSize,
        'include': include,
      },
    );
    return _asMap(response.data);
  }

  /// 获取全部标签
  Future<Map<String, dynamic>> getTags() async {
    final response = await _dio.get('/api/tags');
    return _asMap(response.data);
  }

  /// 获取单个用户信息
  Future<Map<String, dynamic>> getUser(int id) async {
    final response = await _dio.get('/api/users/$id');
    return _asMap(response.data);
  }

  /// 退出登录，清除本地凭证
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  /// 是否已登录
  Future<bool> get isLoggedIn async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ---------- 内部工具方法 ----------
  Future<void> _saveAuth(String token, int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (userId != null) {
      await prefs.setInt(_userIdKey, userId);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
