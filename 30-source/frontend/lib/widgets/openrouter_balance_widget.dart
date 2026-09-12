import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/openrouter_balance_service.dart';

/// Compact OpenRouter balance chip for top bar / HUD overlay.
class OpenRouterBalanceWidget extends StatelessWidget {
  const OpenRouterBalanceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenRouterBalanceService>(
      builder: (context, svc, _) {
        if (!svc.hasKey) {
          return _chip(
            icon: Icons.key_off,
            label: 'OR: no key',
            color: Colors.grey,
            onTap: () => _showKeyDialog(context, svc),
          );
        }

        if (svc.loading && svc.balance == null) {
          return _chip(
            icon: Icons.sync,
            label: 'OR: ...',
            color: Colors.amber,
          );
        }

        if (svc.error != null && svc.balance == null) {
          return _chip(
            icon: Icons.error_outline,
            label: 'OR: err',
            color: Colors.redAccent,
            onTap: () => svc.fetchBalance(),
          );
        }

        final b = svc.balance!;
        final Color balColor;
        if (!b.hasLimit) {
          balColor = const Color(0xFF00E5FF);
        } else if (b.remaining > 5.0) {
          balColor = const Color(0xFF00E676);
        } else if (b.remaining > 1.0) {
          balColor = Colors.amber;
        } else {
          balColor = Colors.redAccent;
        }

        return _chip(
          icon: Icons.account_balance_wallet_outlined,
          label: b.hasLimit
              ? 'OR: ${b.displayUsage} / ${b.displayLimit}'
              : 'OR: ${b.displayUsage}',
          color: balColor,
          onTap: () => _showDetailDialog(context, svc),
        );
      },
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKeyDialog(BuildContext context, OpenRouterBalanceService svc) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('OpenRouter API Key',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'sk-or-v1-...',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00E5FF)),
            ),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
            ),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                svc.setApiKey(ctrl.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context, OpenRouterBalanceService svc) {
    final b = svc.balance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet,
                color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 8),
            Text('OpenRouter Balance',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (b?.label != null) _detailRow('Key', b!.label!),
            _detailRow('Usage', b?.displayUsage ?? '—'),
            _detailRow('Limit', b?.displayLimit ?? '—'),
            if (b?.hasLimit == true)
              _detailRow('Remaining', b!.displayRemaining),
            _detailRow('Tier', b?.isFreeTier == true ? 'Free' : 'Paid'),
            const SizedBox(height: 12),
            if (svc.error != null)
              Text('Error: ${svc.error}',
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              svc.clearApiKey();
              Navigator.pop(ctx);
            },
            child: const Text('Remove Key',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => svc.fetchBalance(),
            child: const Text('Refresh',
                style: TextStyle(color: Color(0xFF00E5FF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 20),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}