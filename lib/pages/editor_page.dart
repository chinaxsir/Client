// 文件位置: lib/pages/editor_page.dart

import 'package:flutter/material.dart';
import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/models/flarum_models.dart';

// [修改备注：新建一个通用的富文本编辑器页面，同时支持“发布新主题”和“回复现有帖子”两种模式]
class EditorPage extends StatefulWidget {
  final ApiClient api;
  final Discussion? discussion; // 如果为空，表示是发布新主题；如果不为空，表示回复该主题
  final List<FlarumTag>? availableTags; // 发布新主题时供选择的标签列表

  const EditorPage({
    super.key,
    required this.api,
    this.discussion,
    this.availableTags,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  bool _isSubmitting = false;
  FlarumTag? _selectedTag;

  bool get _isNewPost => widget.discussion == null;

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('内容不能为空')));
      return;
    }

    if (_isNewPost) {
      final title = _titleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题不能为空')));
        return;
      }
      if (_selectedTag == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择一个标签')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isNewPost) {
        // 调用发帖 API
        await widget.api.createDiscussion(
          title: _titleController.text.trim(),
          content: content,
          tagIds: [_selectedTag!.id], // Flarum 发帖必须带标签ID
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发布成功！')));
          Navigator.pop(context, true); // 返回 true 通知上一页刷新列表
        }
      } else {
        // 调用回帖 API
        await widget.api.createPost(int.parse(widget.discussion!.id), content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回复成功！')));
          Navigator.pop(context, true); // 返回 true 通知上一页刷新楼层
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交失败，请检查网络或账号权限')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewPost ? '发布新主题' : '回复帖子'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('发送'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 新主题模式下，显示标题输入框和标签选择器
          if (_isNewPost) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '请输入标题...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            // 标签选择区域
            if (widget.availableTags != null && widget.availableTags!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.availableTags!.map((tag) {
                      final isSelected = _selectedTag?.id == tag.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedTag = selected ? tag : null);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const Divider(height: 1),
          ],
          // 共用的正文输入区域
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: _isNewPost ? '分享你的想法...' : '写下你的回复...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
