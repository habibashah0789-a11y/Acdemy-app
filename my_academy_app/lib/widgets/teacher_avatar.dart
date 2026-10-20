import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' if (dart.library.html) 'package:my_academy_app/utils/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/teacher_model.dart';
import '../theme/app_theme.dart';

class TeacherAvatar extends StatelessWidget {
  final TeacherModel teacher;
  final double size;
  final BoxFit fit;
  final Color? backgroundColor;

  const TeacherAvatar({
    super.key,
    required this.teacher,
    this.size = 50,
    this.fit = BoxFit.cover,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = teacher.profilePicUrl.trim();
    Widget imageWidget;

    if (url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: size,
          height: size,
          placeholder: (_, __) => _buildInitials(),
          errorWidget: (_, __, ___) => _buildInitials(),
        );
      } else if (url.startsWith('data:image') || url.length > 100) {
        try {
          final base64Str = url.contains(',') ? url.split(',').last : url;
          final bytes = base64Decode(
              base64Str.replaceAll('\n', '').replaceAll('\r', '').trim());
          imageWidget = Image.memory(
            bytes,
            fit: fit,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _buildInitials(),
          );
        } catch (_) {
          imageWidget = _buildInitials();
        }
      } else if (!kIsWeb && io.File(url).existsSync()) {
        imageWidget = Image.file(
          io.File(url),
          fit: fit,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => _buildInitials(),
        );
      } else {
        imageWidget = _buildInitials();
      }
    } else {
      imageWidget = _buildInitials();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      ),
      child: ClipOval(child: imageWidget),
    );
  }

  Widget _buildInitials() {
    final initials = teacher.name.isNotEmpty
        ? teacher.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'T';
    return Container(
      color: backgroundColor ?? AppTheme.primaryBlue.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}
