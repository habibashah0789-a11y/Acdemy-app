// Web stub for dart:io — provides no-op implementations of File/Directory
// so that files using `import 'dart:io' if (dart.library.html) '...'` compile on web.

/// Stub for dart:io File — web builds never call these methods
/// because all usages are guarded with `if (!kIsWeb)`.
class File {
  final String path;
  const File(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<List<int>> readAsBytes() async => [];
  Future<File> writeAsBytes(List<int> bytes) async => this;
  Future<File> create({bool recursive = false}) async => this;
  Future<void> delete({bool recursive = false}) async {}
}

/// Stub for dart:io Directory — web builds never use this.
class Directory {
  final String path;
  const Directory(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}
