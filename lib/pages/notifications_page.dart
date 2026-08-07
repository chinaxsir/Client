// 文件位置: lib/pages/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/pages/home_page.dart' show formatRelativeTime;

// [修改备注：新增全局的通知中心页面]
class NotificationsPage extends StatefulWidget {
  final ApiClient api;

  const NotificationsPage({super.key, required this.api});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _notifications = [];
  Map<String, dynamic> _usersMap = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await widget.api.getNotifications();
      final data = res['data'] as List<dynamic>? ?? [];
      final included = res['included'] as List<dynamic>? ?? [];
      
      final Map<String, dynamic> users = {};
      for (var item in included) {
        if (item['type'] == 'users') {
          users[item['id']] = item;
        }
      }

      if (mounted) {
        setState(() {
          _notifications = data;
          _usersMap = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '无法加载通知，请检查网络';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('通知中心', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: const Color(0xFFE5E5EA), height: 0.5),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_notifications.isEmpty) {
      return const Center(child: Text('暂无新通知', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, thickness: 0.5, color: Color(0xFFE5E5EA)),
      itemBuilder: (context, index) {
        final notice = _notifications[index];
        final attrs = notice['attributes'] ?? {};
        final rels = notice['relationships'] ?? {};
        
        final fromUserId = rels['fromUser']?['data']?['id'];
        final fromUser = fromUserId != null ? _usersMap[fromUserId] : null;
        
        final username = fromUser?['attributes']?['displayName'] ?? fromUser?['attributes']?['username'] ?? '某人';
        final avatarUrl = fromUser?['attributes']?['avatarUrl'];
        
        final contentType = attrs['contentType'] as String? ?? '未知';
        final isRead = attrs['isRead'] == true;
        final timeStr = attrs['createdAt'] as String?;
        final time = timeStr != null ? DateTime.tryParse(timeStr) : null;
        
        String actionText = '与你进行了互动';
        IconData actionIcon = Icons.notifications;
        Color iconColor = Colors.grey;

        if (contentType == 'postLiked') {
          actionText = '赞了你的帖子';
          actionIcon = Icons.thumb_up;
          iconColor = Colors.blue;
        } else if (contentType == 'postMentioned') {
          actionText = '在回复中提到了你';
          actionIcon = Icons.reply;
          iconColor = Colors.green;
        } else if (contentType == 'userMentioned') {
          actionText = '提到了你';
          actionIcon = Icons.alternate_email;
          iconColor = Colors.orange;
        } else if (contentType == 'newPost') {
          actionText = '发布了新回复';
          actionIcon = Icons.chat_bubble_outline;
          iconColor = Colors.purple;
        }

        return Container(
          color: isRead ? Colors.white : Colors.blue.withOpacity(0.03),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: avatarUrl != null ? NetworkImage(widget.api.baseUrl + avatarUrl.replaceAll(widget.api.baseUrl, '')) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(actionIcon, size: 10, color: iconColor),
                  ),
                ),
              ],
            ),
            title: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' $actionText'),
                ],
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                time != null ? formatRelativeTime(time) : '',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}
