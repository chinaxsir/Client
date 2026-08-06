import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// [修改备注：将原本的相对路径替换为 package: 绝对路径，避免由于 CI 环境脚本重组文件系统导致的路径解析崩溃]
import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/pages/home_page.dart';

/// 全局单例 ApiClient，默认连接 https://xsop.de
final ApiClient apiClient = ApiClient();

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const XSOPForumApp());
}

class XSOPForumApp extends StatelessWidget {
  const XSOPForumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XSOP',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      home: HomePage(
        api: apiClient,
        baseUrl: apiClient.baseUrl,
        onTapAvatar: () {
          // TODO: 跳转个人中心
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const seed = Color(0xFF3B82F6); // Flarum 蓝
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      scaffoldBackgroundColor: const Color(0xFFF7F7F8),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: Color(0xFFEEEEEE),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
