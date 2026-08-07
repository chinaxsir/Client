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
      // [修改备注：增加 Builder 包裹，以获取 Scaffold 下方的有效 Context 用于弹出 Snackbar]
      home: Builder(
        builder: (innerContext) {
          return HomePage(
            api: apiClient,
            baseUrl: apiClient.baseUrl,
            // [修改备注：补充了右上角头像的临时点击响应，后续开发个人中心页后替换这里的逻辑]
            onTapAvatar: () {
              ScaffoldMessenger.of(innerContext).clearSnackBars();
              ScaffoldMessenger.of(innerContext).showSnackBar(
                const SnackBar(
                  content: Text('正在开发中：个人中心页面'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          );
        },
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
