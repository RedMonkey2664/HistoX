import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/admin_mode.dart';
import '../../app/theme.dart';
import '../../app/widgets/hud.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/purchases_service.dart';
import '../../core/services/revenuecat_service.dart';
import '../../core/services/run_history_service.dart';
import '../../data/sample/dev_sample_level.dart';
import '../onboarding/onboarding_screen.dart';
import '../simulator/campaign/level_repository.dart';
import '../simulator/engine/level_model.dart';
import '../simulator/engine/simulation_mode.dart';
import '../simulator/level/level_screen.dart';

/// Everything, reachable, for testing and demos.
///
/// Reached from the ⚙ sheet on the campaign screen, and only in a build where
/// [AdminMode.enabled] — debug and profile always, release only when somebody
/// passed `--dart-define=HISTOX_ADMIN=true`. The store build has no way in.
///
/// Every action here goes through the same providers the app uses. Nothing
/// writes a fake score or a fake price: unlocking Pro grants the session
/// unlock, clearing progress clears the real store, and the level launcher
/// starts a real run.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  /// Null until the store has been asked. Asking is the diagnostic: it runs
  /// the same call the paywall runs, so what shows here is what the paywall
  /// will get.
  PriceLoad? _load;
  bool _asking = false;

  Future<void> _askTheStore() async {
    setState(() => _asking = true);
    final PriceLoad load = await ref.read(purchasesServiceProvider).prices();
    if (mounted) {
      setState(() {
        _load = load;
        _asking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProAccess pro = ref.watch(proAccessProvider);
    final PurchasesService store = ref.watch(purchasesServiceProvider);
    final ProgressState progress = ref.watch(progressProvider);
    final List<RunRecord> history = ref.watch(runHistoryProvider);
    final AsyncValue<List<LevelManifestEntry>> manifest = ref.watch(
      levelManifestProvider,
    );

    void toast(String message) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    return Scaffold(
      appBar: const HudTopBar(
        title: 'ADMIN',
        titleColor: AppColors.textPrimary,
        leading: HudBackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 4,
          AppSpacing.md,
          AppSpacing.md + 4,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          if (AdminMode.isForcedIntoRelease)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: (kIsWeb ? AppColors.caution : AppColors.down)
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color: kIsWeb ? AppColors.caution : AppColors.down,
                ),
              ),
              child: Text(
                kIsWeb
                    // The web build is the public demo. Nothing is sold
                    // on it, so these tools cost nothing here - but
                    // anyone with the link can use them, and that should
                    // not be a surprise.
                    ? 'PUBLIC DEMO BUILD. These tools are open to anyone '
                          'with the link. Nothing is sold on the web build.'
                    : 'RELEASE BUILD WITH ADMIN FORCED ON.\nDo not upload '
                          'this build to a store: it can unlock Pro '
                          'without paying.',
                style: AppText.body(
                  size: 13,
                  color: kIsWeb ? AppColors.caution : AppColors.down,
                ),
              ),
            ),

          _Section('REVENUECAT'),
          _Row(
            'SDK configured',
            store.isConfigured ? 'yes' : 'no',
          ),
          _Row(
            'Key in this build',
            RevenueCatKeys.current() == null
                ? 'none'
                : RevenueCatKeys.describeCurrent(),
          ),
          _Row('Pro entitlement', pro.purchased ? 'active' : 'inactive'),
          if (_load case final PriceLoad load) ...<Widget>[
            _Row('Offering', switch (load.status) {
              PriceStatus.ok => 'found',
              PriceStatus.noOffering => 'none set as current',
              PriceStatus.noProducts => 'found, but no packages',
              PriceStatus.notConfigured => 'not asked: no key',
              PriceStatus.networkError => 'unreachable',
              PriceStatus.storeError => 'store refused',
            }),
            _Row('Packages priced', '${load.plans.length}'),
            for (final PlanPrice plan in load.plans)
              _Row(
                '  ${plan.plan.name}',
                plan.perMonthLabel == null
                    ? plan.priceLabel
                    : '${plan.priceLabel} (${plan.perMonthLabel}/mo)',
              ),
            if (load.message case final String m) _Row('  reported as', m),
          ],
          const SizedBox(height: AppSpacing.sm),
          _Action(
            label: _asking ? 'ASKING THE STORE...' : 'ASK THE STORE FOR PRICES',
            onTap: _asking ? () {} : () => _askTheStore(),
          ),

          const SizedBox(height: AppSpacing.lg),
          _Section('STATE'),
          _Row('Pro access', pro.hasPro ? 'unlocked' : 'locked'),
          _Row('  from a purchase', pro.purchased ? 'yes' : 'no'),
          _Row('  from a session unlock', pro.previewUnlocked ? 'yes' : 'no'),
          _Row('Store', store.isConfigured ? 'connected' : 'not connected'),
          _Row(
            'RevenueCat key',
            RevenueCatKeys.current() == null ? 'absent' : 'present',
          ),
          _Row('Levels cleared', '${progress.clearedCount}'),
          _Row('Pivot points', '${progress.pivotBonusPoints}'),
          _Row('Runs recorded', '${history.length}'),

          const SizedBox(height: AppSpacing.lg),
          _Section('PRO'),
          _Action(
            label: 'UNLOCK PRO FOR THIS SESSION',
            onTap: () {
              ref.read(proAccessProvider.notifier).unlockForAdmin();
              toast('Pro unlocked for this session.');
            },
          ),
          _Action(
            label: 'RE-LOCK PRO',
            onTap: () {
              ref.read(proAccessProvider.notifier).relockForAdmin();
              toast('Pro re-locked.');
            },
          ),

          const SizedBox(height: AppSpacing.lg),
          _Section('DATA'),
          _Action(
            label: 'UNLOCK EVERYTHING (100% PROGRESS)',
            onTap: () async {
              final List<LevelManifestEntry> all = manifest.maybeWhen(
                data: (List<LevelManifestEntry> l) => l,
                orElse: () => const <LevelManifestEntry>[],
              );
              final List<String> playable = <String>[
                for (final LevelManifestEntry e in all)
                  if (e.dataStatus.isPlayable) e.id,
              ];
              if (playable.isEmpty) {
                toast('The level manifest is not loaded yet.');
                return;
              }
              ref.read(proAccessProvider.notifier).unlockForAdmin();
              await ref
                  .read(progressProvider.notifier)
                  .completeAllForAdmin(playable);
              toast(
                'Pro unlocked and ${playable.length} levels marked cleared. '
                'This progress is synthetic.',
              );
            },
          ),
          _Action(
            label: 'CLEAR CAMPAIGN PROGRESS',
            destructive: true,
            onTap: () async {
              await ref.read(progressProvider.notifier).resetForAdmin();
              toast('Progress cleared.');
            },
          ),
          _Action(
            label: 'CLEAR RUN HISTORY',
            destructive: true,
            onTap: () async {
              await ref.read(runHistoryProvider.notifier).resetForAdmin();
              toast('Run history cleared.');
            },
          ),
          _Action(
            label: 'REPLAY ONBOARDING',
            onTap: () async {
              await ref.read(onboardingSeenProvider.notifier).replayForAdmin();
              toast('Onboarding will show on next launch.');
            },
          ),

          const SizedBox(height: AppSpacing.lg),
          _Section('RUNS'),
          _Action(
            label: 'ENGINE TEST RUN (SYNTHETIC DATA)',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => LevelScreen(
                  level: DevSampleLevel.build(),
                  mode: SimulationMode.beginner,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'EVERY LEVEL',
            style: AppText.label(size: 11, letterSpacing: 11 * 0.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Opens any level directly, Pro or not, ignoring the paywall. '
            'Levels with no sourced data are absent because there is nothing '
            'to play.',
            style: AppText.body(size: 12.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          ...manifest.when(
            loading: () => <Widget>[
              const Center(child: CircularProgressIndicator()),
            ],
            error: (Object e, StackTrace _) => <Widget>[
              Text('Manifest unreadable: $e', style: AppText.body(size: 12)),
            ],
            data: (List<LevelManifestEntry> all) => <Widget>[
              for (final LevelManifestEntry e in all)
                if (e.dataStatus.isPlayable)
                  _LevelRow(entry: e, progress: progress),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends ConsumerWidget {
  const _LevelRow({required this.entry, required this.progress});

  final LevelManifestEntry entry;
  final ProgressState progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? best = progress.forLevel(entry.id)?.bestScore;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () async {
          final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
            context,
          );
          final NavigatorState navigator = Navigator.of(
            context,
            rootNavigator: true,
          );
          try {
            final SimulationLevel level = await ref
                .read(levelRepositoryProvider)
                .loadLevel(entry);
            await navigator.push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    LevelScreen(level: level, mode: SimulationMode.beginner),
              ),
            );
          } on Object catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not load ${entry.id}: $error')),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.id,
                  style: AppText.mono(size: 12.5, color: AppColors.textPrimary),
                ),
              ),
              if (!entry.isFree)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    'PRO',
                    style: AppText.label(size: 10, color: AppColors.caution),
                  ),
                ),
              Text(
                best == null ? '—' : '$best',
                style: AppText.mono(size: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
    child: Text(
      title,
      style: AppText.label(size: 11, letterSpacing: 11 * 0.2),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppText.body(size: 13, color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppText.mono(size: 13, color: AppColors.textPrimary),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
    child: HudButton(
      label: label,
      style: HudButtonStyle.ghost,
      color: destructive ? AppColors.down : AppColors.accent,
      height: 48,
      fontSize: 13,
      onPressed: onTap,
    ),
  );
}
