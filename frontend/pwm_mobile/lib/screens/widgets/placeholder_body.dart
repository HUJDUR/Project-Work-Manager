import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              '$title is not built yet',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick Dashboard from the navigation to see the implemented screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
