# XSOP Forum — TrollStore 构建指南

## 在 Windows 上构建 TrollStore IPA（无需 Mac、无需开发者账号）

> 核心思路：**Windows 负责编写代码 + Git 推送，GitHub Actions 的 macOS Runner 负责云构建 IPA。**

---

## 🚀 完整步骤

### 1. 初始化 Flutter 项目

```powershell
# 在 Windows 上（可选，已完成可跳过）
flutter create .
flutter pub get
```

### 2. 推送到 GitHub

```powershell
git init
git add .
git commit -m "feat: init XSOP Forum with TrollStore config"
git branch -M main
git remote add origin https://github.com/<你的用户名>/XSOP-Forum.git
git push -u origin main
```

### 3. 在 GitHub 上触发构建

两种方式任选其一：

**方式 A：推送 Tag（自动触发）**
```powershell
git tag v1.0.0
git push origin v1.0.0
```

**方式 B：手动触发**
1. 打开 GitHub 仓库 → **Actions** 标签页
2. 选择 **"Build IPA for TrollStore"** 工作流
3. 点击 **Run workflow** 按钮

### 4. 下载 IPA 产物

构建完成后（约 8-15 分钟）：
1. 进入 Actions → 最新运行 → **Artifacts**
2. 下载 **`TrollStore-IPA`**（.ipa 文件）
3. 同时下载 **`TrollStore-App`**（.app.zip，备用）

### 5. 侧载到 iPhone

1. 确保 iOS 设备已安装 **TrollStore**
2. 通过 TrollStore 的 **Sideload** 功能导入 .ipa
3. 或使用 **TrollInstallerX** / **Sideloadly** 等工具

---

## ⚙️ TrollStore 扩展权限说明

### 已配置的 Extended Entitlements

| 权限键 | 作用 | 风险 |
|--------|------|------|
| `com.apple.developer.ubiquity-kvstore-access` | 访问 iCloud Keychain | 低 |
| `com.apple.developer.kernel.extended-virtual-address-space` | 64-bit 内存寻址 | 低 |
| `com.apple.security.allow-unsigned-executable-memory` | 执行未签名内存（JIT） | ⚠️ 可能导致崩溃 |
| `com.apple.developer.playable-content` | 媒体播放控制 | 低 |
| `com.apple.developer.networking.wifi-info` | 获取 WiFi 信息 | 中（隐私风险） |
| `com.apple.developer.usb.host-device` | USB 主机访问 | 中 |
| `com.apple.developer.avfoundation.audio-fetch` | 系统级音频抓取 | ⚠️ 隐私风险高 |
| `com.apple.security.files.user-selected.read-write` | 文件读写权限 | ⚠️ 可能被滥用 |
| `com.apple.developer.networking.raw-socket` | 原始套接字 | ⚠️ 安全风险高 |

### 已开启的后台模式

| 模式 | 作用 |
|------|------|
| `audio` | 后台播放音乐/语音 |
| `fetch` | 后台定期拉取数据 |
| `remote-notification` | 接收远程推送 |
| `processing` | 后台处理任务 |
| `location` | 后台持续定位 |

---

## 🔧 本地调试（Windows）

虽然 iOS 构建需要 Mac，但 Android 调试可在 Windows 直接完成：

```powershell
flutter doctor
flutter pub get
flutter run -d windows   # Windows 桌面预览
flutter run -d chrome    # Web 预览
flutter run -d <Android设备ID>  # Android 真机
```

---

## 📁 项目结构

```
XSOP-Forum/
├── .github/workflows/
│   └── build_ios.yml          # GitHub Actions 云构建
├── lib/
│   ├── api/
│   │   └── api_client.dart    # Flarum API 客户端
│   ├── models/
│   │   └── flarum_models.dart # JSON:API 数据模型
│   ├── pages/
│   │   └── home_page.dart     # 首页 UI
│   └── main.dart              # 应用入口
├── ios/
│   ├── Runner/
│   │   ├── Info.plist         # 配置（含后台模式、权限说明）
│   │   ├── Runner.entitlements # TrollStore 扩展权限
│   │   └── AppDelegate.swift  # iOS 入口
│   └── Podfile                # CocoaPods 配置（已禁签名）
├── pubspec.yaml
└── analysis_options.yaml
```

---

## ⚠️ 重要提示

1. **无需苹果开发者账号**：TrollStore 侧载完全绕过了苹果的签名和审核机制
2. **无需签名证书**：所有构建均使用 `CODE_SIGNING_ALLOWED=NO`，TrollStore 会在安装时自动签名
3. **系统版本限制**：TrollStore 支持 iOS 14.0 - 17.x（具体取决于设备和 TrollStore 版本）
4. **风险自负**：扩展权限可能导致 App 在系统更新后无法启动，或被系统安全机制拦截
