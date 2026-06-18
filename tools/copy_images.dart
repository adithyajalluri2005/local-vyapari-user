import 'dart:io';

void main() {
  final sourcePath = 'C:/Users/adith/.gemini/antigravity/brain/00a9753d-0e57-4de5-a9c7-d79a875e3a36/media__1781001614206.png';
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
