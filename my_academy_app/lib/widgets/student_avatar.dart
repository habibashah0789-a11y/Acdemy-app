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
  final BoxFit fit;

  const StudentAvatar({
    super.key,
    required this.student,
    this.size = 50,
    this.isLarge = false,
    this.fit = BoxFit.cover,
  });

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  String? _localPath;
  bool _checkedLocal = false;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
  }

  @override
  void didUpdateWidget(StudentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id || 
        oldWidget.student.profilePicUrl != widget.student.profilePicUrl) {
      _checkLocalFile();
    }
  }

  Future<void> _checkLocalFile() async {
    if (kIsWeb) {
      setState(() {
        _localPath = null;
        _checkedLocal = true;
      });
      return;
    }

    final path = await ImageUtils.getLocalProfilePath(widget.student.id);
    if (await io.File(path).exists()) {
      if (mounted) {
        setState(() {
          _localPath = path;
          _checkedLocal = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _localPath = null;
          _checkedLocal = true;
        });
      }
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

    Widget imageWidget;

    if (_localPath != null) {
      imageWidget = Image.file(
        io.File(_localPath!),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else if (widget.student.profilePicUrl.isNotEmpty) {
      final url = widget.student.profilePicUrl;
      if (url.startsWith('http')) {
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          fit: widget.fit,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
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
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } catch (_) {
          imageWidget = _buildFallback();
        }
      } else if (!kIsWeb && io.File(url).existsSync()) {
        imageWidget = Image.file(
          io.File(url),
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        imageWidget = _buildFallback();
      }
    } else {
      imageWidget = _buildFallback();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.isLarge ? 16 : widget.size / 2),
        child: imageWidget,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: widget.isLarge ? Colors.black12 : AppTheme.primaryBlue.withValues(alpha: 0.1),
      child: Center(
        child: widget.student.initials.isNotEmpty && !widget.isLarge
            ? Text(
                widget.student.initials,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.size * 0.4,
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
