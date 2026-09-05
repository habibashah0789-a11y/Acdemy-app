import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../theme/app_theme.dart';

class CropImageDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const CropImageDialog({super.key, required this.imageBytes});

  @override
  State<CropImageDialog> createState() => _CropImageDialogState();
}

class _CropImageDialogState extends State<CropImageDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  double _zoomVal = 1.0;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _zoomVal).abs() > 0.05) {
      setState(() {
        _zoomVal = scale.clamp(1.0, 4.0);
      });
    }
  }

  void _onZoomSliderChanged(double value) {
    setState(() {
      _zoomVal = value;
      // Zoom from the current translation center
      final translation = _transformationController.value.getTranslation();
      final Matrix4 matrix = Matrix4.identity();
      matrix.setTranslation(translation);
      matrix.scaleByVector3(Vector3(value, value, 1.0));
      _transformationController.value = matrix;
    });
  }

  Future<void> _crop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Render boundary not found");
      }
      
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to encode image");
      }
      final croppedBytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      
      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      debugPrint("Crop error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to crop image: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Crop Profile Photo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pinch to zoom or use the slider below. Drag to position the face inside the circular area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // RepaintBoundary encapsulates the viewport to be cropped
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: Container(
                        width: 280,
                        height: 280,
                        color: Colors.black,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 4.0,
                          boundaryMargin: const EdgeInsets.all(140),
                          child: Center(
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Inverted Circle Dim Overlay
                  IgnorePointer(
                    child: ClipPath(
                      clipper: InvertedCircleClipper(),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // Thin white circular border guide
                  IgnorePointer(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.zoom_out, color: isDark ? Colors.grey : Colors.grey.shade600),
                Expanded(
                  child: Slider(
                    value: _zoomVal,
                    min: 1.0,
                    max: 4.0,
                    activeColor: AppTheme.primaryBlue,
                    inactiveColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    onChanged: _onZoomSliderChanged,
                  ),
                ),
                Icon(Icons.zoom_in, color: isDark ? Colors.grey : Colors.grey.shade600),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCropping ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isCropping ? null : _crop,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isCropping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('CROP & SAVE'),
                ),
              ],
            ),
          ],
        ),
      ),
     ),
    );
  }
}

class InvertedCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
