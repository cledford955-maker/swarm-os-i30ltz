import 'package:flutter/material.dart';
import '../services/app_installer_service.dart';
import '../services/user_apps_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

/// SWARM OS — App Store
///
/// Search Arch repos + AUR (via yay), install apps in a terminal window,
/// and manage what's on the desktop. Every successful install registers a
/// desktop icon via UserAppsService, which the hex desktop renders as a
/// tile with a real icon and a right-click menu (delete icon / uninstall).
class AppStorePage extends StatefulWidget {
  const AppStorePage({super.key});

  @override
  State<AppStorePage> createState() => _AppStorePageState();
}

class _AppStorePageState extends State<AppStorePage> {
  final _searchCtrl = TextEditingController();
  final _installer = AppInstallerService.instance;
  final _userApps = UserAppsService.instance;

  List<PackageResult> _results = [];
  bool _searching = false;
  String? _searchError;

  // package name → live status line for in-flight installs/uninstalls
  final Map<String, String> _busy = {};

  @override
  void initState() {
    super.initState();
    _userApps.addListener(_onUserAppsChanged);
  }

  @override
  void dispose() {
    _userApps.removeListener(_onUserAppsChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onUserAppsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final results = await _installer.search(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      if (results.isEmpty) {
        _searchError = 'No packages found for "$q" — check the spelling or '
            'install yay for AUR results (sudo pacman -S yay).';
      }
    });
  }

  Future<void> _install(PackageResult pkg) async {
    if (_busy.containsKey(pkg.name)) return;
    setState(() => _busy[pkg.name] = 'Starting…');
    final ok = await _installer.installAndRegister(
      pkg.name,
      onStatus: (s) {
        if (mounted) setState(() => _busy[pkg.name] = s);
      },
    );
    if (!mounted) return;
    setState(() => _busy.remove(pkg.name));
    if (ok) {
      final app = _userApps.byPackage(pkg.name);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: SwarmColors.statusOnline,
        content: Text(
          app != null
              ? '✅ Installed ${pkg.name} — icon added to your desktop'
              : '✅ Installed ${pkg.name} (no desktop entry found — launch it from Apps)',
          style: const TextStyle(color: Colors.black, fontSize: 12),
        ),
        duration: const Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: SwarmColors.statusCritical,
        content: Text(
          '⚠️ ${pkg.name} install did not complete',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<void> _uninstallUserApp(UserApp app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwarmColors.bgElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: SwarmColors.border)),
        title: Text('Uninstall ${app.name}?',
            style: SwarmTextStyles.h3.copyWith(color: SwarmColors.textPrimary)),
        content: Text(
          'This removes the ${app.packageName} package from your system AND '
          'deletes its desktop icon. Its settings and user data are removed '
          'too (pacman -Rns).',
          style: SwarmTextStyles.bodySmall.copyWith(color: SwarmColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: SwarmColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uninstall', style: TextStyle(color: SwarmColors.statusCritical)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy[app.packageName] = 'Starting…');
    final ok = await _installer.uninstallAndCleanup(
      app.packageName,
      onStatus: (s) {
        if (mounted) setState(() => _busy[app.packageName] = s);
      },
    );
    if (!mounted) return;
    setState(() => _busy.remove(app.packageName));
    if (ok) {
      await _userApps.removeByPackage(app.packageName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: SwarmColors.statusOnline,
          content: Text('🗑️ Uninstalled — icon removed from desktop',
              style: TextStyle(color: Colors.black, fontSize: 12)),
          duration: const Duration(seconds: 3),
        ));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: SwarmColors.statusCritical,
        content: Text('⚠️ ${app.packageName} uninstall did not complete',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = _userApps.apps;

    return Scaffold(
      backgroundColor: SwarmColors.bg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SwarmColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SwarmColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.storefront_rounded, color: SwarmColors.accent, size: 28),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SWARM APP STORE',
                    style: SwarmTextStyles.headlineMedium.copyWith(
                        color: SwarmColors.textPrimary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Search Arch repos & AUR — install apps, get a desktop icon',
                    style: SwarmTextStyles.bodyMedium.copyWith(color: SwarmColors.textMuted)),
              ]),
            ]),
            const SizedBox(height: 20),

            // ── Search bar ─────────────────────────────────────
            Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: SwarmColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SwarmColors.borderSubtle),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: SwarmColors.textPrimary),
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search apps — e.g. gimp, vlc, kdenlive, steam…',
                      hintStyle: const TextStyle(color: SwarmColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: SwarmColors.textMuted, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: SwarmColors.textMuted, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _results = [];
                                  _searchError = null;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: SwarmColors.accent))
                    : const Icon(Icons.search_rounded, size: 18),
                label: const Text('SEARCH'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Installed desktop apps ─────────────────────────
            if (installed.isNotEmpty) ...[
              Text('ON YOUR DESKTOP (${installed.length})',
                  style: SwarmTextStyles.label.copyWith(color: SwarmColors.textMuted)),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: installed.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final app = installed[i];
                    return _InstalledChip(
                      app: app,
                      busy: _busy[app.packageName],
                      onUninstall: () => _uninstallUserApp(app),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Results ────────────────────────────────────────
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator(color: SwarmColors.accent))
                  : _searchError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded,
                                  color: SwarmColors.textMuted, size: 48),
                              const SizedBox(height: 12),
                              Text(_searchError!,
                                  style: const TextStyle(color: SwarmColors.textMuted),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apps_rounded,
                                      color: SwarmColors.accent.withValues(alpha: 0.3), size: 56),
                                  const SizedBox(height: 16),
                                  Text('Search to install anything from Arch or the AUR',
                                      style: SwarmTextStyles.body
                                          .copyWith(color: SwarmColors.textMuted)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) => _ResultRow(
                                pkg: _results[i],
                                installed: _userApps.isInstalled(_results[i].name),
                                busy: _busy[_results[i].name],
                                onInstall: () => _install(_results[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Result row ──────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final PackageResult pkg;
  final bool installed;
  final String? busy;
  final VoidCallback onInstall;

  const _ResultRow({
    required this.pkg,
    required this.installed,
    required this.busy,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pkg.isAur ? SwarmColors.agentAmber : SwarmColors.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SwarmColors.borderSubtle),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Icon(
            pkg.isAur ? Icons.egg_alt_rounded : Icons.inventory_2_rounded,
            color: accent, size: 20,
          ),
        ),
        title: Row(children: [
          Flexible(
            child: Text(pkg.name,
                style: const TextStyle(
                    color: SwarmColors.textPrimary,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Text(pkg.isAur ? 'AUR' : pkg.repo.toUpperCase(),
                style: TextStyle(
                    color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          Text(pkg.version,
              style: const TextStyle(color: SwarmColors.textMuted, fontSize: 11)),
        ]),
        subtitle: Text(
          busy ?? pkg.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: busy != null ? SwarmColors.accent : SwarmColors.textMuted,
              fontSize: 11),
        ),
        trailing: installed
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: SwarmColors.statusOnline, size: 18),
                SizedBox(width: 6),
                Text('INSTALLED',
                    style: TextStyle(color: SwarmColors.statusOnline, fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ])
            : ElevatedButton.icon(
                onPressed: busy != null ? null : onInstall,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('INSTALL', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwarmColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
      ),
    );
  }
}

// ─── Installed chip (horizontal rail) ────────────────────────────────────────

class _InstalledChip extends StatelessWidget {
  final UserApp app;
  final String? busy;
  final VoidCallback onUninstall;

  const _InstalledChip({
    required this.app,
    required this.busy,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SwarmColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SwarmColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              app.iconPath.isNotEmpty
                  ? Icons.apps_rounded
                  : Icons.download_rounded,
              color: SwarmColors.accent, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(app.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: SwarmColors.textPrimary,
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            busy ?? app.packageName,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: busy != null ? SwarmColors.accent : SwarmColors.textMuted,
                fontSize: 10),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: busy != null ? null : onUninstall,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SwarmColors.statusCritical.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SwarmColors.statusCritical.withValues(alpha: 0.4)),
                ),
                child: const Text('UNINSTALL',
                    style: TextStyle(
                        color: SwarmColors.statusCritical, fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
