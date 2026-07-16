import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/roles.dart';
import '../../core/models/hierarchy_node.dart';
import '../auth/auth_provider.dart';
import 'user_provider.dart';

/// Hierarchy Tree Screen — displays the organizational tree view
class HierarchyTreeScreen extends ConsumerStatefulWidget {
  const HierarchyTreeScreen({super.key});

  @override
  ConsumerState<HierarchyTreeScreen> createState() =>
      _HierarchyTreeScreenState();
}

class _HierarchyTreeScreenState extends ConsumerState<HierarchyTreeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(hierarchyTreeProvider.notifier).fetchHierarchy();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hierarchyTreeProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentSaffron),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(hierarchyTreeProvider.notifier).fetchHierarchy(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (state.root == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_tree_outlined,
                size: 40,
                color: AppColors.primaryNavy.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.noHierarchyData,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    final rootNode = state.root!;
    
    final List<HierarchyNode> displayNodes = [rootNode];

    if (displayNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_off_outlined,
                size: 40,
                color: AppColors.primaryNavy.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Subordinates',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have any users reporting to you.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(hierarchyTreeProvider.notifier).fetchHierarchy(),
      color: AppColors.accentSaffron,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: displayNodes.map((node) => Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _TreeNodeWidget(node: node, isRoot: true),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recursive tree node widget with connecting lines
class _TreeNodeWidget extends StatefulWidget {
  final HierarchyNode node;
  final bool isRoot;
  final bool isLast;

  const _TreeNodeWidget({
    required this.node,
    this.isRoot = false,
    this.isLast = true,
  });

  @override
  State<_TreeNodeWidget> createState() => _TreeNodeWidgetState();
}

class _TreeNodeWidgetState extends State<_TreeNodeWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Default to root expanded, others collapsed
    _isExpanded = widget.isRoot;
  }

  void _toggleExpanded() {
    if (widget.node.hasChildren) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The user card for this node
        _buildNodeCard(context),

        // Children with connecting lines (Collapsible)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: _isExpanded && widget.node.hasChildren
              ? Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < widget.node.children.length; i++)
                        _buildChildConnector(
                          context,
                          widget.node.children[i],
                          isLast: i == widget.node.children.length - 1,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildChildConnector(
    BuildContext context,
    HierarchyNode child, {
    required bool isLast,
  }) {
    return Stack(
      children: [
        // Vertical + horizontal connector lines
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 28,
          child: CustomPaint(
            painter: _TreeLinePainter(isLast: isLast),
          ),
        ),
        // Child tree node (recursive)
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: _TreeNodeWidget(
            node: child,
            isLast: isLast,
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(BuildContext context) {
    final roleColor = getRoleColor(widget.node.user.role);
    final roleDisplay = getRoleDisplayName(widget.node.user.role);

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isExpanded ? roleColor.withValues(alpha: 0.5) : roleColor.withValues(alpha: 0.25),
            width: _isExpanded ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: roleColor.withValues(alpha: _isExpanded ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: avatar + name + role badge
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    widget.node.user.name.isNotEmpty
                        ? widget.node.user.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.node.user.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        roleDisplay,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.node.hasChildren)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.textSubtle.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.textSubtle,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${widget.node.children.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Zone & Division info
          if (widget.node.user.zone != null && widget.node.user.zone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailChip(
              Icons.location_city_rounded,
              widget.node.user.zone!,
              AppColors.info,
            ),
          ],
          if (widget.node.user.division != null && widget.node.user.division!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildDetailChip(
              Icons.map_rounded,
              widget.node.user.division!,
              AppColors.roleAdmin,
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for tree connecting lines
class _TreeLinePainter extends CustomPainter {
  final bool isLast;

  _TreeLinePainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textSubtle.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Vertical line from top to the horizontal branch point
    final verticalEndY = isLast ? size.height * 0.35 : size.height;
    canvas.drawLine(
      Offset(0, 0),
      Offset(0, verticalEndY),
      paint,
    );

    // Horizontal line from vertical to the child node
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width - 4, size.height * 0.35),
      paint,
    );

    // Small circle at the junction point
    final dotPaint = Paint()
      ..color = AppColors.textSubtle.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, size.height * 0.35), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
