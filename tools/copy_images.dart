import 'dart:io';

void main() {
  final sourcePath = 'C:/Users/adith/.gemini/antigravity/brain/0a7d04d1-6af7-441a-99b1-da540a0d8c6c/media__1780986388840.png';
  final sourceFile = File(sourcePath);

  if (!sourceFile.existsSync()) {
    print('Error: Source image not found at: $sourcePath');
    exit(1);
  }

  final targets = [
    'android/app/src/main/res/drawable/ic_notification.png',
    'assets/images/logo.png',
    'assets/images/logo_white.png',
  ];

  for (final target in targets) {
    try {
      final targetFile = File(target);
      if (!targetFile.parent.existsSync()) {
        targetFile.parent.createSync(recursive: true);
      }
      sourceFile.copySync(target);
      print('Copied to $target');
    } catch (e) {
      print('Error copying to $target: $e');
    }
  }
  print('Logo copy task complete.');
}
