// 文件位置: lib/pages/editor_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/models/flarum_models.dart';

class EditorPage extends StatefulWidget {
  final ApiClient api;
  final Discussion? discussion; 
  final List<FlarumTag>? availableTags; 

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
  bool _isUploading = false; 
  
  FlarumTag? _selectedPrimaryTag;
  final List<FlarumTag> _selectedSecondaryTags = [];

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
      if (_selectedPrimaryTag == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择一个主标签 (必选)')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isNewPost) {
        List<String> finalTagIds = [_selectedPrimaryTag!.id];
        finalTagIds.addAll(_selectedSecondaryTags.map((t) => t.id));

        await widget.api.createDiscussion(
          title: _titleController.text.trim(),
          content: content,
          tagIds: finalTagIds, 
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发布成功！')));
          Navigator.pop(context, true); 
        }
      } else {
        await widget.api.createPost(int.parse(widget.discussion!.id), content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回复成功！')));
          Navigator.pop(context, true); 
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

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    
    try {
      final url = await widget.api.uploadImage(pickedFile.path);
      if (url != null) {
        final currentText = _contentController.text;
        final selection = _contentController.selection;
        final imageMarkdown = '\n![图片]($url)\n';
        
        if (selection.isValid) {
          final newText = currentText.replaceRange(selection.start, selection.end, imageMarkdown);
          _contentController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start + imageMarkdown.length),
          );
        } else {
          _contentController.text = currentText + imageMarkdown;
        }
      } else {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传未能获取到图片链接')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('图片上传失败，请检查图床或 API 设置')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
    // [核心修复4 配合：严格筛选出当前用户有“发帖权限”的标签]
    final allowedTags = widget.availableTags?.where((t) => t.canStartDiscussion).toList() ?? [];
    
    // 基于过滤后的安全列表，再进行层级拆分
    final primaryTags = allowedTags.where((t) => !t.isChild).toList();
    final secondaryTags = allowedTags.where((t) => t.isChild).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(_isNewPost ? '发布新主题' : '回复帖子', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: const Color(0xFFE5E5EA), height: 0.5),
        ),
        actions: [
          IconButton(
            icon: _isUploading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
            onPressed: _isSubmitting || _isUploading ? null : _pickAndUploadImage,
            tooltip: '插入图片',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _isSubmitting || _isUploading ? null : _submit,
              child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('发送'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isNewPost) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '请输入具有描述性的标题...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
            
            if (primaryTags.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('选择主标签 (必选)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: primaryTags.map((tag) {
                        final isSelected = _selectedPrimaryTag?.id == tag.id;
                        return ChoiceChip(
                          label: Text(tag.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedPrimaryTag = selected ? tag : null);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            
            if (secondaryTags.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('选择二级标签 (可选)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: secondaryTags.map((tag) {
                        final isSelected = _selectedSecondaryTags.any((t) => t.id == tag.id);
                        return FilterChip(
                          label: Text(tag.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSecondaryTags.add(tag);
                              } else {
                                _selectedSecondaryTags.removeWhere((t) => t.id == tag.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
          ],
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: _isNewPost ? '分享你的想法（支持 Markdown）...' : '写下你的回复...',
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
