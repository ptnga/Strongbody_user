# Vendored copy — strongbody_chat_client

Bản copy từ `chat-server/clients/dart` (tag `clients/dart/v0.1.2`).

Dev Flutter **không cần** quyền repo `chat-server` — `pubspec.yaml` dùng `path: packages/strongbody_chat_client`.

## Maintainer: cập nhật SDK

Khi có bản mới trên chat-server:

```powershell
# Từ máy có clone chat-server
$src = "..\..\chat-server\clients\dart"
$dst = "packages\strongbody_chat_client"
robocopy $src $dst /E /XD .dart_tool .git /XF pubspec.lock VENDORED.md
```

Sau đó trong `Multime_Version_2`:

```bash
flutter pub get
dart analyze packages/strongbody_chat_client
```

Commit thay đổi trong `packages/strongbody_chat_client/`.

## Dev mới clone Flutter

```bash
flutter pub get
```

Không cần token hay quyền GitHub repo chat-server.
