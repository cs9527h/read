# Read Windows 实验性 CI 构建

通过 GitHub Actions 的 `windows-latest` 生成 Windows 平台壳、运行 Flutter 分析和单测，并打包 Windows Release **便携 ZIP**，不需要用户本机安装 Flutter。

**重要状态：**
- 这是构建/兼容验证，不是已交付安装程序。尚无 MSI/MSIX、正式代码签名、自动更新。
- Windows 下 file_picker、pdfrx、drift/native 和字体表现均需真实构建与设备验证。
- 由于 UI 当前基于 Android 小屏布局，Windows 双页、快捷键、拖放导入及云端读书位置同步仍未实现。
- 本地 Flutter 源码保持单仓，Read 仓库不公开，Mate 仓库无改动。
