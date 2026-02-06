import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminMenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  AdminMenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class AdminMenuSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<AdminMenuItem> items;

  const AdminMenuSection({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2D3436),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: Colors.grey.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 20),
          items.length <= 3
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items.map((item) {
                    return _buildItem(context, item);
                  }).toList(),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = 2; // Fixed 2 columns when > 3 items
                    final spacing = 16.0;
                    final totalSpacing = spacing * (crossAxisCount - 1);
                    final itemWidth =
                        (constraints.maxWidth - totalSpacing) / crossAxisCount;

                    return Wrap(
                      alignment: WrapAlignment.start,
                      runSpacing: 16,
                      spacing: spacing,
                      children: items.map((item) {
                        return SizedBox(
                          width: itemWidth,
                          child: _buildItem(context, item),
                        );
                      }).toList(),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, AdminMenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : const Color(0xFF636E72),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
