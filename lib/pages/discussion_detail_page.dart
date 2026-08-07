// 文件位置: lib/pages/discussion_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/models/flarum_models.dart';
import 'package:xsop_forum/pages/home_page.dart' show formatRelativeTime;
import 'package:xsop_forum/pages/editor_page.dart';
import 'package:xsop_forum/pages/login_page.dart';

class DiscussionDetailPage extends StatefulWidget {
  final ApiClient api;
  final Discussion discussion;

  const DiscussionDetailPage({
    super.key,
    required this.api,
    required this.discussion,
  });

  @override
  State<DiscussionDetailPage> createState() => _DiscussionDetailPageState();
}

class _DiscussionDetailPageState extends State<DiscussionDetailPage> {
  bool _isLoading = true;
  String? _error;
  
  List<dynamic> _posts = [];
  Map<String, dynamic> _usersMap = {};

  @override
  void initState() {
    super.initState();
    _loadDiscussionDetail();
  }

  Future<void> _loadDiscussionDetail() async {
    try {
      final data = await widget.api.getDiscussion(int.parse(widget.discussion.id));
      
      final included = data['included'] as List<dynamic>? ?? [];
      
      final Map<String, dynamic> users = {};
      final List<dynamic> postsList = [];

      for (var item in included) {
        if (item['type'] == 'users') {
          users[item['id']] = item;
        } else if (item['type'] == 'posts' && item['attributes']?['contentType'] == 'comment') {
          postsList.add(item);
        }
      }

      postsList.sort((a, b) {
        final aNum = a['attributes']['number'] as int? ?? 0;
        final bNum = b['attributes']['number'] as int? ?? 0;
        return aNum.compareTo(bNum);
      });

      setState(() {
        _usersMap = users;
        _posts = postsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '无法加载帖子详情，请检查网络';
        _isLoading = false;
      });
    }
  }

  // [修改备注：实现点赞逻辑（包含乐观 UI 更新，先变亮再请求接口，失败则回退）]
  Future<void> _toggleLike(int index) async {
    final isLoggedIn = await widget.api.isLoggedIn;
    if (!isLoggedIn) {
      _promptLogin();
      return;
    }

    final post = _posts[index];
    final postId = int.parse(post['id']);
    final attrs = post['attributes'] ?? {};
    
    final bool currentIsLiked = attrs['isLiked'] ?? false;
    final int currentLikesCount = attrs['likesCount'] ?? 0;

    // 乐观 UI 更新
    setState(() {
      _posts[index]['attributes']['isLiked'] = !currentIsLiked;
      _posts[index]['attributes']['likesCount'] = currentIsLiked ? currentLikesCount - 1 : currentLikesCount + 1;
    });

    try {
      await widget.api.likePost(postId, !currentIsLiked);
    } catch (e) {
      // 失败后回退 UI
      if (mounted) {
        setState(() {
          _posts[index]['attributes']['isLiked'] = currentIsLiked;
          _posts[index]['attributes']['likesCount'] = currentLikesCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
      }
    }
  }

  // [修改备注：实现举报弹窗逻辑]
  Future<void> _showReportDialog(int postId) async {
    final isLoggedIn = await widget.api.isLoggedIn;
    if (!isLoggedIn) {
      _promptLogin();
      return;
    }

    String selectedReason = 'spam';
    final detailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('举报该内容'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile(
                      title: const Text('垃圾广告'),
                      value: 'spam',
                      groupValue: selectedReason,
                      onChanged: (val) => setStateDialog(() => selectedReason = val.toString()),
                    ),
                    RadioListTile(
                      title: const Text('违规内容'),
                      value: 'inappropriate',
                      groupValue: selectedReason,
                      onChanged: (val) => setStateDialog(() => selectedReason = val.toString()),
                    ),
                    RadioListTile(
                      title: const Text('偏离主题'),
                      value: 'off_topic',
                      groupValue: selectedReason,
                      onChanged: (val) => setStateDialog(() => selectedReason = val.toString()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: detailController,
                      decoration: const InputDecoration(
                        hintText: '补充详细原因（选填）',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await widget.api.reportPost(postId, selectedReason, detailController.text);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('举报已提交，感谢您的反馈')));
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提交失败')));
                      }
                    }
                  },
                  child: const Text('提交'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // [修改备注：底部回复栏点击时，唤起新建的 EditorPage 回帖模式]
  void _openReplyEditor() async {
    final isLoggedIn = await widget.api.isLoggedIn;
    if (!isLoggedIn) {
      _promptLogin();
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorPage(
          api: widget.api,
          discussion: widget.discussion,
        ),
      ),
    );

    // 回帖成功后，自动刷新当前页面的楼层数据
    if (result == true) {
      setState(() => _isLoading = true);
      _loadDiscussionDetail();
    }
  }

  void _promptLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage(api: widget.api)),
    );
    if (result == true) {
      setState(() => _isLoading = true);
      _loadDiscussionDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.discussion.title, style: const TextStyle(fontSize: 16)),
      ),
      body: _buildBody(),
      // [修改备注：帖子底部的固定回复栏]
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
            ]
          ),
          child: InkWell(
            onTap: _openReplyEditor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('写下你的回复...', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final postId = int.parse(post['id']);
        final attrs = post['attributes'] ?? {};
        
        final userId = post['relationships']?['user']?['data']?['id'];
        final user = userId != null ? _usersMap[userId] : null;
        
        final username = user?['attributes']?['displayName'] ?? user?['attributes']?['username'] ?? '已注销';
        final avatarUrl = user?['attributes']?['avatarUrl'];
        final timeStr = attrs['createdAt'] as String?;
        final time = timeStr != null ? DateTime.tryParse(timeStr) : null;
        
        final htmlContent = attrs['contentHtml'] as String? ?? '';
        final isLiked = attrs['isLiked'] ?? false;
        final likesCount = attrs['likesCount'] ?? 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (time != null)
                          Text(formatRelativeTime(time), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('#${attrs['number']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              HtmlWidget(
                htmlContent,
                textStyle: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
              ),

              const SizedBox(height: 16),
              // [修改备注：渲染每个楼层底部的互动操作栏（点赞与举报）]
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => _toggleLike(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, 
                            size: 16, 
                            color: isLiked ? Colors.blue : Colors.grey
                          ),
                          if (likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text('$likesCount', style: TextStyle(color: isLiked ? Colors.blue : Colors.grey, fontSize: 13)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => _showReportDialog(postId),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.grey),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
