import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog.dart';
import '../files.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'categories.dart';
import 'lock.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

  /// Saves via the system "save as" dialog; falls back to the share sheet off Android.
  Future<void> _saveFile(BuildContext context, String name, String content, String mime, String done) async {
    if (!DeviceFiles.supported) return _shareFile(context, name, content, mime);
    try {
      final saved = await DeviceFiles.save(name, content, mime);
      if (saved && context.mounted) toast(context, done);
    } catch (e) {
      if (context.mounted) toast(context, 'Could not save: $e');
    }
  }

  Future<void> _shareFile(BuildContext context, String name, String content, String mime) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsString(content);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime)], subject: name));
    } catch (e) {
      if (context.mounted) toast(context, 'Could not share: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final store = context.read<AppStore>();
    if (!DeviceFiles.supported) {
      toast(context, 'Restore is available on Android');
      return;
    }
    try {
      final content = await DeviceFiles.open();
      if (content == null || !context.mounted) return;
      final ok = await confirm(
        context,
        title: 'Restore backup?',
        message: 'This replaces everything currently in the app with the backup\'s data.',
        confirmLabel: 'Restore',
        destructive: true,
      );
      if (!ok) return;
      store.importJson(content);
      if (context.mounted) toast(context, 'Backup restored');
    } on FormatException {
      if (context.mounted) toast(context, 'That file isn\'t an Xpense backup');
    } catch (e) {
      if (context.mounted) toast(context, 'Restore failed: $e');
    }
  }

  Future<void> _erase(BuildContext context) async {
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    final ok = await confirm(
      context,
      title: 'Erase all data?',
      message: 'Every transaction, month log, goal and setting will be permanently deleted from this device. '
          'Export a backup first if you might want it back.',
      confirmLabel: 'Erase everything',
      destructive: true,
    );
    if (!ok) return;
    nav.popUntil((r) => r.isFirst);
    await store.eraseEverything();
  }

  Future<void> _toggleLock(BuildContext context, bool v) async {
    final store = context.read<AppStore>();
    if (v) {
      if (!await canUseDeviceLock()) {
        if (context.mounted) toast(context, 'Set up a screen lock or fingerprint on your phone first');
        return;
      }
      if (!await authenticate('Confirm to enable app lock')) return;
    }
    store.updateSettings((s) => s.lockEnabled = v);
  }

  Future<void> _editName(BuildContext context) async {
    final store = context.read<AppStore>();
    final ctrl = TextEditingController(text: store.settings.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null) store.updateSettings((s) => s.name = name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final cur = currencyFor(s.currencyCode);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          _Group('Profile', [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(s.name.isEmpty ? 'Not set' : s.name),
              onTap: () => _editName(context),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange_rounded),
              title: const Text('Currency'),
              subtitle: Text('${cur.name} (${cur.symbol.trim()})'),
              onTap: () async {
                final c = await pickCurrency(context, s.currencyCode);
                if (c != null) store.updateSettings((x) => x.currencyCode = c);
              },
            ),
          ]),
          _Group('Appearance', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => store.updateSettings((x) => x.themeMode = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Accent', style: context.tt.labelLarge),
                const SizedBox(height: 10),
                ColorRow(
                  colors: kAccents,
                  selected: s.accent,
                  onSelect: (c) => store.updateSettings((x) => x.accent = c),
                ),
              ]),
            ),
          ]),
          _Group('Privacy', [
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('App lock'),
              subtitle: const Text('Require fingerprint, face or PIN to open'),
              value: s.lockEnabled,
              onChanged: (v) => _toggleLock(context, v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide amounts'),
              subtitle: const Text('Mask numbers when others can see your screen'),
              value: s.hideAmounts,
              onChanged: (v) => store.updateSettings((x) => x.hideAmounts = v),
            ),
          ]),
          _Group('Data', [
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('Categories'),
              subtitle: Text('${store.categories.length} categories'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('Save backup'),
              subtitle: const Text('Full backup as a JSON file'),
              onTap: () => _saveFile(context, 'xpense-backup-${_stamp()}.json', store.exportJson(), 'application/json', 'Backup saved'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share backup'),
              subtitle: const Text('Send to Drive, email or another app'),
              onTap: () => _shareFile(context, 'xpense-backup-${_stamp()}.json', store.exportJson(), 'application/json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('Export CSV'),
              subtitle: const Text('Open transactions in Excel or Sheets'),
              onTap: () => _saveFile(context, 'xpense-transactions-${_stamp()}.csv', store.exportCsv(), 'text/csv', 'CSV exported'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore_rounded),
              title: const Text('Restore backup'),
              subtitle: const Text('Replace data with a backup file'),
              onTap: () => _restore(context),
            ),
          ]),
          _Group('Danger zone', [
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: context.cs.error),
              title: Text('Erase all data', style: TextStyle(color: context.cs.error)),
              onTap: () => _erase(context),
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Xpense · stored only on this device · works offline',
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
            child: Text(title.toUpperCase(),
                style: context.tt.labelSmall?.copyWith(color: context.cs.primary, letterSpacing: 1.1)),
          ),
          Card(child: Column(children: children)),
        ],
      );
}
