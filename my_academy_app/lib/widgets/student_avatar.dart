import 'dart:convert';
import 'dart:io' as io;
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

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  static final Map<String, String?> _localPathCache = {};
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
      _initLocalCheck();
    }
  }

  void _initLocalCheck() {
    final url = widget.student.profilePicUrl;
    // Fast path: if url is empty, HTTP, base64 data URI, or on Web, no disk I/O is needed.
    if (url.isEmpty || url.startsWith('http') || url.startsWith('data:image') || url.length > 100 || kIsWeb) {
      _localPath = null;
      _checkedLocal = true;
      return;
    }

    if (_localPathCache.containsKey(widget.student.id)) {
      _localPath = _localPathCache[widget.student.id];
      _checkedLocal = true;
      return;
    }

    _checkedLocal = false;
    _checkLocalFile();
  }

  Future<void> _checkLocalFile() async {
    final path = await ImageUtils.getLocalProfilePath(widget.student.id);
    final exists = await io.File(path).exists();
    final resolved = exists ? path : null;
    _localPathCache[widget.student.id] = resolved;

    if (mounted) {
      setState(() {
        _localPath = resolved;
        _checkedLocal = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedLocal) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final int cacheDimension = (widget.size * 2).toInt().clamp(64, 512);
    Widget imageWidget;

    if (_localPath != null) {
      imageWidget = Image.file(
        io.File(_localPath!),
        fit: widget.fit,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else if (widget.student.profilePicUrl.isNotEmpty) {
      final url = widget.student.profilePicUrl;
      if (url.startsWith('http')) {
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          fit: widget.fit,
          memCacheWidth: cacheDimension,
          memCacheHeight: cacheDimension,
          placeholder: (context, url) => Container(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallback(),
        );
      } else if (url.startsWith('data:image') || url.length > 100) {
        try {
          final base64Str = url.contains(',') ? url.split(',').last : url;
          final bytes = base64Decode(base64Str.replaceAll('\n', '').replaceAll('\r', '').trim());
          imageWidget = Image.memory(
            bytes,
            fit: widget.fit,
            cacheWidth: cacheDimension,
            cacheHeight: cacheDimension,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } catch (_) {
          imageWidget = _buildFallback();
        }
      } else if (!kIsWeb && io.File(url).existsSync()) {
        imageWidget = Image.file(
          io.File(url),
          fit: widget.fit,
          cacheWidth: cacheDimension,
          cacheHeight: cacheDimension,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        imageWidget = _buildFallback();
      }
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
