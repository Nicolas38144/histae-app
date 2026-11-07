import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_failure.dart';

enum PhotoSource { camera, gallery }

class PhotoPreparer {
  PhotoPreparer({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  // Never attach an Android recovered selection to a session restored after a
  // process death. The owner binding of that selection is no longer known.

  Future<bool> discardInterruptedSelection() async {
    if (!Platform.isAndroid) return false;
    final data = await _picker.retrieveLostData();
    for (final file in data.files ?? <XFile>[]) {
      await _purgePickerCopy(file);
    }
    return !data.isEmpty;
  }

  Future<Uint8List?> choose({PhotoSource source = PhotoSource.gallery}) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        requestFullMetadata: false,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 100,
      );
      if (file == null) return null;
      // Bound memory before decoding; input remains local and never goes to API.
      if (await file.length() > 30000000) {
        throw const ApiFailure(ApiFailureKind.payloadTooLarge);
      }
      final input = await file.readAsBytes();
      // Keep detail for the local crop. The final 500 KB bound is applied only
      // after the user chooses the framing, never to an uncropped upload.
      final output = await FlutterImageCompress.compressWithList(
        input,
        minWidth: 2400,
        minHeight: 2400,
        quality: 95,
        keepExif: false,
        autoCorrectionAngle: true,
        format: CompressFormat.jpeg,
      );
      if (output.length >= 3 &&
          output[0] == 255 &&
          output[1] == 216 &&
          output[2] == 255 &&
          output.length <= 30000000) {
        return output;
      }
      throw const ApiFailure(ApiFailureKind.payloadTooLarge);
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        code: 'photo_selection_unavailable',
      );
    } finally {
      if (file != null) await _purgePickerCopy(file);
    }
  }

  Future<void> _purgePickerCopy(XFile file) async {
    try {
      final temporary = (await getTemporaryDirectory()).absolute.path;
      final copy = File(file.path);
      // Only a copy created by the picker in the application's own cache.
      // Resolve symlinks before checking; never remove a library original.
      final resolved = await copy.resolveSymbolicLinks();
      final root = await Directory(temporary).resolveSymbolicLinks();
      if (resolved.startsWith('$root${Platform.pathSeparator}')) {
        await File(resolved).delete();
      }
    } catch (_) {
      /* The OS also owns the temporary-cache lifecycle. */
    }
  }
}
