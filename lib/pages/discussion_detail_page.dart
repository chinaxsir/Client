// 文件位置: lib/pages/discussion_detail_page.dart

import 'package:flutter/material.dart';
import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/models/flarum_models.dart';

// [修改备注：新建帖子详情页面，用于接收传入的 ApiClient 和 Discussion 模型，并动态请求帖子具体内容]
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
  Map<String, dynamic>? _detailData;

  @override
  void initState() {
    super.initState();
    _loadDiscussionDetail();
  }

  // [修改备注：调用 api_client 中的 getDiscussion 方法拉取具体回复]
  Future<void> _loadDiscussionDetail() async {
    try {
      final data = await widget.api.getDiscussion(widget.discussion.id);
      setState(() {
        _detailData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '无法加载帖子详情，请检查网络';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // [修改备注：顶部导航栏显示当前帖子的标题]
        title: const Text('帖子详情', style: TextStyle(fontSize: 16)),
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

    // 解析 Flarum API 的 included 列表获取回复总数
    final included = _detailData?['included'] as List<dynamic>? ?? [];
    final postsCount = included.where((item) => item['type'] == 'posts').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 帖子大标题
          Text(
            widget.discussion.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // 帖子主体内容占位（因 Flarum 返回的是 HTML 格式，后续需引入 flutter_html 插件专门渲染，这里暂做连通性展示）
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '接口联通成功！\n\n此处为首层楼内容。\n当前接口共拉取到 $postsCount 条相关回复数据。\n(后续可通过解析 _detailData 渲染具体 HTML 富文本)',
              style: const TextStyle(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
