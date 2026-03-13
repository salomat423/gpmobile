import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

/// Standalone QR club-pass dialog + visit analytics bottom sheet.
/// Used by both HomeScreen and ProfileScreen.
class QrClubPass {
  QrClubPass._();

  static Future<void> showQrClubPass(
    BuildContext context,
    String userName,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? qrData;
    bool hasError = false;
    int validSeconds = 60;

    try {
      final result =
          await AppScope.instance.secondaryRepository.gymQr();
      qrData = (result['qr_content'] ?? result['qr_code'] ?? result['qr'] ?? result['data'] ?? '')
          .toString();
      validSeconds = (result['valid_seconds'] as num?)?.toInt() ?? 60;
    } catch (_) {
      hasError = true;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _QrDialog(
        userName: userName,
        initialQrData: qrData,
        hasError: hasError,
        validSeconds: validSeconds,
      ),
    );
  }

  static Future<void> showVisitAnalytics(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VisitAnalyticsSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// QR Dialog
// ---------------------------------------------------------------------------

class _QrDialog extends StatefulWidget {
  const _QrDialog({
    required this.userName,
    required this.initialQrData,
    required this.hasError,
    this.validSeconds = 60,
  });

  final String userName;
  final String? initialQrData;
  final bool hasError;
  final int validSeconds;

  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 60;
  String? _qrData;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _qrData = widget.initialQrData;
    _hasError = widget.hasError;
    _secondsLeft = widget.validSeconds;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4, end: 18).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _refreshQr();
      }
    });
  }

  Future<void> _refreshQr() async {
    try {
      final result =
          await AppScope.instance.secondaryRepository.gymQr();
      if (!mounted) return;
      final validSec = (result['valid_seconds'] as num?)?.toInt();
      setState(() {
        _qrData = (result['qr_content'] ?? result['qr_code'] ?? result['qr'] ?? result['data'] ?? '')
            .toString();
        _hasError = false;
        if (validSec != null && validSec > 0) _secondsLeft = validSec;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
    _startCountdown();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A3A2A), const Color(0xFF0D1F17)]
                : [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Клубный пропуск',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.userName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withOpacity(0.45),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: _glowAnimation.value / 3,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _hasError || _qrData == null || _qrData!.isEmpty
                    ? const SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(
                          child: Icon(Icons.qr_code_2,
                              size: 80, color: Colors.grey),
                        ),
                      )
                    : QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.primaryColor,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: AppTheme.primaryColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Обновится через: 0:${_secondsLeft.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Покажите QR на входе',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visit Analytics Bottom Sheet
// ---------------------------------------------------------------------------

class _VisitAnalyticsSheet extends StatefulWidget {
  const _VisitAnalyticsSheet();

  @override
  State<_VisitAnalyticsSheet> createState() => _VisitAnalyticsSheetState();
}

class _VisitAnalyticsSheetState extends State<_VisitAnalyticsSheet> {
  List<Map<String, dynamic>>? _visits;
  bool _loading = true;
  String _period = 'all';

  static const _dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  static const _periodOptions = <String, String>{
    'week': '7 дней',
    'month': '30 дней',
    'quarter': '3 мес.',
    'all': 'Все',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.instance.secondaryRepository.gymVisits();
      if (!mounted) return;
      setState(() {
        _visits = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVisits {
    if (_visits == null) return [];
    if (_period == 'all') return _visits!;
    final now = DateTime.now();
    final Duration cutoff;
    switch (_period) {
      case 'week':
        cutoff = const Duration(days: 7);
      case 'month':
        cutoff = const Duration(days: 30);
      case 'quarter':
        cutoff = const Duration(days: 90);
      default:
        return _visits!;
    }
    final threshold = now.subtract(cutoff);
    return _visits!.where((v) {
      final raw = v['date'] ?? v['created_at'] ?? v['checked_in_at'];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString());
      return dt != null && dt.isAfter(threshold);
    }).toList();
  }

  List<int> _weekdayCounts(List<Map<String, dynamic>> visits) {
    final counts = List.filled(7, 0);
    for (final v in visits) {
      final raw = v['date'] ?? v['created_at'] ?? v['checked_in_at'];
      if (raw == null) continue;
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) continue;
      counts[dt.weekday - 1]++;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(scrollController, theme, isDark),
        );
      },
    );
  }

  Widget _buildContent(
    ScrollController controller,
    ThemeData theme,
    bool isDark,
  ) {
    final filtered = _filteredVisits;
    final counts = _weekdayCounts(filtered);
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final total = filtered.length;

    final periodLabel = _period == 'all'
        ? 'за всё время'
        : 'за ${_periodOptions[_period]}';

    // Comparison with previous period
    String? comparisonText;
    if (_period != 'all' && _visits != null) {
      final now = DateTime.now();
      final int days;
      switch (_period) {
        case 'week':
          days = 7;
        case 'month':
          days = 30;
        case 'quarter':
          days = 90;
        default:
          days = 0;
      }
      if (days > 0) {
        final prevStart = now.subtract(Duration(days: days * 2));
        final prevEnd = now.subtract(Duration(days: days));
        final prevCount = _visits!.where((v) {
          final raw = v['date'] ?? v['created_at'] ?? v['checked_in_at'];
          if (raw == null) return false;
          final dt = DateTime.tryParse(raw.toString());
          return dt != null && dt.isAfter(prevStart) && dt.isBefore(prevEnd);
        }).length;
        final diff = total - prevCount;
        if (diff > 0) {
          comparisonText = '+$diff к пред. периоду';
        } else if (diff < 0) {
          comparisonText = '$diff к пред. периоду';
        } else {
          comparisonText = 'Без изменений';
        }
      }
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Аналитика посещений',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ваша активность $periodLabel',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white54 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Period filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _periodOptions.entries.map((e) {
              final isSelected = _period == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _period = e.key),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        _buildBarChart(counts, maxCount, isDark),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : AppTheme.primaryColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center,
                    color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Посещений $periodLabel',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  if (comparisonText != null)
                    Text(
                      comparisonText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: comparisonText.startsWith('+')
                            ? Colors.green
                            : comparisonText.startsWith('-')
                                ? Colors.redAccent
                                : Colors.grey,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (filtered.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'История',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              Text(
                '${filtered.length} записей',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...filtered.map((v) => _visitTile(v, isDark)),
        ],
      ],
    );
  }

  Widget _buildBarChart(List<int> counts, int maxCount, bool isDark) {
    const barMaxHeight = 120.0;
    return SizedBox(
      height: barMaxHeight + 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final ratio = maxCount == 0 ? 0.0 : counts[i] / maxCount;
          final barH = (ratio * barMaxHeight).clamp(6.0, barMaxHeight);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (counts[i] > 0)
                    Text(
                      '${counts[i]}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white70 : AppTheme.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    height: barH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.accentColor,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dayLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white54 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _visitTile(Map<String, dynamic> visit, bool isDark) {
    final raw = visit['date'] ?? visit['created_at'] ?? visit['checked_in_at'];
    String dateText = '—';
    if (raw != null) {
      final dt = DateTime.tryParse(raw.toString());
      if (dt != null) {
        dateText =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.login_rounded,
                size: 20,
                color: isDark ? AppTheme.accentColor : AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              visit['type']?.toString() ?? 'Вход',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
