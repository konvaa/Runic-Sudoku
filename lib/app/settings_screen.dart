import 'package:flutter/material.dart';

import '../core/purchases/purchase_service.dart';
import 'app.dart';

/// Settings shell: theme selection + entitlement (remove ads) actions.
class SettingsScreen extends StatefulWidget {
  final AppServices services;

  const SettingsScreen({super.key, required this.services});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _removeAdsOwned = false;

  @override
  void initState() {
    super.initState();
    _refreshOwnership();
  }

  Future<void> _refreshOwnership() async {
    final owned = await widget.services.purchases.isRemoveAdsOwned() ||
        widget.services.appController.removeAdsPurchased;
    if (mounted) setState(() => _removeAdsOwned = owned);
  }

  Future<void> _purchaseRemoveAds() async {
    setState(() => _busy = true);
    final result = await widget.services.purchases.purchaseRemoveAds();
    await widget.services.analytics.log('purchase_attempt', {
      'product': ProductIds.removeAds,
      'status': result.status.name,
    });
    // Persist entitlement on the profile so it survives restarts (Phase 3).
    if (result.isEntitled) {
      await widget.services.appController.setRemoveAdsPurchased();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _removeAdsOwned = result.isEntitled;
    });
    _toast('Remove ads: ${result.status.name}');
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final results = await widget.services.purchases.restorePurchases();
    final entitled = results.any((r) => r.isEntitled);
    if (entitled) {
      await widget.services.appController.setRemoveAdsPurchased();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _removeAdsOwned = entitled;
    });
    _toast('Restored ${results.length} purchase(s)');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tm = widget.services.themeManager;
    final isDark = tm.current.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: tm,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionHeader('Appearance'),
              SwitchListTile(
                title: const Text('Dark mode'),
                value: isDark,
                onChanged: (_) => tm.toggleBrightness(),
              ),
              for (final theme in tm.available)
                RadioListTile<String>(
                  title: Text(theme.displayName),
                  value: theme.id,
                  groupValue: tm.current.id,
                  onChanged: (id) {
                    if (id != null) tm.selectTheme(id);
                  },
                ),
              const Divider(height: 32),
              const _SectionHeader('Purchases'),
              ListTile(
                title: const Text('Remove ads'),
                subtitle:
                    Text(_removeAdsOwned ? 'Owned' : 'Not purchased'),
                trailing: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _removeAdsOwned ? null : _purchaseRemoveAds,
                        child: const Text('Buy'),
                      ),
              ),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Restore purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
