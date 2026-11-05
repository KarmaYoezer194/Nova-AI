import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';
import '../../app/nova_tokens.dart';
import '../../app/nova_typography.dart';
import '../../models/project.dart';

/// A small square in the project's colour.
class ProjectSwatch extends StatelessWidget {
  const ProjectSwatch({
    super.key,
    required this.projectId,
    this.size = NovaSize.swatch,
  });

  final String projectId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = NovaColors.of(context).forProject(projectId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.dot,
        borderRadius: BorderRadius.circular(size / 3),
      ),
    );
  }
}

/// A project in the sidebar grid: a colour square with the name under it
/// (up to two lines), on the project's tinted tile. Tapping it opens the
/// project page.
class NovaProjectTile extends StatelessWidget {
  const NovaProjectTile({
    super.key,
    required this.project,
    required this.onTap,
  });

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = NovaColors.of(context).forProject(project.id);
    final shape = BorderRadius.circular(NovaRadius.button);
    return Semantics(
      button: true,
      label: 'Open project ${project.name}',
      excludeSemantics: true,
      child: Material(
        color: colors.tile,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: NovaSize.iconButton + NovaSpace.sm,
            ),
            child: Padding(
              padding: const EdgeInsets.all(NovaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProjectSwatch(
                    projectId: project.id,
                    size: NovaSize.projectSquare,
                  ),
                  const SizedBox(height: NovaSpace.sm + 2),
                  Text(
                    project.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NovaText.of(context).tileTitle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The project pill in the top bar: the project's tile colour and label
/// colour. Tapping it opens the project page.
class NovaProjectPill extends StatelessWidget {
  const NovaProjectPill({
    super.key,
    required this.project,
    required this.onPressed,
  });

  final Project project;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = NovaColors.of(context).forProject(project.id);
    return Tooltip(
      message: 'Open project',
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: colors.tile,
          foregroundColor: colors.label,
          shape: const StadiumBorder(),
          minimumSize: const Size(NovaSize.chip, NovaSize.chip),
          padding: const EdgeInsets.symmetric(horizontal: NovaSpace.md),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: NovaText.of(context).small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProjectSwatch(projectId: project.id, size: NovaSize.swatchSmall),
            const SizedBox(width: NovaSpace.sm),
            Flexible(
              child: Text(project.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
