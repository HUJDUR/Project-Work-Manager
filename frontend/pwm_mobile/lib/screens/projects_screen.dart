import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_row.dart';
import '../providers/projects_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'project_details_screen.dart';

/// The Projects tab: what the shop floor is building.
///
/// There is no mockup in `docs/mockups/mobile` for this one — it was designed
/// to sit with the others and follows their anatomy: the same heading and
/// subtitle, the same card.
///
/// Every row is **in production**, which is what this app is for, so there is
/// no status filter and no status chip: a pill that says the same thing on
/// every card is noise, not information.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final ProjectsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? ProjectsProvider())..load(),
      child: Consumer<ProjectsProvider>(
        builder: (context, provider, _) => _Body(provider: provider),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final ProjectsProvider provider;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const SizedBox(height: 4),
          Text(
            'Projects',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Projects currently in production',
            style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _SearchField(provider: provider),
          ..._results(context),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context) {
    return switch (provider.status) {
      ProjectsStatus.failed when provider.rows.isEmpty => [
          _Message(
            icon: Icons.cloud_off_outlined,
            title: 'Projects could not be loaded',
            detail: provider.errorMessage ?? '',
            onRetry: provider.load,
          ),
        ],
      ProjectsStatus.ready when provider.rows.isEmpty => [
          _Message(
            icon: Icons.folder_off_outlined,
            title: provider.search.isEmpty
                ? 'Nothing is in production'
                : 'No projects match',
            detail: provider.search.isEmpty
                ? 'Projects show up here once the office puts them into production.'
                : 'Only projects in production are listed.',
          ),
        ],
      ProjectsStatus.loading => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      _ => [
          const SizedBox(height: 16),
          Text(
            _countLabel(provider.totalCount, provider.rows.length),
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          for (final row in provider.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProjectCard(row: row, provider: provider),
            ),
          if (provider.hasMore) _LoadMore(provider: provider),
          // A failure while appending leaves what is already on screen and says
          // what went wrong under it, rather than throwing the list away.
          if (provider.errorMessage != null && provider.rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          ],
        ],
    };
  }

  static String _countLabel(int? total, int shown) {
    if (total == null) return '$shown projects';
    if (shown >= total) return total == 1 ? '1 project' : '$total projects';
    return '$shown of $total projects';
  }
}

/// Applies on submit rather than on every keystroke: each search is a request,
/// the same reason the desktop's projects box waits for Enter.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.provider});

  final ProjectsProvider provider;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.provider.search);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: widget.provider.applySearch,
      decoration: InputDecoration(
        hintText: 'Search projects',
        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close, size: 19, color: AppColors.textMuted),
                onPressed: () {
                  _controller.clear();
                  widget.provider.applySearch('');
                },
              ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.row, required this.provider});

  final ProjectRow row;
  final ProjectsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          // The root navigator: the shell's bottom bar is not a per-tab one, so
          // a detail covers the screen and carries its own way back.
          MaterialPageRoute(
            builder: (_) => ProjectDetailsScreen(row: row, provider: provider),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _Meta(icon: Icons.folder_outlined, text: row.categoryName),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: _Meta(
                      icon: Icons.calendar_today_outlined,
                      text: _dateLabel(row),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: _Meta(
                      icon: Icons.scale_outlined,
                      text: formatTonnes(row.weight),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Always a date still owed: nothing delivered reaches this list.
  static String _dateLabel(ProjectRow row) {
    final date = row.deliveryDate;
    return date == null ? 'No date set' : 'Due ${formatDate(date)}';
  }
}

/// An icon and a line of muted text. It shrink-wraps and flexes only
/// **horizontally** — wrapping the whole thing in `Flexible` would make it a
/// vertically flexible child wherever it sits straight in the card's Column,
/// which has no bounded height inside the list. Callers that put two side by
/// side wrap them at the call site instead.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.provider});

  final ProjectsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: provider.isLoadingMore ? null : provider.loadMore,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: provider.isLoadingMore
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : const Text(
                'Load more',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
