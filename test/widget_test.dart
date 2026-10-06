import 'package:flutter_test/flutter_test.dart';
import 'package:zhibo_im_win/shared/protocol/custom_message.dart';

void main() {
  test('CustomMessageProtocol 摘要与 MessageSummary 自定义分支一致', () {
    const protocol = TextLinkMessage(text: 'https://example.com');
    expect(protocol.summary, 'https://example.com');
    expect(CustomMessageProtocol.parse('{"businessID":"text_link","text":"hello"}'), isA<TextLinkMessage>());
  });

  test('MessageSummary 空信令返回空串', () {
    expect(
      CustomMessageProtocol.parse('{"businessID":"user_typing_status","typingStatus":1}').isSignaling,
      isTrue,
    );
  });
}
