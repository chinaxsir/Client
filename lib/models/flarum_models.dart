// 文件位置: lib/models/flarum_models.dart

class FlarumUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  FlarumUser({required this.id, required this.username, required this.displayName, this.avatarUrl});
}

class FlarumTag {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? color;
  final bool isChild; 
  final int? position; 
  // [核心修复4：新增发帖权限字段]
  final bool canStartDiscussion;

  FlarumTag({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.color,
    this.isChild = false,
    this.position,
    this.canStartDiscussion = true,
  });
}

class Discussion {
  final String id;
  final String title;
  final int commentCount;
  final DateTime createdAt;
  final FlarumUser? user;
  final FlarumUser? lastPostedUser;
  final DateTime? lastPostedAt;
  final List<FlarumTag> tags;

  Discussion({
    required this.id,
    required this.title,
    required this.commentCount,
    required this.createdAt,
    this.user,
    this.lastPostedUser,
    this.lastPostedAt,
    required this.tags,
  });
}

class DiscussionList {
  final List<Discussion> items;
  final bool hasMore;
  DiscussionList(this.items, this.hasMore);
}

FlarumUser parseUser(Map<String, dynamic> json, String baseUrl) {
  final attrs = json['data']?['attributes'] ?? {};
  String? avatar = attrs['avatarUrl'];
  if (avatar != null && avatar.startsWith('/')) {
    avatar = '$baseUrl$avatar';
  }
  return FlarumUser(
    id: json['data']['id'].toString(),
    username: attrs['username'] ?? 'Unknown',
    displayName: attrs['displayName'] ?? attrs['username'] ?? 'Unknown',
    avatarUrl: avatar,
  );
}

List<FlarumTag> parseTags(Map<String, dynamic> json) {
  final data = json['data'] as List<dynamic>? ?? [];
  return data.map((item) {
    final attrs = item['attributes'] ?? {};
    final rels = item['relationships'] ?? {};
    
    // [核心修复3 配合：通过分析父级关系，100% 准确地判断该标签是否属于二级子标签]
    final hasParent = rels['parent'] != null && rels['parent']['data'] != null;

    return FlarumTag(
      id: item['id'].toString(),
      name: attrs['name'] ?? '',
      slug: attrs['slug'] ?? '',
      description: attrs['description'],
      color: attrs['color'],
      // 只要包含父级关系，或者明确标记了 isChild，就一定是二级标签
      isChild: attrs['isChild'] == true || hasParent,
      position: attrs['position'] as int?,
      // 获取当前登录用户对该标签是否有发帖权限
      canStartDiscussion: attrs['canStartDiscussion'] ?? true,
    );
  }).toList();
}

DiscussionList parseDiscussionList(Map<String, dynamic> json, String baseUrl) {
  final data = json['data'] as List<dynamic>? ?? [];
  final included = json['included'] as List<dynamic>? ?? [];
  
  final Map<String, FlarumUser> users = {};
  final Map<String, FlarumTag> tags = {};

  for (var item in included) {
    if (item['type'] == 'users') {
      final attrs = item['attributes'] ?? {};
      String? avatar = attrs['avatarUrl'];
      if (avatar != null && avatar.startsWith('/')) avatar = '$baseUrl$avatar';
      users[item['id'].toString()] = FlarumUser(
        id: item['id'].toString(),
        username: attrs['username'] ?? '',
        displayName: attrs['displayName'] ?? attrs['username'] ?? '',
        avatarUrl: avatar,
      );
    } else if (item['type'] == 'tags') {
      final attrs = item['attributes'] ?? {};
      tags[item['id'].toString()] = FlarumTag(
        id: item['id'].toString(),
        name: attrs['name'] ?? '',
        slug: attrs['slug'] ?? '',
        color: attrs['color'],
        isChild: attrs['isChild'] == true,
      );
    }
  }

  final items = data.map((item) {
    final attrs = item['attributes'] ?? {};
    final rels = item['relationships'] ?? {};
    
    final userId = rels['user']?['data']?['id']?.toString();
    final lastUserId = rels['lastPostedUser']?['data']?['id']?.toString();
    
    final tagData = rels['tags']?['data'] as List<dynamic>? ?? [];
    final discussionTags = tagData
        .map((t) => tags[t['id'].toString()])
        .whereType<FlarumTag>()
        .toList();

    return Discussion(
      id: item['id'].toString(),
      title: attrs['title'] ?? '',
      commentCount: attrs['commentCount'] ?? 0,
      createdAt: DateTime.tryParse(attrs['createdAt'] ?? '') ?? DateTime.now(),
      user: userId != null ? users[userId] : null,
      lastPostedUser: lastUserId != null ? users[lastUserId] : null,
      lastPostedAt: attrs['lastPostedAt'] != null ? DateTime.tryParse(attrs['lastPostedAt']) : null,
      tags: discussionTags,
    );
  }).toList();

  final links = json['links'] ?? {};
  final hasMore = links['next'] != null;

  return DiscussionList(items, hasMore);
}
