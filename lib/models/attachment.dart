import 'dart:typed_data';

import '../app/constants.dart';

/// What kind of file is attached. Stored in Firestore as "image" or "pdf".
enum AttachmentKind {
  image,
  pdf;

  static AttachmentKind? fromName(Object? value) => switch (value) {
    'image' => AttachmentKind.image,
    'pdf' => AttachmentKind.pdf,
    _ => null,
  };

  /// Short label used in the chat and in the saved note.
  String get label => this == AttachmentKind.image ? 'Photo' : 'PDF';
}

/// Thrown when a picked file can't be attached. [message] is user-friendly.
class AttachmentException implements Exception {
  const AttachmentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A file the user picked, held in memory only.
///
/// It is sent to the AI with one message and then forgotten: we never store
/// files (Cloud Storage needs the paid Blaze plan). Only [name] and [kind]
/// are saved, as a note on the message.
class Attachment {
  const Attachment._({
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final AttachmentKind kind;
  final String mimeType;
  final Uint8List bytes;

  int get sizeInBytes => bytes.length;

  /// Checks a picked file and turns it into an [Attachment].
  ///
  /// Security: the type is decided from the file's first bytes (its
  /// "signature"), not from its name, so a renamed file can't sneak through.
  /// Throws [AttachmentException] if the file is empty, too big or not an
  /// allowed type.
  static Attachment fromPickedFile({
    required String name,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      throw const AttachmentException('That file is empty.');
    }
    if (bytes.length > AppConstants.maxAttachmentBytes) {
      throw AttachmentException(
        'That file is too big. The limit is ${formatFileSize(AppConstants.maxAttachmentBytes)}.',
      );
    }
    final mimeType = detectMimeType(bytes);
    if (mimeType == null) {
      throw const AttachmentException(
        'Only photos (JPG, PNG, WebP) and PDFs can be attached.',
      );
    }
    return Attachment._(
      name: cleanFileName(name),
      kind: mimeType == 'application/pdf'
          ? AttachmentKind.pdf
          : AttachmentKind.image,
      mimeType: mimeType,
      bytes: bytes,
    );
  }
}

/// Recognises allowed file types by their first bytes. Returns null for
/// anything else.
String? detectMimeType(Uint8List b) {
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  // WebP: "RIFF" .... "WEBP"
  if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
      startsWith([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  if (startsWith([0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return 'application/pdf'; // %PDF-
  }
  return null;
}

/// Keeps only the file's own name (no folders), on one line, at most
/// [AppConstants.maxAttachmentNameLength] characters.
String cleanFileName(String raw) {
  final base = raw.split(RegExp(r'[\\/]')).last;
  final oneLine = base.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
  if (oneLine.isEmpty) return 'file';
  if (oneLine.length <= AppConstants.maxAttachmentNameLength) return oneLine;
  return oneLine.substring(0, AppConstants.maxAttachmentNameLength);
}

/// "2.4 MB", "830 KB", "512 bytes".
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    // "7 MB", not "7.0 MB".
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '${mb.endsWith('.0') ? mb.substring(0, mb.length - 2) : mb} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes bytes';
}
