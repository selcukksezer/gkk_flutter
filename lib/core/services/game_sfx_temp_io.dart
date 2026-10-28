import 'dart:io';
import 'dart:typed_data';

final Map<String, String> _writtenPaths = <String, String>{};

/// Writes synthesized mono WAV bytes once to OS temp storage so Android/iOS
/// `SoundPool` (`PlayerMode.lowLatency`) loads natively from file without
/// marshaling `Uint8List` over JNI MethodChannels or blocking the UI thread.
Future<String?> cacheGameSfxWavFile(String name, Uint8List wavBytes) async {
  final String? existing = _writtenPaths[name];
  if (existing != null) return existing;
  try {
    final File file = File('${Directory.systemTemp.path}/gkk_v15_sfx_$name.wav');
    if (!await file.exists() || await file.length() != wavBytes.length) {
      await file.writeAsBytes(wavBytes, flush: false);
    }
    _writtenPaths[name] = file.path;
    return file.path;
  } catch (_) {
    return null;
  }
}
