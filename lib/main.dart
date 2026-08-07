// 文件位置: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xsop_forum/api/api_client.dart';
import 'package:xsop_forum/pages/home_page.dart';

final ApiClient apiClient = ApiClient();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'XSOP 论坛',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      home: HomePage(
        api: apiClient,
        baseUrl: apiClient.baseUrl,
        // [修改备注：彻底删除了这里引起报错的 onTapAvatar: () {...} 代码，因为 home_page 已经不需要这个参数了]
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const seed = Color(0xFF3B82F6);
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
