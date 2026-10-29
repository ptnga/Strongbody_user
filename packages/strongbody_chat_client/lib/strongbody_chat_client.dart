/// PubNub-compatible Dart client SDK for chat-server (StrongBody platform).
library strongbody_chat_client;

export 'src/client.dart';
export 'src/errors.dart';
export 'src/types.dart';
export 'src/transport/rest.dart' show toHttpBase;
export 'src/transport/ws.dart' show WebSocketFactory;
