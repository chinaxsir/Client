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

  Future<Map<String, dynamic>> getForumInfo() async {
    final response = await _dio.get('/api');
    return _asMap(response.data);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<Map<String, dynamic>> login(String identification, String password) async {
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

    final response = await _dio.get('/api/discussions', queryParameters: query);
    return _asMap(response.data);
  }

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

  Future<Map<String, dynamic>> getTags() async {
    final response = await _dio.get('/api/tags');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getUser(int id) async {
    final response = await _dio.get('/api/users/$id');
    return _asMap(response.data);
  }

  // ==========================================
  // [修改备注：新增核心交互功能 API]
  // ==========================================

  /// 发帖 / 创建私密主题
  /// [tagIds] 必须传入至少一个标签的 ID
  /// [recipientUserIds] 如果传入了目标用户 ID，则利用 Byobu 插件创建私密主题
  Future<Map<String, dynamic>> createDiscussion({
    required String title,
    required String content,
    List<String>? tagIds,
    List<String>? recipientUserIds,
  }) async {
    final data = {
      "data": {
        "type": "discussions",
        "attributes": {
          "title": title,
          "content": content,
        },
        "relationships": <String, dynamic>{}
      }
    };

    if (tagIds != null && tagIds.isNotEmpty) {
      data["data"]!["relationships"]!["tags"] = {
        "data": tagIds.map((id) => {"type": "tags", "id": id}).toList()
      };
    }

    if (recipientUserIds != null && recipientUserIds.isNotEmpty) {
      data["data"]!["relationships"]!["recipientUsers"] = {
        "data": recipientUserIds.map((id) => {"type": "users", "id": id}).toList()
      };
    }

    final response = await _dio.post('/api/discussions', data: data);
    return _asMap(response.data);
  }

  /// 回帖 (回复某个主题)
  Future<Map<String, dynamic>> createPost(int discussionId, String content) async {
    final data = {
      "data": {
        "type": "posts",
        "attributes": {"content": content},
        "relationships": {
          "discussion": {
            "data": {"type": "discussions", "id": discussionId.toString()}
          }
        }
      }
    };
    final response = await _dio.post('/api/posts', data: data);
    return _asMap(response.data);
  }

  /// 点赞/取消点赞
  Future<void> likePost(int postId, bool isLiked) async {
    await _dio.patch('/api/posts/$postId', data: {
      "data": {
        "type": "posts",
        "id": postId.toString(),
        "attributes": {"isLiked": isLiked}
      }
    });
  }

  /// 举报帖子
  Future<void> reportPost(int postId, String reason, String? detail) async {
    await _dio.post('/api/flags', data: {
      "data": {
        "type": "flags",
        "attributes": {
          "reason": reason,
          "reasonDetail": detail ?? ""
        },
        "relationships": {
          "post": {
            "data": {"type": "posts", "id": postId.toString()}
          }
        }
      }
    });
  }

  /// 获取通知中心数据
  Future<Map<String, dynamic>> getNotifications() async {
    final response = await _dio.get('/api/notifications');
    return _asMap(response.data);
  }

  /// 小黑屋：封禁/解封用户 (需要管理员权限)
  Future<void> suspendUser(int userId, DateTime? suspendUntil, String? reason) async {
    await _dio.patch('/api/users/$userId', data: {
      "data": {
        "type": "users",
        "id": userId.toString(),
        "attributes": {
          "suspendUntil": suspendUntil?.toIso8601String(),
          "suspendMessage": reason
        }
      }
    });
  }

  // ==========================================

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  Future<bool> get isLoggedIn async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

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
