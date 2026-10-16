import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_failure.dart';

class PhotoPreparer {
  final _picker = ImagePicker();
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

  Future<Uint8List?> choose() async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      // Bound memory before decoding; input remains local and never goes to API.
      if (await file.length() > 30000000) {
        throw const ApiFailure(ApiFailureKind.payloadTooLarge);
      }
      final input = await file.readAsBytes();
      for (final size in [1600, 1200, 900, 640]) {
        final output = await FlutterImageCompress.compressWithList(
          input,
          minWidth: size,
          minHeight: size,
          quality: 80,
          keepExif: false,
          autoCorrectionAngle: true,
          format: CompressFormat.jpeg,
        );
        if (output.length >= 3 &&
            output[0] == 255 &&
            output[1] == 216 &&
            output[2] == 255 &&
            output.length <= 500000) {
          return output;
        }
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
