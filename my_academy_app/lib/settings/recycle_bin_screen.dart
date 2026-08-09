import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recycled_student.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading_widget.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});
  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  bool _isEmptying = false;
  Future<void> _restore(RecycledStudent recycled) async {
    final restored = await DatabaseService.restoreStudent(recycled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? '${recycled.name} restored to Student Directory'
              : 'Restore failed — check your connection',
        ),
        backgroundColor: restored ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _deletePermanently(RecycledStudent recycled) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text(
          'Permanently delete ${recycled.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.deleteRecycledStudent(recycled.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student permanently deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _emptyRecycleBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Recycle Bin'),
        content: const Text(
          'This will permanently delete ALL recycled students. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Empty Bin'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isEmptying = true);
      await DatabaseService.emptyRecycleBin();
      if (!mounted) return;
      setState(() => _isEmptying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recycle bin emptied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [
          if (_isEmptying)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Empty Recycle Bin',
              onPressed: _emptyRecycleBin,
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final stream = DatabaseService.getRecycledStudentsStream();

    // Offline / not signed-in: listen to local Hive box only
    if (stream == null) {
      return ValueListenableBuilder(
        valueListenable: DatabaseService.recycledStudentBox.listenable(),
        builder: (context, box, _) {
          final localList = DatabaseService.getRecycledStudents()
            ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
          if (localList.isEmpty) return _buildEmptyState();
          return _buildList(localList, isDark);
        },
      );
    }

    // Online: merge cloud + local
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final local = DatabaseService.getRecycledStudents();

        if (snapshot.connectionState == ConnectionState.waiting && local.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, _) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShimmerLoadingWidget.studentCardPlaceholder(context),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final cloud = docs.map((doc) {
          return RecycledStudent.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        final Map<String, RecycledStudent> combinedMap = {};
        for (var item in local) {
          combinedMap[item.id] = item;
        }
        for (var item in cloud) {
          combinedMap[item.id] = item;
        }
        final combinedList = combinedMap.values.toList();
        combinedList.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

        if (combinedList.isEmpty) return _buildEmptyState();
        return _buildList(combinedList, isDark);
      },
    );
  }

  Widget _buildList(List<RecycledStudent> recycled, bool isDark) {
    return Column(
      children: [
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Swipe right to restore • Swipe left to delete permanently',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: recycled.length,
            itemBuilder: (context, index) {
              return _buildRecycledCard(recycled[index], index, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecycledCard(RecycledStudent student, int index, bool isDark) {
    final deletedLabel =
        DateFormat('MMM d, y • h:mm a').format(student.deletedAt);
    return Dismissible(
      key: Key(student.id),
      background: _buildSwipeBackground(
        color: Colors.green,
        icon: Icons.restore_rounded,
        label: 'Restore',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: Colors.red,
        icon: Icons.delete_forever_rounded,
        label: 'Delete',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _restore(student);
          return false; // stream will update UI
        } else {
          await _deletePermanently(student);
          return false; // stream will update UI
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: student.profilePicUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: student.profilePicUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ShimmerLoadingWidget(
                            width: 54,
                            height: 54,
                            borderRadius: 16,
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.red.shade300,
                              size: 28,
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            student.initials.isNotEmpty
                                ? student.initials
                                : 'S',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.grade} • ${student.subject}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 12,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Deleted $deletedLabel',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Restore button
                  _actionButton(
                    icon: Icons.restore_rounded,
                    color: Colors.green,
                    tooltip: 'Restore',
                    onTap: () => _restore(student),
                  ),
                  const SizedBox(height: 6),
                  // Delete forever button
                  _actionButton(
                    icon: Icons.delete_forever_rounded,
                    color: Colors.red,
                    tooltip: 'Delete forever',
                    onTap: () => _deletePermanently(student),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
          ],
          Icon(icon, color: color),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 72,
              color: AppTheme.primaryBlue.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Recycle Bin is Empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deleted students will appear here.\nYou can restore or permanently delete them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
