# strongbody_chat_client

PubNub-compatible Dart client SDK for [chat-server](../../).

Works on Flutter (iOS / Android / web / desktop) and pure-Dart server-side.

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  strongbody_chat_client:
    git:
      url: https://github.com/quannv/chat-server.git
      path: clients/dart
```

Or for local development:

```yaml
dependencies:
  strongbody_chat_client:
    path: /path/to/chat-server/clients/dart
```

## Quickstart

```dart
import 'package:strongbody_chat_client/strongbody_chat_client.dart';

void main() async {
  final pubnub = ChatPubNub(
    endpoint: 'wss://chat-dev.strongbody.ai',
    tenant:   'strongbody',
    uuid:     'alice',
    token:    jwt, // minted by your backend via /v3/grant
  );

  pubnub.messages.listen((MessageEvent e) {
    print('${e.publisher}: ${e.message}');
  });

  pubnub.presence.listen((PresenceEvent e) {
    print('${e.action} ${e.uuid} (occupancy ${e.occupancy})');
  });

  pubnub.status.listen((StatusEvent e) {
    print('status: ${e.category}');
  });

  pubnub.subscribe(channels: {'dm_alice_bob'});

  final res = await pubnub.publish(
    channel: 'dm_alice_bob',
    message: {'type': 'text', 'content': 'hi', 'uuid': 'alice'},
  );
  print('delivered at ${res.timetoken}');

  await pubnub.disconnect();
}
```

## API

### Constructor

```dart
ChatPubNub({
  required String endpoint,        // https:// or wss:// — both accepted
  required String tenant,
  required String uuid,
  required String token,
  Duration heartbeatInterval = const Duration(seconds: 30),
  Duration initialReconnectDelay = const Duration(seconds: 1),
  Duration maxReconnectDelay = const Duration(seconds: 30),
  http.Client? httpClient,         // inject for tests
  WebSocketFactory? webSocketFactory, // inject for tests
})
```

### Methods

- `subscribe({required Set<String> channels, bool withPresence, String? timetoken})`
- `unsubscribe({required Set<String> channels})`
- `unsubscribeAll()`
- `Future<PublishResult> publish({required String channel, required Object message, Object? meta, bool? storeInHistory})`
- `Future<void> disconnect()` — terminal; instance unusable after

### Streams

| Stream | Yields |
|---|---|
| `messages` | `MessageEvent { channel, timetoken, publisher, message, userMetadata? }` |
| `presence` | `PresenceEvent { channel, action, uuid, occupancy, timetoken, timestamp }` |
| `status` | `StatusEvent { category, statusCode, operation?, affectedChannels?, error? }` |

All three are broadcast streams — `.listen` multiple times safely.

`StatusEvent.category` is a PubNub-compatible string constant from `StatusCategory`:
- `StatusCategory.connected` — `'PNConnectedCategory'`
- `StatusCategory.disconnected` — `'PNDisconnectedCategory'`
- `StatusCategory.accessDenied` — `'PNAccessDeniedCategory'` (terminal — token rejected)
- `StatusCategory.unknown` — `'PNUnknownCategory'`
- `StatusCategory.networkIssues` — `'PNNetworkIssuesCategory'`
- `StatusCategory.catchupSkipped` — `'PNCatchupSkippedCategory'`

### Errors

`publish()` throws `ChatError` for non-2xx responses:

```dart
try {
  await pubnub.publish(channel: 'x', message: {});
} on ChatError catch (e) {
  if (isInvalidToken(e))         await refreshToken();
  else if (isNoWritePermission(e)) showAccessDenied();
  else                           print('chat-server ${e.httpStatus} ${e.code}: ${e.message}');
}
```

| Helper | Matches |
|---|---|
| `isAdminAuthFailed(e)` | 401 `admin_auth_failed` |
| `isInvalidToken(e)` | 401 `invalid_token` / `missing_token` |
| `isTenantMismatch(e)` | 403 `tenant_mismatch` |
| `isNoWritePermission(e)` | 403 `no_write_permission` |
| `isBadRequest(e)` | 400 `bad_json` / `missing_uuid` / `invalid_tenant` |
| `isNotImplemented(e)` | 501 `not_implemented` |

Full code reference at [`/docs/errors`](https://chat-dev.strongbody.ai/docs/errors).

## Reconnect behaviour

| WS close code | Behaviour |
|---|---|
| 1000 normal | Stop. |
| 1011 server error | Auto-reconnect with exponential backoff (1s → 30s, ±20% jitter). |
| 4401 invalid token | Emit `PNAccessDeniedCategory` status, **stop**. Caller must refresh and create a new `ChatPubNub`. |
| 4403 tenant mismatch | Same — terminal. |
| 4408 idle timeout | Reconnect with backoff. |
| 4429 rate limited | Reconnect with backoff. |

The subscription set is replayed on every (re)connect. Callers don't need to re-subscribe after a network blip.

## Migration from `pubnub` 7.x (Dart)

The full mapping is at [`/docs/migrating-from-pubnub`](https://chat-dev.strongbody.ai/docs/migrating-from-pubnub). High-level:

| `pubnub` 7.x | `strongbody_chat_client` |
|---|---|
| `PubNub(defaultKeyset: ...)` | `ChatPubNub(endpoint:, tenant:, uuid:, token:)` |
| `pubnub.subscribe(channels: {'foo'})` | `pubnub.subscribe(channels: {'foo'})` |
| `subscription.messages.listen(...)` | `pubnub.messages.listen(...)` |
| `pubnub.publish('foo', {'x': 1})` | `pubnub.publish(channel: 'foo', message: {'x': 1})` |

## Development

```sh
dart pub get
dart analyze
dart test
```
