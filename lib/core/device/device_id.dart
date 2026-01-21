import 'dart:html' as html;
import 'package:uuid/uuid.dart';

class DeviceId {
  static const _storageKey = 'bubbles_device_id';
  static final _uuid = Uuid();

  static String get() {
    final storage = html.window.localStorage;

    // já existe
    final existing = storage[_storageKey];
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    // cria novo
    final id = _uuid.v4();
    storage[_storageKey] = id;
    return id;
  }
}
