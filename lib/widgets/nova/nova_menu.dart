import 'package:flutter/material.dart';

/// Shows a popup menu next to [anchor] (the button or row that opened it)
/// and returns the chosen value, or null if dismissed.
Future<T?> showMenuAt<T>(
  BuildContext anchor, {
  required List<PopupMenuEntry<T>> items,
}) {
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return Future.value();
  final rect = Rect.fromPoints(
    box.localToGlobal(Offset.zero, ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
  );
  return showMenu<T>(
    context: anchor,
    position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    items: items,
  );
}
