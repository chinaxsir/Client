/// Flarum JSON:API 数据模型与解析
///
/// 将 Flarum 返回的 JSON:API 文档解析为强类型对象，
/// 并通过 `included` 资源表解析 relationships（作者、最后回复用户、标签）。

class FlarumUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const FlarumUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });
}

class FlarumTag {
  final String id;
  final String name;
  final String slug;
  final String? color;
  final String? description;

  const FlarumTag({
    required this.id,
    required this.name,
    required this.slug,
    this.color,
    this.description,
  });
}

class Discussion {
  final String id;
  final String title;
  final int commentCount;
  final int participantCount;
  final DateTime? createdAt;
  final DateTime? lastPostedAt;
  final FlarumUser? user; // 作者
  final FlarumUser? lastPostedUser; // 最后回复用户
  final List<FlarumTag> tags;
  final bool isSticky;
  final bool isLocked;

  const Discussion({
    required this.id,
    required this.title,
    required this.commentCount,
    required this.participantCount,
    required this.createdAt,
    required this.lastPostedAt,
    required this.user,
    required this.lastPostedUser,
    required this.tags,
    required this.isSticky,
    required this.isLocked,
  });
}

/// 帖子列表分页结果
class DiscussionList {
  final List<Discussion> items;
  final bool hasMore;

  const DiscussionList({required this.items, required this.hasMore});
}

// ---------------- 解析 ----------------

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// 将相对路径的 URL 拼接上 baseUrl
String _resolveUrl(String url, String baseUrl) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  if (url.startsWith('/')) return '$base$url';
  return '$base/$url';
}

FlarumUser _userFromResource(Map<String, dynamic> resource, String baseUrl) {
  final attrs = resource['attributes'] as Map<String, dynamic>? ?? const {};
  final username = attrs['username'] as String? ?? '';
  final avatar = attrs['avatarUrl'] as String?;
  return FlarumUser(
    id: resource['id'].toString(),
    username: username,
    displayName: attrs['displayName'] as String? ?? username,
    avatarUrl: avatar == null ? null : _resolveUrl(avatar, baseUrl),
  );
}

FlarumTag _tagFromResource(Map<String, dynamic> resource) {
  final attrs = resource['attributes'] as Map<String, dynamic>? ?? const {};
  return FlarumTag(
    id: resource['id'].toString(),
    name: attrs['name'] as String? ?? '',
    slug: attrs['slug'] as String? ?? '',
    color: attrs['color'] as String?,
    description: attrs['description'] as String?,
  );
}

/// 取某个 relationship 的 data（单个对象）
Map<String, dynamic>? _relationData(Map<String, dynamic> resource, String name) {
  final rels = resource['relationships'] as Map<String, dynamic>?;
  if (rels == null) return null;
  final r = rels[name] as Map<String, dynamic>?;
  if (r == null) return null;
  return r['data'] as Map<String, dynamic>?;
}

/// 解析帖子列表响应（JSON:API）
DiscussionList parseDiscussionList(Map<String, dynamic> json, String baseUrl) {
  final data = json['data'] as List? ?? const [];
  final includedRaw = json['included'] as List? ?? const [];
  final links = json['links'] as Map<String, dynamic>? ?? const {};
  final hasMore = links['next'] != null;

  // 构建 included 索引：'type:id' -> resource
  final included = <String, Map<String, dynamic>>{};
  for (final item in includedRaw) {
    final res = item as Map<String, dynamic>;
    included['${res['type']}:${res['id']}'] = res;
  }

  final discussions = <Discussion>[];
  for (final raw in data) {
    final resource = raw as Map<String, dynamic>;
    final attrs = resource['attributes'] as Map<String, dynamic>? ?? const {};

    // 作者
    FlarumUser? author;
    final userData = _relationData(resource, 'user');
    if (userData != null) {
      final res = included['users:${userData['id']}'];
      if (res != null) author = _userFromResource(res, baseUrl);
    }

    // 最后回复用户
    FlarumUser? lastUser;
    final lastData = _relationData(resource, 'lastPostedUser');
    if (lastData != null) {
      final res = included['users:${lastData['id']}'];
      if (res != null) lastUser = _userFromResource(res, baseUrl);
    }

    // 标签
    final tags = <FlarumTag>[];
    final tagsRel = resource['relationships']?['tags'] as Map<String, dynamic>?;
    final tagsData = tagsRel?['data'] as List?;
    if (tagsData != null) {
      for (final t in tagsData) {
        final td = t as Map<String, dynamic>;
        final res = included['tags:${td['id']}'];
        if (res != null) tags.add(_tagFromResource(res));
      }
    }

    discussions.add(Discussion(
      id: resource['id'].toString(),
      title: attrs['title'] as String? ?? '',
      commentCount: attrs['commentCount'] as int? ?? 0,
      participantCount: attrs['participantCount'] as int? ?? 0,
      createdAt: _parseDate(attrs['createdAt'] as String?),
      lastPostedAt: _parseDate(attrs['lastPostedAt'] as String?),
      user: author,
      lastPostedUser: lastUser,
      tags: tags,
      isSticky: attrs['isSticky'] as bool? ?? false,
      isLocked: attrs['isLocked'] as bool? ?? false,
    ));
  }

  return DiscussionList(items: discussions, hasMore: hasMore);
}

/// 解析全部标签列表（GET /api/tags）
List<FlarumTag> parseTags(Map<String, dynamic> json) {
  final data = json['data'] as List? ?? const [];
  return data.map((e) => _tagFromResource(e as Map<String, dynamic>)).toList();
}

/// 解析单个用户响应（GET /api/users/{id}）
FlarumUser parseUser(Map<String, dynamic> json, String baseUrl) {
  final data = json['data'] as Map<String, dynamic>? ?? const {};
  return _userFromResource(data, baseUrl);
}
