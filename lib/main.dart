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
      title: 'XSOP主页',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      home: HomePage(
        api: apiClient,
        baseUrl: apiClient.baseUrl,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    // [修改备注：使用更明亮、更现代的纯正蓝色作为品牌主色调]
    const seed = Color(0xFF007AFF); 
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        // [修改备注：强制将表面和背景颜色设置为纯白，杜绝 Material 3 自动附加的灰紫染色]
        surface: Colors.white,
        background: Colors.white,
      ),
      // [修改备注：脚手架背景设为纯白，提升整体界面的通透感和对比度]
      scaffoldBackgroundColor: Colors.white, 
      
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        // [修改备注：导航栏使用纯白背景，并添加极细微的底边阴影以区分内容区]
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        shadowColor: Colors.black12,
        // [修改备注：关键！将 surfaceTintColor 设为透明，彻底阻止导航栏在滚动时变色]
        surfaceTintColor: Colors.transparent, 
      ),
      
      dividerTheme: const DividerThemeData(
        space: 1,
        // [修改备注：将分割线改得更加纤细（0.5），颜色使用干净的浅灰色，视觉上更清爽]
        thickness: 0.5,
        color: Color(0xFFE5E5EA),
      ),
      
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
