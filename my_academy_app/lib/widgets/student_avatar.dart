import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' if (dart.library.html) 'package:my_academy_app/utils/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/student_model.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';

class StudentAvatar extends StatefulWidget {
  final StudentModel student;
  final double size;
  final bool isLarge;
  final bool isCircle;
  final BoxFit fit;

  const StudentAvatar({
    super.key,
    required this.student,
    this.size = 50,
    this.isLarge = false,
    this.isCircle = true,
    this.fit = BoxFit.cover,
  });

  static void showFullScreen(BuildContext context, StudentModel student) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Hero(
                      tag: 'student_avatar_zoom_${student.id}',
                      child: StudentAvatar(
                        student: student,
                        size: MediaQuery.of(context).size.width * 0.95,
                        isCircle: false,
                        isLarge: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static final Map<String, String?> _localPathCache = {};

  static void invalidateCache([String? studentId]) {
    if (studentId != null) {
      _localPathCache.remove(studentId);
    } else {
      _localPathCache.clear();
    }
  }

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  String? _localPath;
  bool _checkedLocal = false;

  @override
  void initState() {
    super.initState();
    _initLocalCheck();
  }

  @override
  void didUpdateWidget(StudentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id || 
        oldWidget.student.profilePicUrl != widget.student.profilePicUrl) {
      StudentAvatar._localPathCache.remove(widget.student.id);
      _initLocalCheck();
    }
  }

  void _initLocalCheck() {
    final url = widget.student.profilePicUrl.trim();
    // If remote URL, base64, or on Web, no local disk check needed unless offline
    if (url.startsWith('data:image') || (!url.startsWith('http') && url.length > 100) || kIsWeb) {
      _localPath = null;
      _checkedLocal = true;
      return;
    }

    if (StudentAvatar._localPathCache.containsKey(widget.student.id)) {
      _localPath = StudentAvatar._localPathCache[widget.student.id];
      _checkedLocal = true;
      return;
    }

    _checkedLocal = false;
    _checkLocalFile();
  }

  Future<void> _checkLocalFile() async {
    if (kIsWeb) {
      if (mounted) setState(() => _checkedLocal = true);
      return;
    }
    try {
      final path = await ImageUtils.getLocalProfilePath(widget.student.id);
      String? resolved;
      if (io.File(path).existsSync()) {
        resolved = path;
      } else {
        // Also check legacy .jpg
        final legacyPath = path.replaceAll('.png', '.jpg');
        if (io.File(legacyPath).existsSync()) {
          resolved = legacyPath;
        }
      }
      StudentAvatar._localPathCache[widget.student.id] = resolved;

      if (mounted) {
        setState(() {
          _localPath = resolved;
          _checkedLocal = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkedLocal = true);
      }
    }
  }

  static Uint8List? _tryDecodeBase64(String str) {
    try {
      String clean = str.contains(',') ? str.split(',').last : str;
      clean = clean.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '').trim();
      while (clean.length % 4 != 0) {
        clean += '=';
      }
      final decoded = base64Decode(clean);
      return decoded.isNotEmpty ? decoded : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedLocal && widget.student.profilePicUrl.trim().isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: _buildFallback(),
      );
    }

    final int cacheDimension = (widget.size * 2).toInt().clamp(64, 512);
    Widget imageWidget;

    final url = widget.student.profilePicUrl.trim();

    if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        key: ValueKey('avatar_net_${widget.student.id}_${url.hashCode}'),
        imageUrl: url,
        fit: widget.fit,
        memCacheWidth: cacheDimension,
        memCacheHeight: cacheDimension,
        placeholder: (context, url) => _buildFallback(),
        errorWidget: (context, url, error) {
          if (_localPath != null && io.File(_localPath!).existsSync()) {
            return Image.file(
              io.File(_localPath!),
              fit: widget.fit,
              cacheWidth: cacheDimension,
              cacheHeight: cacheDimension,
              errorBuilder: (_, __, ___) => _buildFallback(),
            );
          }
          return _buildFallback();
        },
      );
    } else if (url.startsWith('data:image') || (!url.contains('/') && !url.contains('\\') && url.length > 50)) {
      final bytes = _tryDecodeBase64(url);
      if (bytes != null) {
        imageWidget = Image.memory(
          bytes,
          key: ValueKey('avatar_b64_${widget.student.id}_${url.hashCode}'),
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        imageWidget = _buildFallback();
      }
    } else if (url.startsWith('blob:')) {
      imageWidget = Image.network(
        url,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (!kIsWeb && url.isNotEmpty && io.File(url).existsSync()) {
      imageWidget = Image.file(
        io.File(url),
        key: ValueKey('avatar_file_${widget.student.id}_$url'),
        fit: widget.fit,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (_localPath != null && io.File(_localPath!).existsSync()) {
      imageWidget = Image.file(
        io.File(_localPath!),
        key: ValueKey('avatar_local_${widget.student.id}_$_localPath'),
        fit: widget.fit,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      imageWidget = _buildFallback();
    }

    final double radius = widget.isCircle ? (widget.size / 2) : (widget.isLarge ? 16.0 : 12.0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageWidget,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: widget.isLarge ? Colors.black12 : AppTheme.primaryBlue.withValues(alpha: 0.1),
      child: Center(
        child: widget.student.initials.isNotEmpty
            ? Text(
                widget.student.initials,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.size * (widget.isLarge ? 0.35 : 0.4),
                  color: AppTheme.primaryBlue,
                ),
              )
            : Icon(
                Icons.person_rounded,
                color: widget.isLarge ? Colors.grey : AppTheme.primaryBlue,
                size: widget.size * 0.6,
              ),
      ),
    );
  }
}
