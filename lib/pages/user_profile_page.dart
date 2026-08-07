// 文件位置: lib/pages/user_profile_page.dart

import 'package:flutter/material.dart';
import 'package:xsop_forum/models/flarum_models.dart';
// [修改备注：引入 main.dart 以便直接使用全局的 apiClient 对象，无需在上一层页面修改传参]
import 'package:xsop_forum/main.dart'; 

class UserProfilePage extends StatelessWidget {
  final FlarumUser user;

  const UserProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 顶部背景与头像区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: scheme.primary,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Icon(Icons.person, size: 50, color: scheme.onPrimary)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName.isNotEmpty ? user.displayName : user.username,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // 功能列表区域
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('我的发帖'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               // [修改备注：为“我的发帖”增加交互反馈提示]
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('我的发帖历史功能正在开发中...'))
               );
            },
          ),
          const Divider(height: 1),
          
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // [修改备注：将“设置”按钮连接到下方新建的 SettingsPage，打通退出登录闭环]
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// [修改备注：新增独立的设置页面，提供退出登录等全局操作]
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('关于 XSOP 论坛'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出当前账号吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        // [修改备注：调用全局 apiClient 清除本地 Token，并直接弹回应用首页]
                        await apiClient.logout();
                        if (context.mounted) {
                          // popUntil 会清空路由栈并回到首页，首页检测到无 Token 会自动变成未登录状态
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                      child: const Text('确定退出'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
