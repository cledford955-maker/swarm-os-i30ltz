import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';
import '../providers/sentinel_providers.dart';
import '../widgets/extensions_dialog.dart';
import '../services/screenshot_service.dart';
import '../services/system_launcher.dart';
import 'osd_hud.dart';
import 'power_controls.dart';
import '../widgets/vital_tracker_dialog.dart';
import '../services/lucille_voice_service.dart';

/// SWARM OS Top Navigation Bar
/// Port of components/top-bar.tsx with global OpenRouter live balance
class SwarmTopBar extends ConsumerWidget {
  const SwarmTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String location = '/';
    try {
      location = GoRouterState.of(context).uri.toString();
    } catch (_) {}
    
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: SwarmColors.bgSurface,
        border: Border(
          bottom: BorderSide(color: SwarmColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Logo / Brand (Click to return to Hub)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: SwarmColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SwarmColors.accentGlow,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('SWARM', style: SwarmTextStyles.label.copyWith(
                      color: SwarmColors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    )),
                    const SizedBox(width: 4),
                    Text('OS', style: SwarmTextStyles.label.copyWith(
                      color: SwarmColors.textMuted,
                      letterSpacing: 2.0,
                    )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwarmColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        'v6.2.69',
                        style: SwarmTextStyles.codeSmall.copyWith(
                          color: SwarmColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwarmColors.agentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        'I320K3-N-I30LTZ',
                        style: SwarmTextStyles.codeSmall.copyWith(
                          color: SwarmColors.agentCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ─── Back to Hub Button ──────────────────────────────
          Tooltip(
            message: 'Return to Central Swarm Hub',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: location == '/'
                        ? SwarmColors.accent.withValues(alpha: 0.08)
                        : SwarmColors.agentCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: location == '/'
                          ? SwarmColors.border
                          : SwarmColors.agentCyan.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hub_rounded,
                        color: location == '/' ? SwarmColors.accent : SwarmColors.agentCyan,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'BACK TO HUB',
                        style: SwarmTextStyles.codeSmall.copyWith(
                          color: location == '/' ? SwarmColors.accent : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Navigation Links
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _NavItem(label: 'HUB', route: '/', current: location),
                  _NavItem(label: 'LUCILLE', route: '/lucille', current: location),
                  _NavItem(label: 'FORGE', route: '/forge', current: location),
                  _NavItem(label: 'APPS', route: '/apps', current: location),
                  _NavItem(label: 'IDE', route: '/ide', current: location),
                  _NavItem(label: 'TASKS', route: '/tasks', current: location),
                  _NavItem(label: 'MODELS', route: '/models', current: location),
                  _NavItem(label: 'SWARM', route: '/swarm', current: location),
                  _NavItem(label: 'SYSOPT', route: '/sysopt', current: location),
                  _NavItem(label: 'BACKEND', route: '/backend', current: location),
                  _NavItem(label: 'TELEMETRY', route: '/telemetry', current: location),
                  _NavItem(label: 'SETTINGS', route: '/settings', current: location),
                ],
              ),
            ),
          ),

          // ─── Right Action Items ──────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Universal Stop Lucille Speaking / Mute / Wait for Words Button
                  const _LucilleVoiceSpeechMuteTopButton(),
                  const SizedBox(width: 8),

                  // Chat with Lucille Direct Button
                  _ChatWithLucilleTopButton(isActive: location == '/lucille' || location == '/chat'),
                  const SizedBox(width: 8),

                  // Forge Studio Direct Button (Lucille Core)
                  _ForgeTopButton(isActive: location == '/forge' || location == '/coder'),
                  const SizedBox(width: 8),

                  // UI Tandem (Claude + DeepSeek) Direct Button
                  _UiTandemTopButton(isActive: location == '/ui_tandem' || location == '/tandem'),
                  const SizedBox(width: 8),

                  // Dr. Vital Direct Button
                  _VitalTopButton(isActive: location == '/vital'),
                  const SizedBox(width: 8),

                  // Antigravity IDE Direct Launch Button
                  const _AntigravityIdeTopButton(),
                  const SizedBox(width: 8),

                  // Screenshot Quick Access Button
                  const _ScreenshotTopButton(),
                  const SizedBox(width: 8),

                  // IDE Extensions Quick Access Button
                  _ExtensionsTopButton(),
                  const SizedBox(width: 10),

                  // Live OpenRouter Balance
                  const OpenRouterBalanceChip(),
                  const SizedBox(width: 12),

                  // Live System HUD
                  const SwarmHud(),
                  const SizedBox(width: 8),
                  const HardwareControls(), // Gamepad, Wifi, BT, Audio
                  const SizedBox(width: 16),
                  const PowerControls(), // OS and Window Controls
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Global OpenRouter Balance Widget shown on every single page
class OpenRouterBalanceChip extends ConsumerWidget {
  const OpenRouterBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(openRouterBalanceProvider);

    return Tooltip(
      message: 'OpenRouter Balance · Click to refresh · Long press for Settings Vault',
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.invalidate(openRouterBalanceProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing OpenRouter balance...'),
                duration: Duration(seconds: 1),
                backgroundColor: SwarmColors.bgElevated,
              ),
            );
          },
          onLongPress: () => context.go('/settings'),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SwarmColors.bgElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: SwarmColors.agentCyan.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: SwarmColors.agentCyan.withValues(alpha: 0.1),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: SwarmColors.agentCyan,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OPENROUTER',
                      style: SwarmTextStyles.codeSmall.copyWith(
                        fontSize: 7.5,
                        color: SwarmColors.textMuted,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    balanceAsync.when(
                      data: (balance) => Text(
                        balance,
                        style: SwarmTextStyles.codeSmall.copyWith(
                          fontSize: 11,
                          color: SwarmColors.accentSky,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(SwarmColors.agentCyan),
                        ),
                      ),
                      error: (_, __) => Text(
                        'Offline',
                        style: SwarmTextStyles.codeSmall.copyWith(
                          fontSize: 10,
                          color: SwarmColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: balanceAsync.maybeWhen(
                      data: (b) => b == 'No Key' ? SwarmColors.warning : SwarmColors.success,
                      orElse: () => SwarmColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Extensions Hub Button in Top Bar
class _ExtensionsTopButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Get the new extensions for VS Code, JetBrains, and more',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const IdeExtensionsDialog(),
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SwarmColors.agentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: SwarmColors.agentPurple.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.extension_rounded, color: SwarmColors.agentPurple, size: 13),
                const SizedBox(width: 5),
                Text(
                  'EXTENSIONS',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: SwarmColors.agentPurple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat with Lucille Direct Top Button
class _ChatWithLucilleTopButton extends StatelessWidget {
  const _ChatWithLucilleTopButton({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Chat with Lucille · Voice & Swarm AI Orchestrator',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/lucille'),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? SwarmColors.lucille.withValues(alpha: 0.3)
                  : SwarmColors.lucille.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: SwarmColors.lucille.withValues(alpha: isActive ? 0.95 : 0.45),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: SwarmColors.lucille.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_rounded, size: 14, color: SwarmColors.lucille),
                const SizedBox(width: 5),
                Text(
                  'CHAT WITH LUCILLE',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: isActive ? Colors.white : SwarmColors.lucille,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Forge Studio Quick Access Button in Top Bar
class _ForgeTopButton extends StatelessWidget {
  const _ForgeTopButton({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Lucille Core Forge · Code & Development Workstation',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/forge'),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? SwarmColors.accent.withValues(alpha: 0.28)
                  : SwarmColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: SwarmColors.accent.withValues(alpha: isActive ? 0.9 : 0.4),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: SwarmColors.accentGlow.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.build_circle_rounded, color: SwarmColors.accent, size: 14),
                const SizedBox(width: 5),
                Text(
                  'FORGE',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: isActive ? Colors.white : SwarmColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VitalTopButton extends StatelessWidget {
  const _VitalTopButton({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    const accentGreen = Color(0xFF00E676);
    return Tooltip(
      message: 'Dr. Vital (Food, Water & 3x Daily Meds Intake Companion)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => VitalTrackerDialog.show(context),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? accentGreen.withValues(alpha: 0.28)
                  : accentGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accentGreen.withValues(alpha: isActive ? 0.9 : 0.4),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accentGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.medical_services_rounded, color: accentGreen, size: 14),
                const SizedBox(width: 5),
                Text(
                  'DR. VITAL',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: isActive ? Colors.white : accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// UI Tandem Direct Button in Top Bar (Claude 3.7 + DeepSeek R1 Dual Engine)
class _UiTandemTopButton extends StatelessWidget {
  final bool isActive;
  const _UiTandemTopButton({required this.isActive});

  @override
  Widget build(BuildContext context) {
    const accentCyan = Color(0xFF00E5FF);
    return Tooltip(
      message: 'UI Tandem (Claude 3.7 + DeepSeek R1) · Dual-Engine UI Studio',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/ui_tandem'),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentCyan.withValues(alpha: isActive ? 0.35 : 0.15),
                  const Color(0xFFD500F9).withValues(alpha: isActive ? 0.25 : 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accentCyan.withValues(alpha: isActive ? 0.9 : 0.45),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accentCyan.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_fix_high_rounded, color: accentCyan, size: 14),
                const SizedBox(width: 5),
                Text(
                  'UI TANDEM',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: isActive ? Colors.white : accentCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Antigravity IDE Direct Launch Button in Top Bar
class _AntigravityIdeTopButton extends StatelessWidget {
  const _AntigravityIdeTopButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Launch Google Antigravity IDE (Antigravity 2.0 Autonomous Platform)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            SystemLauncher.launchAntigravity(context);
          },
          onLongPress: () => context.go('/agent/antigravity'),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4285F4).withValues(alpha: 0.25),
                  const Color(0xFF00E5FF).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF4285F4).withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Color(0xFF00E5FF), size: 13),
                const SizedBox(width: 5),
                Text(
                  'ANTIGRAVITY IDE',
                  style: SwarmTextStyles.codeSmall.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screenshot Capture Button in Top Bar (Arch Linux Spectacle Wayland Integration)
class _ScreenshotTopButton extends StatelessWidget {
  const _ScreenshotTopButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Take Screenshot (Arch Spectacle)',
      color: SwarmColors.bgSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: SwarmColors.border, width: 1),
      ),
      offset: const Offset(0, 36),
      onSelected: (action) async {
        final service = ScreenshotService();
        switch (action) {
          case 'fullscreen':
            final res = await service.captureFullScreen();
            if (context.mounted && res.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: SwarmColors.bgElevated,
                  content: Text('📸 Fullscreen captured & copied to clipboard!\n${res.filePath?.split('/').last}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            break;
          case 'region':
            final res = await service.captureRegion();
            if (context.mounted && res.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: SwarmColors.bgElevated,
                  content: Text('✂️ Selected region saved & copied to clipboard!\n${res.filePath?.split('/').last}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            break;
          case 'window':
            final res = await service.captureActiveWindow();
            if (context.mounted && res.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: SwarmColors.bgElevated,
                  content: Text('🪟 Active window saved & copied to clipboard!\n${res.filePath?.split('/').last}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            break;
          case 'folder':
            await service.openScreenshotsFolder();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'fullscreen',
          child: Row(
            children: [
              const Icon(Icons.fullscreen, color: SwarmColors.accentCyan, size: 16),
              const SizedBox(width: 8),
              Text('Capture Fullscreen', style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'region',
          child: Row(
            children: [
              const Icon(Icons.crop, color: SwarmColors.accent, size: 16),
              const SizedBox(width: 8),
              Text('Capture Region / Box', style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'window',
          child: Row(
            children: [
              const Icon(Icons.window, color: SwarmColors.agentGreen, size: 16),
              const SizedBox(width: 8),
              Text('Capture Active Window', style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textPrimary)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: 'folder',
          child: Row(
            children: [
              const Icon(Icons.folder_open, color: SwarmColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Text('Open Screenshots Folder', style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textMuted)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: SwarmColors.agentCyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: SwarmColors.agentCyan.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: SwarmColors.agentCyan, size: 13),
            const SizedBox(width: 5),
            Text(
              'CAPTURE',
              style: SwarmTextStyles.codeSmall.copyWith(
                color: SwarmColors.agentCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final String route;
  final String current;
  const _NavItem({required this.label, required this.route, required this.current});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.current == widget.route;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? SwarmColors.accentSurface
                : _hovered
                    ? SwarmColors.bgHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isActive
                ? Border.all(color: SwarmColors.accentDim, width: 0.5)
                : null,
          ),
          child: Text(
            widget.label,
            style: SwarmTextStyles.labelSmall.copyWith(
              color: isActive
                  ? SwarmColors.accent
                  : _hovered
                      ? SwarmColors.textPrimary
                      : SwarmColors.textMuted,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Universal TopBar Button: Instantly Stop Lucille Speaking, Wait for Words, or Mute
class _LucilleVoiceSpeechMuteTopButton extends StatefulWidget {
  const _LucilleVoiceSpeechMuteTopButton();

  @override
  State<_LucilleVoiceSpeechMuteTopButton> createState() => _LucilleVoiceSpeechMuteTopButtonState();
}

class _LucilleVoiceSpeechMuteTopButtonState extends State<_LucilleVoiceSpeechMuteTopButton> {
  final LucilleVoiceService _voice = LucilleVoiceService();

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSpeaking = _voice.isSpeaking;
    final isMuted = _voice.isMuted;
    final isWaiting = _voice.isWaitingForWords;

    Color buttonColor;
    String label;
    IconData icon;

    if (isMuted) {
      buttonColor = const Color(0xFFFF6B6B);
      label = 'MUTED';
      icon = Icons.volume_off_rounded;
    } else if (isSpeaking) {
      buttonColor = SwarmColors.lucille;
      label = 'STOP LUCILLE';
      icon = Icons.stop_circle_rounded;
    } else if (isWaiting) {
      buttonColor = SwarmColors.agentCyan;
      label = 'LISTENING...';
      icon = Icons.hearing_rounded;
    } else {
      buttonColor = SwarmColors.accent;
      label = 'VOICE READY';
      icon = Icons.mic_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Stop Speaking / Wait for Words button
        Tooltip(
          message: isSpeaking
              ? 'Click to Stop Lucille Speaking & Wait for Words'
              : 'Click to Put Lucille on Standby / Wait for Words',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _voice.stopAndListen();
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('⏹ Lucille speech stopped — Listening for next words...'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSpeaking
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.25)
                      : buttonColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSpeaking
                        ? const Color(0xFFFF6B6B)
                        : buttonColor.withValues(alpha: 0.5),
                    width: isSpeaking ? 1.5 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSpeaking ? Icons.stop_circle_rounded : icon,
                      size: 14,
                      color: isSpeaking ? const Color(0xFFFF6B6B) : buttonColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: SwarmTextStyles.codeSmall.copyWith(
                        color: isSpeaking ? const Color(0xFFFF6B6B) : buttonColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Quick Mute / Unmute Button
        Tooltip(
          message: isMuted ? 'Unmute Lucille Voice' : 'Mute Lucille Voice',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _voice.toggleMute(),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isMuted
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isMuted ? const Color(0xFFFF6B6B) : Colors.white24,
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 14,
                  color: isMuted ? const Color(0xFFFF6B6B) : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
