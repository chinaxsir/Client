// 文件位置: lib/main.dart

import 'package:flutter/material.dart';
// [修改备注：已将相对路径更改为 package 绝对路径导入，修复 Type 'ApiClient' not found 报错]
import 'package:xsop_forum/api/api_client.dart';
// [修改备注：补充导入 home_page.dart，修复 The method 'HomePage' isn't defined for the type 'XSOPForumApp' 报错]
import 'package:xsop_forum/pages/home_page.dart';

void main() {
  runApp(const XSOPForumApp());
}

class XSOPForumApp extends StatelessWidget {
  const XSOPForumApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [修改备注：现在可以正常读取到导入的 ApiClient 类型]
    final ApiClient apiClient = ApiClient();

    return MaterialApp(
      title: 'XSOP 论坛',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // [修改备注：现在可以正常实例化并渲染 HomePage]
      home: HomePage(), 
    );
  }
}
