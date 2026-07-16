import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    final content = await file.readAsString();
    final newContent = content.replaceAllMapped(
      RegExp(r'\.withOpacity\(([^)]*)\)'),
      (match) => '.withValues(alpha: ${match.group(1)})',
    );
    
    if (content != newContent) {
      await file.writeAsString(newContent);
      print('Fixed ${file.path}');
    }
  }
}
