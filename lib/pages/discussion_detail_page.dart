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

    setState(() {
      _posts[index]['attributes']['isLiked'] = !currentIsLiked;
      _posts[index]['attributes']['likesCount'] = currentIsLiked ? currentLikesCount - 1 : currentLikesCount + 1;
    });

    try {
      await widget.api.likePost(postId, !currentIsLiked);
    } catch (e) {
      if (mounted) {
        setState(() {
          _posts[index]['attributes']['isLiked'] = currentIsLiked;
          _posts[index]['attributes']['likesCount'] = currentLikesCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
      }
    }
  }

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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
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
      // [修改备注：强制页面背景为纯白，确保与主页风格统一]
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.discussion.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        // [修改备注：为导航栏底部增加一条极细的分割线，区分头部与正文]
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: const Color(0xFFE5E5EA), height: 0.5),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            // [修改备注：去除了厚重的阴影，改用干净的顶部分割线]
            border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
          ),
          child: InkWell(
            onTap: _openReplyEditor,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                // [修改备注：输入框背景使用更淡的灰色，显得更加现代]
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text('写下你的回复...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
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

    // [修改备注：将 ListView.builder 改为 ListView.separated，用极细的分割线代替原本楼层之间的巨大留白和卡片边距]
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _posts.length,
      separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
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
          // [修改备注：移除了 margin、borderRadius 和 boxShadow，让楼层扁平铺满屏幕]
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    // [修改备注：统一使用更淡的灰色作为无头像时的底色]
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.primary) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        if (time != null)
                          const SizedBox(height: 2),
                        if (time != null)
                          Text(formatRelativeTime(time), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('#${attrs['number']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
              
              const SizedBox(height: 12),
              
              HtmlWidget(
                htmlContent,
                textStyle: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => _toggleLike(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, 
                            size: 16, 
                            color: isLiked ? Theme.of(context).colorScheme.primary : Colors.grey.shade500
                          ),
                          if (likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text('$likesCount', style: TextStyle(color: isLiked ? Theme.of(context).colorScheme.primary : Colors.grey.shade500, fontSize: 13)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _showReportDialog(postId),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.grey.shade400),
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
