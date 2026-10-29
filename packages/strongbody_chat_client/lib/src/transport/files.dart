import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors.dart';
import '../types.dart';
import 'rest.dart';

/// Options shared by file transport helpers.
class FileTransportOpts {
  final String endpoint;
  final String tenant;
  final String token;
  final http.Client httpClient;

  const FileTransportOpts({
    required this.endpoint,
    required this.tenant,
    required this.token,
    required this.httpClient,
  });
}

/// Three-step PubNub-compatible sendFile: presign → S3 PUT → publish file envelope.
Future<SendFileResult> sendFile(
  FileTransportOpts opts,
  RestTransport rest,
  SendFileParams params,
) async {
  if (params.channel.isEmpty) {
    throw ArgumentError('sendFile: channel is required');
  }
  if (params.file.name.isEmpty) {
    throw ArgumentError('sendFile: file.name is required');
  }

  final String contentType = _pickContentType(params.file);
  final String base = toHttpBase(opts.endpoint);

  // 1. Ask chat-server for a presigned PUT URL.
  final Uri reserveUrl = Uri.parse(
    '$base/v3/files/${Uri.encodeComponent(opts.tenant)}/${Uri.encodeComponent(params.channel)}',
  );
  final http.Response reserve = await opts.httpClient.post(
    reserveUrl,
    headers: <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${opts.token}',
    },
    body: jsonEncode(<String, String>{
      'name': params.file.name,
      'contentType': contentType,
    }),
  );
  if (reserve.statusCode < 200 || reserve.statusCode >= 300) {
    throw parseErrorBody(reserve.statusCode, reserve.body);
  }

  final Object? decoded = jsonDecode(reserve.body);
  if (decoded is! Map<String, dynamic>) {
    throw ChatError(
      httpStatus: reserve.statusCode,
      code: ErrorCode.transportError,
      message: 'malformed presign response: ${reserve.body}',
    );
  }
  final String? id = decoded['id'] as String?;
  final String? name = decoded['name'] as String?;
  final String? uploadUrl = decoded['uploadUrl'] as String?;
  if (id == null || name == null || uploadUrl == null) {
    throw ChatError(
      httpStatus: reserve.statusCode,
      code: ErrorCode.transportError,
      message: 'malformed presign response: ${reserve.body}',
    );
  }

  // 2. Upload directly to S3.
  final http.Response put = await opts.httpClient.put(
    Uri.parse(uploadUrl),
    headers: <String, String>{'Content-Type': contentType},
    body: params.file.data,
  );
  if (put.statusCode < 200 || put.statusCode >= 300) {
    throw ChatError(
      httpStatus: put.statusCode,
      code: 's3_upload_failed',
      message: put.body.isNotEmpty ? put.body : put.reasonPhrase ?? 'S3 upload failed',
    );
  }

  // 3. Publish a file/image message so subscribers see the upload.
  final Map<String, dynamic> envelope = <String, dynamic>{
    'type': params.publishType,
    'file': <String, dynamic>{
      'id': id,
      'name': name,
      'size': params.file.data.length,
    },
  };
  if (params.uuid != null) {
    envelope['uuid'] = params.uuid;
  }
  if (params.message != null) {
    envelope['message'] = params.message;
  }

  final PublishResult pubResult = await rest.publish(
    channel: params.channel,
    message: envelope,
    storeInHistory: params.storeInHistory,
    meta: params.meta,
  );

  return SendFileResult(id: id, name: name, timetoken: pubResult.timetoken);
}

/// Synchronous URL builder — matches PubNub getFileUrl parity.
String getFileUrl(FileTransportOpts opts, GetFileUrlParams params) {
  final String base = toHttpBase(opts.endpoint);
  return '$base/v3/files/'
      '${Uri.encodeComponent(opts.tenant)}/'
      '${Uri.encodeComponent(params.channel)}/'
      '${Uri.encodeComponent(params.id)}/'
      '${Uri.encodeComponent(params.name)}'
      '?token=${Uri.encodeComponent(opts.token)}';
}

/// Download file bytes by following chat-server 302 → S3 redirect.
Future<List<int>> downloadFile(
  FileTransportOpts opts,
  GetFileUrlParams params,
) async {
  final String url = getFileUrl(opts, params);
  final http.Response res = await opts.httpClient.get(Uri.parse(url));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw parseErrorBody(res.statusCode, res.body);
  }
  return res.bodyBytes;
}

String _pickContentType(SendFilePayload file) {
  if (file.mimeType != null && file.mimeType!.isNotEmpty) {
    return file.mimeType!;
  }
  final String lower = file.name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}
