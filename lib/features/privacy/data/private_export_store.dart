import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/async/serial_executor.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';

class PrivateExportStore {
  PrivateExportStore({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final _name = RegExp(r'^histae-export-[a-f0-9-]{36}\.json(?:\.part)?$');
  static const maxBytes = 512 * 1024 * 1024;
  final _queue = SerialExecutor();
  Future<T> _serialized<T>(Future<T> Function() action) => _queue.run(action);

  Future<Directory> _cache() async =>
      Directory(await (await _temporaryDirectory()).resolveSymbolicLinks());
  Future<Directory> _folder(String name, {bool create = false}) async {
    final cache = await _cache();
    final folder = Directory('${cache.path}${Platform.pathSeparator}$name');
    final type = await FileSystemEntity.type(folder.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.file) {
      throw const ApiFailure(
        ApiFailureKind.unavailable,
        code: 'export_local_storage',
      );
    }
    if (create && type == FileSystemEntityType.notFound) await folder.create();
    if (await folder.exists()) {
      final resolved = await folder.resolveSymbolicLinks();
      if (resolved != folder.absolute.path ||
          !resolved.startsWith('${cache.path}${Platform.pathSeparator}')) {
        throw const ApiFailure(
          ApiFailureKind.unavailable,
          code: 'export_local_storage',
        );
      }
    }
    return folder;
  }

  Future<void> clean() => _serialized(_clean);
  Future<void> _clean() async {
    // Own files only, including the share plugin's bounded cache copy. Never
    // traverse a symlink, remove a source file, or clear another plugin's data.
    for (final name in ['histae_private_exports', 'share_plus']) {
      final folder = await _folder(name);
      if (!await folder.exists()) continue;
      await for (final entity in folder.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        if (entity is File &&
            _name.hasMatch(name) &&
            await FileSystemEntity.type(entity.path, followLinks: false) ==
                FileSystemEntityType.file) {
          await entity.delete();
        }
      }
    }
  }

  Future<String> save(ApiDownload download, RequestCancellation scope) =>
      _serialized(() => _save(download, scope));
  Future<String> _save(ApiDownload download, RequestCancellation scope) async {
    String? partial;
    RandomAccessFile? file;
    try {
      if (scope.isCancelled) throw const ApiFailure(ApiFailureKind.cancelled);
      if (download.contentLength > maxBytes) {
        throw const ApiFailure(
          ApiFailureKind.payloadTooLarge,
          code: 'export_local_limit',
        );
      }
      final folder = await _folder('histae_private_exports', create: true);
      final path =
          '${folder.path}${Platform.pathSeparator}histae-export-${newUuidV4()}.json';
      partial = '$path.part';
      file = await File(partial).open(mode: FileMode.writeOnly);
      var count = 0;
      int? first, last;
      final target = file;
      await (() async {
        await for (final chunk in download.bytes) {
          if (scope.isCancelled) {
            throw const ApiFailure(ApiFailureKind.cancelled);
          }
          count += chunk.length;
          if (count > maxBytes || count > download.contentLength) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
          for (final b in chunk) {
            if (![9, 10, 13, 32].contains(b)) {
              first ??= b;
              last = b;
            }
          }
          await target.writeFrom(chunk);
        }
      })().timeout(const Duration(minutes: 10));
      if (scope.isCancelled) throw const ApiFailure(ApiFailureKind.cancelled);
      if (count != download.contentLength || first != 123 || last != 125) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      await target.close();
      file = null;
      await File(partial).rename(path);
      partial = null;
      return path;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } catch (_) {
      throw const ApiFailure(
        ApiFailureKind.unavailable,
        code: 'export_local_storage',
      );
    } finally {
      download.close();
      try {
        await file?.close();
      } catch (_) {
        /* Cleanup is retried on next entry/start. */
      }
      try {
        if (partial != null && await File(partial).exists()) {
          await File(partial).delete();
        }
      } catch (_) {
        /* Remains in private cache, never shared. */
      }
    }
  }
}
