import 'package:flutter/material.dart';

// [修改备注：统一替换为 package 绝对路径导入，彻底消除由于 CI 环境编译时相对路径和绝对路径混用导致的类型冲突和找不到文件错误]
import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/models/flarum_models.dart';

/// Flarum 首页帖子列表
///
/// 顶栏左侧为抽屉导航（展示全部 Tag，点击按标签筛选），
/// 右侧为当前用户头像（点击进入个人中心）。
/// 列表支持下拉刷新与上拉加载更多。
class HomePage extends StatefulWidget {
  final ApiClient api;
  final String baseUrl;

  /// 点击右上角用户头像回调（进入个人中心）
  final VoidCallback? onTapAvatar;

  const HomePage({
    super.key,
    required this.api,
    this.baseUrl = 'https://xsop.de',
    this.onTapAvatar,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  final List<Discussion> _discussions = [];
  final List<FlarumTag> _allTags = [];
  FlarumUser? _currentUser;

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
        // [修改备注：因为 _allTags 是 final 的，不能用 = 重新赋值。这里改为先清空数据，再添加新解析的数据]
        _allTags.clear();
        _allTags.addAll(parseTags(res));
      });
    } catch (_) {
      // 标签加载失败不阻塞主流程
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = await widget.api.getUserId();
      if (userId == null) return;
      final res = await widget.api.getUser(userId);
      setState(() => _currentUser = parseUser(res, widget.baseUrl));
    } catch (_) {
      // 未登录或失败时显示默认头像
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
      // 静默失败，下次滚动可重试
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  void _selectTag(String? slug) {
    Navigator.of(context).pop(); // 关闭抽屉
    if (slug == _selectedTagSlug) return;
    setState(() => _selectedTagSlug = slug);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Flarum'),
        actions: [_buildAvatarAction()],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  /// 顶栏右侧用户头像
  Widget _buildAvatarAction() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: widget.onTapAvatar,
        child: Tooltip(
          message: _currentUser?.username ?? '个人中心',
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

  /// 左侧抽屉：全部 Tag 导航
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
        return DiscussionTile(discussion: _discussions[index], onTap: () {});
      },
    );
  }

  /// 列表底部：加载中 / 没有更多
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

/// 单个帖子列表项
class DiscussionTile extends StatelessWidget {
  final Discussion discussion;
  final VoidCallback onTap;

  const DiscussionTile({super.key, required this.discussion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = discussion.user;
    final replyUser = discussion.lastPostedUser ?? author;
    final replyTime = discussion.lastPostedAt ?? discussion.createdAt;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(user: author),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discussion.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (discussion.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: discussion.tags.map((t) => _TagChip(tag: t)).toList(),
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

/// 带背景色的标签 Chip
class _TagChip extends StatelessWidget {
  final FlarumTag tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.color) ?? Theme.of(context).colorScheme.primary;
    // 由标签色向白色插值，得到浅色背景，文字使用标签原色
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

// ---------------- 工具函数 ----------------

/// 解析十六进制颜色（#RGB / #RRGGBB / AARRGGBB）
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

/// 中文相对时间
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
