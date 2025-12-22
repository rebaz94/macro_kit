import 'dart:async';

import 'package:macro_kit/src/common/models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsChannel {
  WsChannel({
    required this.channel,
  });

  final WebSocketChannel channel;

  FutureOr<void> addMessage(Message message) {
    channel.sink.add(encodeMessage(message));
  }

  Future<dynamic> close(int closeCode, String closeReason) {
    return channel.sink.close(closeCode, closeReason);
  }
}
