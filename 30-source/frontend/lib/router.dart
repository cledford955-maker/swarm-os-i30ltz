import 'package:go_router/go_router.dart';
import 'shell/swarm_shell.dart';
import 'hub/hub_page.dart';
import 'pages/hex_desktop_page.dart';
import 'pages/grub_terminal_page.dart';
import 'pages/file_explorer_page.dart';
import 'pages/settings_page.dart';
import 'pages/models_page.dart';
import 'pages/swarm_page.dart';
import 'pages/sysopt_page.dart';
import 'screens/task_screen.dart';
import 'screens/splash_router.dart';
import 'screens/cyber_stone_lock_screen.dart';
import 'screens/cannabis_mode_screen.dart';
import 'coder/coder_page.dart';
import 'screens/memory_screen.dart';
import 'screens/agents_screen.dart';
import 'agent/apex_workstation.dart';
import 'pages/vital_page.dart';
import 'agent/ui_tandem_studio.dart';
import 'pages/lucille_chat_page.dart';
import 'pages/test_lucy_server_page.dart';
import 'pages/apps_page.dart';
import 'pages/app_store_page.dart';
import 'pages/droid_marketplace_page.dart';
import 'pages/backend_page.dart';
import 'pages/nvidia_page.dart';
import 'pages/telemetry_page.dart';
import 'pages/vm_manager_page.dart';
import 'pages/install_swarm_os_page.dart';
import 'pages/developer_ecosystem_page.dart';
import 'pages/app_store_dashboard_page.dart';
import 'pages/cloud_workspaces_page.dart';
import 'pages/device_mirror_page.dart';
import 'pages/security_audit_page.dart';
import 'pages/cinema_page.dart';
import 'pages/git_lens_page.dart';
import 'pages/diff_viewer_page.dart';
import 'pages/command_reference_page.dart';
import 'pages/web_demo_coming_soon.dart';

/// SWARM OS Route Configuration
/// Mirrors the 11 routes from the Next.js App Router
// Web demo build (--dart-define=MOCK=true): skip splash + stone-cipher lock.
const _demoMode = bool.fromEnvironment('MOCK');

// Desktop-only features shown as "coming soon" in the web demo.
const _demoUnavailable = <String, List<String>>{
  '/coder': ['Coder IDE', 'Full code editor with git, Android and Apple build panels, task runner and Ollama assistant.'],
  '/ide': ['Coder IDE', 'Full code editor with git, Android and Apple build panels, task runner and Ollama assistant.'],
  '/explorer': ['File Explorer', 'Browse and manage the files on your SWARM OS machine.'],
  '/files-explorer': ['File Explorer', 'Browse and manage the files on your SWARM OS machine.'],
  '/gitlens': ['GitLens', 'Repository history, blame and diffs across your local workspaces.'],
  '/git': ['GitLens', 'Repository history, blame and diffs across your local workspaces.'],
  '/diff': ['Diff Viewer', 'Side-by-side file and repository diffs.'],
  '/grub': ['GRUB Terminal', 'Multi-pane terminal with tabs, split view and ANSI colour.'],
  '/terminal-grub': ['GRUB Terminal', 'Multi-pane terminal with tabs, split view and ANSI colour.'],
  '/install': ['Installer', 'Install SWARM OS to an NVMe drive from the live USB.'],
  '/mirror': ['Device Mirror', 'Mirror and control your paired Android phone.'],
  '/cinema': ['Cinema', 'Local video library and player.'],
  '/videos': ['Cinema', 'Local video library and player.'],
  '/studio': ['Cinema', 'Local video library and player.'],
};

final goRouter = GoRouter(
  initialLocation: _demoMode ? '/' : '/splash',
  redirect: (context, state) {
    if (!_demoMode) return null;
    final loc = state.matchedLocation;
    if (loc == '/splash' || loc == '/lock') return '/';
    final info = _demoUnavailable[loc];
    if (info != null) {
      return Uri(path: '/coming-soon', queryParameters: {'f': info[0], 'd': info[1]}).toString();
    }
    return null;
  },
  routes: [
    // Standalone full-screen 1999 Electric Blue Trans-Am WS6 Splash & Cockpit Loading
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashRouter(child: HubPage()),
    ),

    // Standalone full-screen Cyber-Mystic Visual Tile Lock Screen
    GoRoute(
      path: '/lock',
      builder: (_, __) => const CyberStoneLockScreen(),
    ),

    // Standalone full-screen private garden mode (hidden cipher)
    GoRoute(
      path: '/garden',
      builder: (_, __) => const CannabisModeScreen(),
    ),

    // The shell wraps all main routes with desktop chrome (top bar, window manager)
    ShellRoute(
      builder: (context, state, child) => SwarmShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HexDesktopPage()),
        GoRoute(
          path: '/coming-soon',
          builder: (_, state) => WebDemoComingSoonPage(
            feature: state.uri.queryParameters['f'] ?? 'This feature',
            blurb: state.uri.queryParameters['d'] ?? '',
          ),
        ),
        GoRoute(path: '/hub', builder: (_, __) => const HubPage()),
        GoRoute(path: '/reference', builder: (_, __) => const CommandReferencePage()),
        GoRoute(path: '/agent/lucille', builder: (_, __) => const LucilleChatPage()),
        GoRoute(path: '/agent/apex', builder: (_, __) => const ApexWorkstation()),
        GoRoute(path: '/agent/ui_tandem', builder: (_, __) => const UiTandemStudio()),
        GoRoute(path: '/agent/vital', builder: (_, __) => const VitalPage()),
        GoRoute(path: '/agent/:id', builder: (_, state) => const ApexWorkstation()),
        GoRoute(path: '/apps', builder: (_, __) => const AppsPage()),
        GoRoute(path: '/appstore', builder: (_, __) => const AppStorePage()),
        GoRoute(path: '/droid-tools', builder: (_, __) => const DroidMarketplacePage()),
        GoRoute(path: '/backend', builder: (_, __) => const BackendPage()),
        GoRoute(path: '/apex', builder: (_, __) => const ApexWorkstation()),
        GoRoute(path: '/coder', builder: (_, __) => const CoderPage()),
        GoRoute(path: '/ide',   builder: (_, __) => const CoderPage()),
        GoRoute(path: '/models', builder: (_, __) => const ModelsPage()),
        GoRoute(path: '/nvidia', builder: (_, __) => const NvidiaPage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/swarm', builder: (_, __) => const SwarmPage()),
        GoRoute(path: '/sysopt', builder: (_, __) => const SysOptPage()),
        GoRoute(path: '/telemetry', builder: (_, __) => const TelemetryPage()),
        GoRoute(path: '/auth', builder: (_, __) => const CyberStoneLockScreen(isReconfiguring: true)),
        // Garden-cipher-only reset. Prompts for the main cipher, then walks
        // the user through picking a new garden pattern (skippable).
        GoRoute(path: '/auth/garden', builder: (_, __) => const CyberStoneLockScreen(isReconfiguringGarden: true)),
        GoRoute(path: '/vital', builder: (_, __) => const VitalPage()),
        GoRoute(path: '/ui_tandem', builder: (_, __) => const UiTandemStudio()),
        GoRoute(path: '/tandem', builder: (_, __) => const UiTandemStudio()),
        GoRoute(path: '/lucille', builder: (_, __) => const LucilleChatPage()),
        GoRoute(path: '/chat', builder: (_, __) => const LucilleChatPage()),
        GoRoute(path: '/tasks', builder: (_, __) => const TaskScreen()),
        GoRoute(path: '/memory', builder: (_, __) => const MemoryScreen()),
        GoRoute(path: '/agents', builder: (_, __) => const AgentsScreen()),
        GoRoute(path: '/vms', builder: (_, __) => const VmManagerPage()),
        GoRoute(path: '/install', builder: (_, __) => const InstallSwarmOsPage()),
        GoRoute(path: '/ecosystem', builder: (_, __) => const DeveloperEcosystemPage()),
        GoRoute(path: '/appstore-dashboard', builder: (_, __) => const AppStoreDashboardPage()),
        GoRoute(path: '/cloud-workspaces', builder: (_, __) => const CloudWorkspacesPage()),
        GoRoute(path: '/mirror', builder: (_, __) => const DeviceMirrorPage()),
        GoRoute(path: '/security-audit', builder: (_, __) => const SecurityAuditPage()),
        GoRoute(path: '/cinema', builder: (_, state) => CinemaPage(initialVideoPath: state.uri.queryParameters['file'])),
        GoRoute(path: '/videos', builder: (_, state) => CinemaPage(initialVideoPath: state.uri.queryParameters['file'])),
        GoRoute(path: '/studio', builder: (_, state) => CinemaPage(initialVideoPath: state.uri.queryParameters['file'])),
        GoRoute(path: '/gitlens', builder: (_, state) => GitLensPage(initialWorkspacePath: state.uri.queryParameters['path'])),
        GoRoute(path: '/git', builder: (_, state) => GitLensPage(initialWorkspacePath: state.uri.queryParameters['path'])),
        GoRoute(
          path: '/diff',
          builder: (_, state) => DiffViewerPage(
            oldFilePath: state.uri.queryParameters['old'],
            newFilePath: state.uri.queryParameters['new'],
            repoPath: state.uri.queryParameters['repo'],
          ),
        ),
        GoRoute(path: '/test-lucy', builder: (_, __) => const TestLucyServerPage()),
        GoRoute(
          path: '/grub',
          builder: (_, state) => GrubTerminalPage(
            startPath: state.uri.queryParameters['path'],
          ),
        ),
        GoRoute(path: '/terminal-grub', builder: (_, state) =>
          GrubTerminalPage(startPath: state.uri.queryParameters['path'])),
        GoRoute(
          path: '/explorer',
          builder: (_, state) => FileExplorerPage(
            initialPath: state.uri.queryParameters['path'],
          ),
        ),
        GoRoute(path: '/files-explorer', builder: (_, state) =>
          FileExplorerPage(initialPath: state.uri.queryParameters['path'])),
      ],
    ),
  ],
  errorBuilder: (context, state) => const HubPage(),
);
