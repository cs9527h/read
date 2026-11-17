import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/profile/about_page.dart';

/// 任务书六.2：反馈入口名称必须是「联系作者」，链接指向作者官方 QQ 联系页。
/// 这里锁定链接常量，避免以后被改回加群链接或错误地址。
void main() {
  test('联系作者入口指向官方 QQ 链接', () {
    expect(AboutPage.contactUrl, 'https://qm.qq.com/q/Yvc3ugiCoE');
    expect(AboutPage.feedbackUrl, AboutPage.contactUrl,
        reason: '兼容别名必须与主常量一致，不能指向不同地址');
  });
}
