// 文件位置: lib/pages/home_page.dart

import 'package:flutter/material.dart';

import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/models/flarum_models.dart';

import 'package:xsop_forum/pages/discussion_detail_page.dart';
import 'package:xsop_forum/pages/user_profile_page.dart';

class HomePage extends StatefulWidget {
  final ApiClient api;
  final String baseUrl;

  const HomePage({
    super.key,
    required this.api,
    this.baseUrl = 'https://xsop.de',
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  final List<Discussion> _discussions = [];
  final List<FlarumTag> _allTags = [];
  FlarumUser? _currentUser;
  
  String _siteTitle = '加载中...';

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  String? _error;
  String? _selectedTagSlug;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadForumInfo();
    _loadTags();
    _loadCurrentUser();
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadForumInfo() async {
    try {
      final res = await widget.api.getForumInfo();
      final title = res['data']?['attributes']?['title'] as String?;
      if (title != null) {
        setState(() => _siteTitle = title);
      } else {
        setState(() => _siteTitle = 'XSOP 论坛'); 
      }
    } catch (_) {
      setState(() => _siteTitle = 'XSOP 论坛');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240 &&
        !_loadingMore &&
        !_refreshing &&
        _hasMore &&
        _error == null) {
      _loadMore();
    }
  }

  Future<void> _loadTags() async {
    try {
      final res = await widget.api.getTags();
      setState(() {
        _allTags.clear();
        _allTags.addAll(parseTags(res));
      });
    } catch (_) {
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = await widget.api.getUserId();
      if (userId == null) return;
      final res = await widget.api.getUser(userId);
      setState(() => _currentUser = parseUser(res, widget.baseUrl));
    } catch (_) {
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      _page = 1;
      final res = await widget.api.getDiscussions(page: 1, tag: _selectedTagSlug);
      final list = parseDiscussionList(res, widget.baseUrl);
      setState(() {
        _discussions
          ..clear()
          ..addAll(list.items);
        _hasMore = list.hasMore;
      });
    } catch (_) {
      setState(() => _error = '加载失败，请下拉重试');
    } finally {
      setState(() => _refreshing = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await widget.api.getDiscussions(
        page: _page + 1,
        tag: _selectedTagSlug,
      );
      final list = parseDiscussionList(res, widget.baseUrl);
      setState(() {
        _discussions.addAll(list.items);
        _hasMore = list.hasMore;
        _page += 1;
      });
    } catch (_) {
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  void _selectTag(String? slug) {
    // 只有在侧边栏打开时才关闭
    if (Scaffold.of(context).isDrawerOpen) {
      Navigator.of(context).pop(); 
    }
    if (slug == _selectedTagSlug) return;
    setState(() => _selectedTagSlug = slug);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(_siteTitle),
        actions: [_buildAvatarAction(context)],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildAvatarAction(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () {
          if (_currentUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(user: _currentUser!),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先登录')),
            );
          }
        },
        child: Tooltip(
          message: _currentUser?.username ?? '未登录',
          child: CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            backgroundImage: _currentUser?.avatarUrl != null
                ? NetworkImage(_currentUser!.avatarUrl!)
                : null,
            child: _currentUser?.avatarUrl != null
                ? null
                : Icon(Icons.person, size: 20, color: scheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('标签', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text('全部'),
                  selected: _selectedTagSlug == null,
                  onTap: () => _selectTag(null),
                ),
                const Divider(height: 1),
                for (final tag in _allTags)
                  ListTile(
                    leading: Icon(Icons.label, color: _parseColor(tag.color) ?? scheme.primary),
                    title: Text(tag.name),
                    subtitle: (tag.description == null || tag.description!.isEmpty)
                        ? null
                        : Text(
                            tag.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    selected: _selectedTagSlug == tag.slug,
                    onTap: () => _selectTag(tag.slug),
                  ),
                if (_allTags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('暂无标签')),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_refreshing && _discussions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _discussions.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!)),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonal(onPressed: _refresh, child: const Text('重试')),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _discussions.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        if (index == _discussions.length) return _buildFooter();
        return DiscussionTile(
          discussion: _discussions[index], 
          // 1. 点击帖子标题区域，进入详情页
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DiscussionDetailPage(
                  api: widget.api,
                  discussion: _discussions[index],
                ),
              ),
            );
          },
          // 2. 点击头像，进入该作者主页 [修改备注：完善头像点击事件]
          onTapAuthor: () {
             final author = _discussions[index].user;
             if (author != null) {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (context) => UserProfilePage(user: author),
                 ),
               );
             }
          },
          // 3. 点击标签，列表按标签筛选 [修改备注：完善标签筛选事件]
          onTapTag: (String slug) {
             _selectTag(slug);
          },
        );
      },
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text('没有更多了', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class DiscussionTile extends StatelessWidget {
  final Discussion discussion;
  final VoidCallback onTap;
  
  // [修改备注：为帖子列表项增加头像点击和标签点击的回调接口]
  final VoidCallback onTapAuthor;
  final Function(String) onTapTag;

  const DiscussionTile({
    super.key, 
    required this.discussion, 
    required this.onTap,
    required this.onTapAuthor,
    required this.onTapTag,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = discussion.user;
    final replyUser = discussion.lastPostedUser ?? author;
    final replyTime = discussion.lastPostedAt ?? discussion.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [修改备注：用 GestureDetector 包裹头像以支持跳转]
          GestureDetector(
            onTap: onTapAuthor,
            child: _Avatar(user: author),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    discussion.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (discussion.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    // [修改备注：为标签传入点击回调，实现过滤功能]
                    children: discussion.tags.map((t) => GestureDetector(
                      onTap: () => onTapTag(t.slug),
                      child: _TagChip(tag: t),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 14, color: scheme.outline),
                    const SizedBox(width: 4),
                    Text('${discussion.commentCount}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: scheme.outline),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        replyTime == null ? '—' : formatRelativeTime(replyTime),
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (replyUser != null) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          '@${replyUser.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.outline),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final FlarumUser? user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (user?.displayName.isNotEmpty == true
            ? user!.displayName
            : user?.username) ??
        '?';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
      child: user?.avatarUrl != null
          ? null
          : Text(letter, style: TextStyle(color: scheme.onPrimaryContainer)),
    );
  }
}

class _TagChip extends StatelessWidget {
  final FlarumTag tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.color) ?? Theme.of(context).colorScheme.primary;
    final background = Color.lerp(color, Colors.white, 0.88) ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag.name,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  if (value == null) return null;
  return Color(value);
}

String formatRelativeTime(DateTime time, {DateTime? now}) {
  final nowVal = now ?? DateTime.now();
  final diff = nowVal.difference(time);
  if (diff.isNegative) return '刚刚';
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  if (time.year == nowVal.year) return '${time.month}月${time.day}日';
  return '${time.year}年${time.month}月${time.day}日';
}
