import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../services/system_launcher.dart';
import '../models/swarm_apps.dart';
import '../widgets/extensions_dialog.dart';
import '../shell/companion_bridge_dialog.dart';

class DesktopApp {
  final String name;
  final String command;
  final IconData icon;

  DesktopApp({required this.name, required this.command, required this.icon});

  // Pulls a shared app definition out of SwarmAppRegistry (the single source
  // of truth also used by the hex desktop and the left app drawer) instead
  // of re-declaring its name/icon/command here.
  factory DesktopApp.fromRegistry(String id) {
    final app = SwarmAppRegistry.byId(id);
    assert(app != null, 'Unknown SwarmAppRegistry id: $id');
    return DesktopApp(
      name: app!.name,
      command: app.execCommand ?? app.routePath ?? '',
      icon: app.icon,
    );
  }

  DesktopApp.dialog({required String name, required String command, required IconData icon})
      : this(name: name, command: command, icon: icon);
}

class DesktopAppsGrid extends StatelessWidget {
  final List<DesktopApp> apps = [
    DesktopApp.fromRegistry('cinema'),
    DesktopApp.fromRegistry('gitlens'),
    DesktopApp.fromRegistry('diff'),
    DesktopApp.dialog(
      name: 'IDE Extensions',
      command: '__extensions_dialog__',
      icon: Icons.extension_rounded,
    ),
    DesktopApp.dialog(
      name: 'Sync Beta',
      command: 'alacritty -e bash -c "git pull origin beta && echo Sync Complete && sleep 2"',
      icon: Icons.cloud_sync_rounded,
    ),
    DesktopApp.dialog(
      name: '3 Phone Sync',
      command: '__companion_pool_dialog__',
      icon: Icons.sync_rounded,
    ),
    DesktopApp.fromRegistry('sysopt'),
    DesktopApp.fromRegistry('files'),
    DesktopApp.fromRegistry('claude_desktop'),
    DesktopApp.fromRegistry('claude_code'),
    DesktopApp.fromRegistry('terminal'),
    DesktopApp.fromRegistry('browser'),
    DesktopApp.fromRegistry('sysmon'),
  ];

  DesktopAppsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 40.0, bottom: 20.0),
          child: Text(
            'OS Applications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: SwarmColors.textPrimary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: apps.map((app) => _AppIcon(
            app: app,
            onTap: () {
              if (app.command == '__extensions_dialog__') {
                showDialog(
                  context: context,
                  builder: (_) => const IdeExtensionsDialog(),
                );
              } else if (app.command == '__companion_pool_dialog__') {
                CompanionResourcePoolDialog.show(context);
              } else if (app.command.startsWith('/')) {
                context.go(app.command);
              } else {
                SystemLauncher.launch(
                  context,
                  app.command,
                  displayName: app.name,
                );
              }
            },
          )).toList(),
        ),
      ],
    );
  }
}

class _AppIcon extends StatefulWidget {
  final DesktopApp app;
  final VoidCallback onTap;
  
  const _AppIcon({required this.app, required this.onTap});

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 90,
          height: 110,
          decoration: BoxDecoration(
            color: _hovered ? SwarmColors.accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? SwarmColors.accent.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SwarmColors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: SwarmColors.border,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  widget.app.icon,
                  size: 32,
                  color: _hovered ? SwarmColors.accent : SwarmColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.app.name,
                style: const TextStyle(
                  color: SwarmColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
