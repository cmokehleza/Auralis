import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

/// Owns the gallery-to-app-storage lifecycle for custom wallpapers.
///
/// The selected file is copied into application support storage so Android's
/// temporary document-provider permission is never needed after a restart.
abstract final class BackgroundImageService {
  static const _maximumBytes = 32 * 1024 * 1024;
  static const _prefix = 'auralis_background_';

  static Future<String?> pickAndStore() async {
    const images = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
      mimeTypes: ['image/*'],
    );
    final picked = await openFile(acceptedTypeGroups: const [images]);
    if (picked == null) return null;
    final length = await picked.length();
    if (length <= 0) {
      throw const FormatException('The selected image is empty.');
    }
    if (length > _maximumBytes) {
      throw const FormatException('Choose an image smaller than 32 MB.');
    }

    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final extension = _safeExtension(picked.name);
    final target = File(
      '${directory.path}${Platform.pathSeparator}'
      '$_prefix${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await picked.saveTo(target.path);
    if (!await target.exists() || await target.length() == 0) {
      throw const FileSystemException('Could not save the selected image.');
    }
    await _deleteOtherCopies(directory, exceptPath: target.path);
    return target.path;
  }

  static Future<void> remove(String? path) async {
    if (path == null || path.isEmpty) return;
    final directory = await getApplicationSupportDirectory();
    final file = File(path);
    if (!_isManagedFile(file, directory)) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A missing/locked old wallpaper must never block resetting appearance.
    }
  }

  static String _safeExtension(String name) {
    final dot = name.lastIndexOf('.');
    final value = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(value)
        ? value
        : 'jpg';
  }

  static Future<void> _deleteOtherCopies(
    Directory directory, {
    required String exceptPath,
  }) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is! File ||
            entity.path == exceptPath ||
            !_isManagedFile(entity, directory)) {
          continue;
        }
        await entity.delete();
      }
    } on FileSystemException {
      // The new file is already safe; stale-copy cleanup is best effort.
    }
  }

  static bool _isManagedFile(File file, Directory directory) {
    final parent = file.parent.absolute.path.toLowerCase();
    final expected = directory.absolute.path.toLowerCase();
    final name = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last.toLowerCase();
    return parent == expected && name.startsWith(_prefix);
  }
}
