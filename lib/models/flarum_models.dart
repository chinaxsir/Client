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
  final bool isPrimary; // 明确区分主标签和次标签
  final int? position; 
  final bool canStartDiscussion;

  FlarumTag({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.color,
    this.isPrimary = false,
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
    
    final pos = attrs['position'];
    bool hasPosition = false;
    
    // [核心修复：极高容错率判定！拦截 API 可能下发的所有形式的空位]
    if (pos is int) {
      hasPosition = true;
    } else if (pos is String && pos.trim().isNotEmpty && pos.trim().toLowerCase() != 'null') {
      hasPosition = true;
    } else if (pos != null && pos is! String) {
      hasPosition = true;
    }

    final hasParent = rels['parent'] != null && rels['parent']['data'] != null;
    final bool isChild = attrs['isChild'] == true || hasParent;
    
    // 只有明确包含 position 数字，且不是子节点的，才被认定为"主标签"
    final bool isPrimary = hasPosition && !isChild;

    return FlarumTag(
      id: item['id'].toString(),
      name: attrs['name'] ?? '',
      slug: attrs['slug'] ?? '',
      description: attrs['description'],
      color: attrs['color'],
      isPrimary: isPrimary, // 严格标识
      position: pos is int ? pos : null,
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
      
      final pos = attrs['position'];
      bool hasPosition = false;
      if (pos is int) {
        hasPosition = true;
      } else if (pos is String && pos.trim().isNotEmpty && pos.trim().toLowerCase() != 'null') {
        hasPosition = true;
      } else if (pos != null && pos is! String) {
        hasPosition = true;
      }

      tags[item['id'].toString()] = FlarumTag(
        id: item['id'].toString(),
        name: attrs['name'] ?? '',
        slug: attrs['slug'] ?? '',
        color: attrs['color'],
        isPrimary: hasPosition && attrs['isChild'] != true,
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
