import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/config/app_config.dart';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _courtsFuture;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  late Future<List<Map<String, dynamic>>> _membershipsFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _courtsFuture = AppScope.instance.bookingRepository.courts();
    _bookingsFuture = AppScope.instance.bookingRepository.myBookings();
    _membershipsFuture = AppScope.instance.membershipRepository.myMemberships();
  }

  Future<void> _openCourtSheet(Map<String, dynamic> court) async {
    final courtId = (court['id'] as num?)?.toInt();
    if (courtId == null) return;

    final name = (court['name'] ?? 'Корт').toString();
    final courtType = (court['court_type'] ?? '').toString();
    final price = (court['price_per_hour'] ?? '—').toString();
    final description = (court['description'] ?? '').toString();
    final imageUrl = court['image']?.toString() ?? court['image_url']?.toString();
    final isActive = court['is_active'] == true;

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: DateTime.now().hour + 1, minute: 0);
    int duration = 60;
    int? selectedCoachId;
    String? selectedCoachName;
    String paymentMethod = 'KASPI';
    String promoCode = '';

    bool svcInventory = false;
    bool svcRecovery = false;
    bool svcSportBar = false;
    String? promoMessage;
    Color? promoColor;
    bool promoValid = false;
    String promoTitle = '';
    String promoDiscountType = '';
    double promoDiscountValue = 0;

    final promoController = TextEditingController();

    Future<List<Map<String, dynamic>>> loadCoaches() {
      final slot = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final utc = slot.toUtc();
      final iso = '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}T${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:00Z';
      return AppScope.instance.bookingRepository.availableCoaches(
        dateTimeIso: iso,
        duration: duration,
      );
    }

    Future<Map<String, dynamic>> loadAvailability() {
      return AppScope.instance.bookingRepository.checkAvailability(
        courtId: courtId,
        dateIso: _dateOnlyIso(selectedDate),
      );
    }

    Future<List<Map<String, dynamic>>> coachesFuture = loadCoaches();
    Future<Map<String, dynamic>> availFuture = loadAvailability();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          final bool isEvening = selectedTime.hour >= 18;
          final bool isWeekend =
              selectedDate.weekday == DateTime.saturday ||
              selectedDate.weekday == DateTime.sunday;

          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.zero,
                children: [
                  // --- Photo ---
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _courtPlaceholder(isDark),
                            )
                          : _courtPlaceholder(isDark),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Доступен' : 'Недоступен',
                                style: TextStyle(color: isActive ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (courtType.isNotEmpty)
                          Text(courtType, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                        const SizedBox(height: 8),

                        // Price + premium rate badges
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text('$price тг/час', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                            if (isEvening)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Вечер +', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            if (isWeekend)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Выходной +', style: TextStyle(color: Colors.deepPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text('Выберите дату и время', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _datePickerTile(
                                context: ctx,
                                icon: Icons.calendar_today_rounded,
                                label: _formatDate(selectedDate),
                                onTap: () => _showModernDatePicker(
                                  ctx,
                                  selectedDate,
                                  (d) => setSheetState(() {
                                    selectedDate = d;
                                    selectedCoachId = null;
                                    selectedCoachName = null;
                                    coachesFuture = loadCoaches();
                                    availFuture = loadAvailability();
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _datePickerTile(
                                context: ctx,
                                icon: Icons.schedule_rounded,
                                label: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                onTap: () => _showModernTimePicker(
                                  ctx,
                                  selectedTime,
                                  (t) => setSheetState(() {
                                    selectedTime = t;
                                    selectedCoachId = null;
                                    selectedCoachName = null;
                                    coachesFuture = loadCoaches();
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // --- Time slot visualization ---
                        const SizedBox(height: 16),
                        const Text('Доступные слоты', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        FutureBuilder<Map<String, dynamic>>(
                          future: availFuture,
                          builder: (ctx, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const SizedBox(height: 44, child: Center(child: LinearProgressIndicator()));
                            }
                            if (snap.hasError) {
                              return Text('Не удалось загрузить расписание', style: TextStyle(color: Colors.grey[500], fontSize: 12));
                            }
                            final data = snap.data ?? {};
                            if (data['is_holiday'] == true) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event_busy, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        (data['reason'] ?? 'Нерабочий день').toString(),
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final busySlots = (data['busy_slots'] as List?) ?? [];
                            return SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: 14,
                                separatorBuilder: (_, __) => const SizedBox(width: 6),
                                itemBuilder: (ctx, i) {
                                  final hour = 8 + i;
                                  final slotStart = hour * 60;
                                  final slotEnd = slotStart + 60;
                                  bool isBusy = false;
                                  for (final raw in busySlots) {
                                    if (raw is! Map) continue;
                                    final s = _parseSlotMinutes((raw['start'] ?? '').toString());
                                    final e = _parseSlotMinutes((raw['end'] ?? '').toString());
                                    if (s != null && e != null && slotStart < e && slotEnd > s) {
                                      isBusy = true;
                                      break;
                                    }
                                  }
                                  final isSelected = selectedTime.hour == hour && selectedTime.minute == 0;
                                  return GestureDetector(
                                    onTap: isBusy
                                        ? null
                                        : () => setSheetState(() {
                                              selectedTime = TimeOfDay(hour: hour, minute: 0);
                                              selectedCoachId = null;
                                              selectedCoachName = null;
                                              coachesFuture = loadCoaches();
                                            }),
                                    child: Container(
                                      width: 64,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : isBusy
                                                ? Colors.red.withValues(alpha: 0.15)
                                                : Colors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
                                      ),
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isSelected
                                              ? Colors.white
                                              : isBusy
                                                  ? Colors.red
                                                  : Colors.green[700],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        const Text('Длительность', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('60 мин'),
                              selected: duration == 60,
                              onSelected: (_) => setSheetState(() {
                                duration = 60;
                                selectedCoachId = null;
                                selectedCoachName = null;
                                coachesFuture = loadCoaches();
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('90 мин'),
                              selected: duration == 90,
                              onSelected: (_) => setSheetState(() {
                                duration = 90;
                                selectedCoachId = null;
                                selectedCoachName = null;
                                coachesFuture = loadCoaches();
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('120 мин'),
                              selected: duration == 120,
                              onSelected: (_) => setSheetState(() {
                                duration = 120;
                                selectedCoachId = null;
                                selectedCoachName = null;
                                coachesFuture = loadCoaches();
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Тренер', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: coachesFuture,
                          builder: (ctx, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snap.hasError) {
                              return const Text(
                                'Не удалось загрузить тренеров для этого слота',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            }
                            final coaches = snap.data ?? const [];
                            if (coaches.isEmpty) {
                              return const Text(
                                'Свободных тренеров нет (можно бронировать без тренера)',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            }
                            return DropdownButtonFormField<int>(
                              initialValue: selectedCoachId,
                              decoration: InputDecoration(
                                labelText: 'Тренер (опционально)',
                                filled: true,
                                fillColor: Colors.grey.withValues(alpha: 0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: coaches.map((c) {
                                final id = (c['id'] as num?)?.toInt();
                                if (id == null) return null;
                                final cName = (c['full_name'] ?? c['username'] ?? 'Тренер').toString();
                                final cPrice = (c['coach_price'] ?? '').toString();
                                final label = cPrice.isEmpty || cPrice == '0.00' ? cName : '$cName • $cPrice тг';
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(label),
                                );
                              }).whereType<DropdownMenuItem<int>>().toList(),
                              onChanged: (v) {
                                setSheetState(() {
                                  selectedCoachId = v;
                                  if (v != null) {
                                    final matched = coaches.firstWhere(
                                      (c) => (c['id'] as num?)?.toInt() == v,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    selectedCoachName = (matched['full_name'] ?? matched['username'] ?? 'Тренер').toString();
                                  } else {
                                    selectedCoachName = null;
                                  }
                                });
                              },
                            );
                          },
                        ),

                        // --- Additional services ---
                        const SizedBox(height: 16),
                        const Text('Дополнительные услуги', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _serviceCheckbox(
                          isDark: isDark,
                          icon: Icons.sports_tennis,
                          title: 'Аренда инвентаря',
                          value: svcInventory,
                          onChanged: (v) => setSheetState(() => svcInventory = v ?? false),
                        ),
                        const SizedBox(height: 6),
                        _serviceCheckbox(
                          isDark: isDark,
                          icon: Icons.spa_outlined,
                          title: 'Восстановительные процедуры',
                          value: svcRecovery,
                          onChanged: (v) => setSheetState(() => svcRecovery = v ?? false),
                        ),
                        const SizedBox(height: 6),
                        _serviceCheckbox(
                          isDark: isDark,
                          icon: Icons.local_bar_outlined,
                          title: 'Услуги спорт-бара',
                          value: svcSportBar,
                          onChanged: (v) => setSheetState(() => svcSportBar = v ?? false),
                        ),

                        // --- Promo code ---
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: promoController,
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (v) {
                                  promoCode = v;
                                  if (promoMessage != null) setSheetState(() { promoMessage = null; promoColor = null; });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Промокод',
                                  hintText: 'Введите код',
                                  filled: true,
                                  fillColor: Colors.grey.withValues(alpha: 0.08),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  suffixIcon: promoMessage != null
                                      ? Icon(promoColor == Colors.green ? Icons.check_circle : Icons.error_outline, color: promoColor, size: 20)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () async {
                                  final code = promoCode.trim();
                                  if (code.isEmpty) return;
                                  try {
                                    final result = await AppScope.instance.secondaryRepository.validatePromo(code);
                                    if (!ctx.mounted) return;
                                    final valid = result['valid'] == true;
                                    final title = (result['title'] ?? result['name'] ?? '').toString();
                                    final discType = (result['discount_type'] ?? '').toString();
                                    final discVal = double.tryParse((result['discount_value'] ?? '0').toString()) ?? 0;
                                    final discLabel = discType == 'PERCENT' ? '${discVal.toStringAsFixed(0)}%' : (discVal > 0 ? '${discVal.toStringAsFixed(0)} тг' : '');
                                    setSheetState(() {
                                      if (valid) {
                                        promoValid = true;
                                        promoTitle = title;
                                        promoDiscountType = discType;
                                        promoDiscountValue = discVal;
                                        promoMessage = title.isNotEmpty
                                            ? 'Промокод «$title» применён${discLabel.isNotEmpty ? ' — скидка $discLabel' : ''}'
                                            : 'Промокод применён';
                                        promoColor = Colors.green;
                                      } else {
                                        promoValid = false;
                                        promoDiscountValue = 0;
                                        promoMessage = (result['error'] ?? result['message'] ?? result['detail'] ?? 'Промокод недействителен').toString();
                                        promoColor = Colors.redAccent;
                                      }
                                    });
                                  } catch (e) {
                                    if (!ctx.mounted) return;
                                    setSheetState(() {
                                      promoValid = false;
                                      promoDiscountValue = 0;
                                      promoMessage = e.toString().replaceAll('Exception: ', '');
                                      promoColor = Colors.redAccent;
                                    });
                                  }
                                },
                                child: const Text('Применить'),
                              ),
                            ),
                          ],
                        ),
                        if (promoMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(promoMessage!, style: TextStyle(fontSize: 12, color: promoColor, fontWeight: FontWeight.w500)),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Способ оплаты',
                            filled: true,
                            fillColor: Colors.grey.withValues(alpha: 0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'KASPI', child: Text('Kaspi')),
                            DropdownMenuItem(value: 'CARD', child: Text('Карта')),
                            DropdownMenuItem(value: 'CASH', child: Text('Наличные')),
                          ],
                          onChanged: (v) { if (v != null) setSheetState(() => paymentMethod = v); },
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isActive
                                ? () => _bookCourt(
                                      ctx,
                                      courtId,
                                      name,
                                      selectedDate,
                                      selectedTime,
                                      duration,
                                      paymentMethod,
                                      courtPricePerHour: double.tryParse(price) ?? 0,
                                      coachId: selectedCoachId,
                                      coachName: selectedCoachName,
                                      promoCode: promoCode.trim(),
                                      services: [
                                        if (svcInventory) 'inventory',
                                        if (svcRecovery) 'recovery',
                                        if (svcSportBar) 'sport_bar',
                                      ],
                                      promoApplied: promoValid,
                                      promoDiscountType: promoDiscountType,
                                      promoDiscountValue: promoDiscountValue,
                                      promoLabel: promoTitle,
                                    )
                                : null,
                            child: const Text('Забронировать', style: TextStyle(fontSize: 16)),
                          ),
                        ),

                        // --- Clear form ---
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => setSheetState(() {
                              selectedDate = DateTime.now();
                              selectedTime = TimeOfDay(hour: DateTime.now().hour + 1, minute: 0);
                              duration = 60;
                              selectedCoachId = null;
                              selectedCoachName = null;
                              paymentMethod = 'KASPI';
                              promoCode = '';
                              promoController.clear();
                              svcInventory = false;
                              svcRecovery = false;
                              svcSportBar = false;
                              promoMessage = null;
                              promoColor = null;
                              promoValid = false;
                              promoTitle = '';
                              promoDiscountType = '';
                              promoDiscountValue = 0;
                              coachesFuture = loadCoaches();
                              availFuture = loadAvailability();
                            }),
                            child: const Text('Очистить', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bookCourt(
    BuildContext ctx,
    int courtId,
    String courtName,
    DateTime date,
    TimeOfDay time,
    int duration,
    String paymentMethod, {
    double courtPricePerHour = 0,
    int? coachId,
    String? coachName,
    String? promoCode,
    List<String> services = const [],
    bool promoApplied = false,
    String promoDiscountType = '',
    double promoDiscountValue = 0,
    String promoLabel = '',
  }) async {
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(ctx);
    final payload = <String, dynamic>{
      'court': courtId,
      'start_time': start.toIso8601String(),
      'duration': duration,
      'payment_method': paymentMethod,
    };
    if (coachId != null) payload['coach'] = coachId;
    final promo = (promoCode ?? '').trim();
    if (promo.isNotEmpty) payload['promo_code'] = promo;

    try {
      final availability = await AppScope.instance.bookingRepository.checkAvailability(
        courtId: courtId,
        dateIso: _dateOnlyIso(date),
      );
      if ((availability['is_holiday'] == true)) {
        throw (availability['reason'] ?? 'Корт недоступен в выбранную дату').toString();
      }
      final busySlots = (availability['busy_slots'] as List?) ?? const [];
      if (_isRequestedSlotBusy(time: time, duration: duration, busySlots: busySlots)) {
        throw 'Этот временной слот уже занят. Выберите другое время.';
      }

      final previewPayload = <String, dynamic>{
        'court_id': courtId,
        'start_time': payload['start_time'],
        'duration': duration,
      };
      if (coachId != null) previewPayload['coach_id'] = coachId;
      // services are informational only (no real IDs from hardcoded checkboxes)
      if (promo.isNotEmpty) previewPayload['promo_code'] = promo;

      final preview = await AppScope.instance.bookingRepository.pricePreview(previewPayload);
      if (!mounted) return;

      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      final serviceLabels = _serviceLabels(services);

      final courtCost = courtPricePerHour * duration / 60;

      final breakdown = (preview['breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
      final bCoach = _parseDouble(breakdown['coach'] ?? preview['coach_price']);
      final bServices = _parseDouble(breakdown['services'] ?? preview['services_price'] ?? preview['service_total']);
      final total = _parseDouble(preview['total']);
      final membershipApplied = preview['membership_applied'] == true;

      final actualCourtCost = membershipApplied ? 0.0 : courtCost;
      final subtotalBeforeDiscount = actualCourtCost + bCoach + bServices;

      double discountAmount = 0;
      if (promoApplied && promoDiscountValue > 0) {
        if (promoDiscountType == 'PERCENT') {
          discountAmount = (courtCost + bCoach + bServices) * promoDiscountValue / 100;
        } else {
          discountAmount = promoDiscountValue;
        }
      }
      if (discountAmount == 0 && subtotalBeforeDiscount > total && total >= 0) {
        discountAmount = subtotalBeforeDiscount - total;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Подтвердить бронь'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courtName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${_formatDate(date)}, $timeStr • $duration мин', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                if (coachName != null) ...[
                  const SizedBox(height: 2),
                  Text('Тренер: $coachName', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
                if (serviceLabels.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Услуги: ${serviceLabels.join(', ')}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
                if (membershipApplied) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('Абонемент: ${preview['membership_name'] ?? 'Активен'}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),
                if (membershipApplied)
                  _priceRow('Аренда корта', '0 (абонемент)')
                else
                  _priceRow('Аренда корта', courtCost.toStringAsFixed(0)),
                if (coachId != null && bCoach > 0)
                  _priceRow('Тренер', bCoach.toStringAsFixed(0)),
                if (services.isNotEmpty && bServices > 0)
                  _priceRow('Доп. услуги', bServices.toStringAsFixed(0)),
                if (promoApplied && promoDiscountValue > 0 && discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  _promoDiscountRow(
                    promoCode: promo,
                    promoTitle: promoLabel,
                    discountType: promoDiscountType,
                    discountValue: promoDiscountValue,
                    discountAmount: discountAmount,
                  ),
                ] else if (discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  _fallbackDiscountRow(preview, promo),
                ],
                const Divider(),
                const SizedBox(height: 4),
                _priceRow('ИТОГО', (total - discountAmount).toStringAsFixed(0), isBold: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Подтвердить')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final result = await AppScope.instance.bookingRepository.createBooking(payload);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Бронь создана #${result['id'] ?? ''}')),
      );
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String? _discountValue(Map<String, dynamic> preview) {
    final d = preview['discount'] ?? preview['discount_amount'];
    if (d == null) return null;
    if (d is num && d == 0) return null;
    if (d.toString() == '0' || d.toString() == '0.00') return null;
    return d.toString();
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Widget _promoDiscountRow({
    required String promoCode,
    required String promoTitle,
    required String discountType,
    required double discountValue,
    required double discountAmount,
  }) {
    final pctLabel = discountType == 'PERCENT' ? '${discountValue.toStringAsFixed(0)}%' : '';
    final amountLabel = '-${discountAmount.toStringAsFixed(0)} тг';
    final name = promoTitle.isNotEmpty ? promoTitle : promoCode;
    final label = pctLabel.isNotEmpty ? '«$name» (-$pctLabel)' : '«$name»';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_offer_rounded, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Text(amountLabel, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _fallbackDiscountRow(Map<String, dynamic> preview, String promoCode) {
    final discountAmount = _discountValue(preview) ?? '0';
    final label = promoCode.isNotEmpty ? 'Промокод «$promoCode»' : 'Скидка';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_offer_rounded, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Text('-$discountAmount тг', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  String _dateOnlyIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _isRequestedSlotBusy({
    required TimeOfDay time,
    required int duration,
    required List busySlots,
  }) {
    final selectedStart = time.hour * 60 + time.minute;
    final selectedEnd = selectedStart + duration;
    for (final raw in busySlots) {
      if (raw is! Map) continue;
      final slot = Map<String, dynamic>.from(raw);
      final start = _parseSlotMinutes((slot['start'] ?? '').toString());
      final end = _parseSlotMinutes((slot['end'] ?? '').toString());
      if (start == null || end == null) continue;
      if (selectedStart < end && selectedEnd > start) return true;
    }
    return false;
  }

  int? _parseSlotMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final id = (booking['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await AppScope.instance.bookingRepository.cancelBooking(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бронирование отменено')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _freezeOrUnfreeze(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final frozen = item['is_frozen'] == true;
    try {
      if (frozen) {
        await AppScope.instance.membershipRepository.unfreeze(id);
      } else {
        await AppScope.instance.membershipRepository.freeze(id);
      }
      if (!mounted) return;
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [
            Tab(text: 'Корты'),
            Tab(text: 'Мои брони'),
            Tab(text: 'Абонементы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildCourtsGrid(),
          _buildMyBookings(),
          _buildMemberships(),
        ],
      ),
    );
  }

  Widget _buildCourtsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _courtsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Кортов не найдено', style: TextStyle(color: Colors.grey)));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildCourtCard(items[i]),
          ),
        );
      },
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (court['name'] ?? 'Корт').toString();
    final courtType = (court['court_type'] ?? '').toString();
    final price = (court['price_per_hour'] ?? '—').toString();
    final imageUrl = court['image']?.toString() ?? court['image_url']?.toString();
    final isActive = court['is_active'] == true;

    return GestureDetector(
      onTap: () => _openCourtSheet(court),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _courtPlaceholder(isDark),
                      )
                    : _courtPlaceholder(isDark),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (courtType.isNotEmpty) Text(courtType, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$price тг', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryColor)),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBookings() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                const Text('Нет активных бронирований', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _bookingCard(items[i], isDark),
          ),
        );
      },
    );
  }

  Widget _bookingCard(Map<String, dynamic> b, bool isDark) {
    final courtName = (b['court_name'] ?? b['court'] ?? 'Корт').toString();
    final status = (b['status'] ?? '').toString().toUpperCase();
    final startRaw = (b['start_time'] ?? '').toString();
    final endRaw = (b['end_time'] ?? '').toString();
    final price = (b['price'] ?? '').toString();
    final coachName = (b['coach_name'] ?? '').toString();
    final isPaid = b['is_paid'] == true;

    String dateLabel = '';
    String timeLabel = '';
    final dt = DateTime.tryParse(startRaw);
    if (dt != null) {
      final local = dt.toLocal();
      dateLabel = '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
      timeLabel = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      final dtEnd = DateTime.tryParse(endRaw)?.toLocal();
      if (dtEnd != null) {
        timeLabel += ' – ${dtEnd.hour.toString().padLeft(2, '0')}:${dtEnd.minute.toString().padLeft(2, '0')}';
      }
    } else {
      dateLabel = startRaw;
    }

    final statusColor = _bookingStatusColor(status);
    final statusLabel = _bookingStatusLabel(status);

    return GestureDetector(
      onTap: () => _showBookingDetail(b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.sports_tennis, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(courtName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      if (coachName.isNotEmpty)
                        Text('Тренер: $coachName', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 15, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(dateLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(timeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (price.isNotEmpty && price != '0' && price != '0.00') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$price тг', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Оплачено', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Не оплачено', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBookingDetail(Map<String, dynamic> b) async {
    final bookingId = (b['id'] as num?)?.toInt();

    Map<String, dynamic> detail = b;
    if (bookingId != null) {
      try {
        detail = await AppScope.instance.bookingRepository.bookingDetail(bookingId);
      } catch (_) {}
    }

    if (!mounted) return;

    final courtName = (detail['court_name'] ?? detail['court'] ?? 'Корт').toString();
    final status = (detail['status'] ?? '').toString().toUpperCase();
    final startRaw = (detail['start_time'] ?? '').toString();
    final endRaw = (detail['end_time'] ?? '').toString();
    final price = (detail['price'] ?? '').toString();
    final coachName = (detail['coach_name'] ?? '').toString();
    final isPaid = detail['is_paid'] == true;
    final durationHours = detail['duration_hours'];
    final participants = (detail['participants_names'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final servicesList = (detail['services'] as List?) ?? [];
    final createdAt = (detail['created_at'] ?? '').toString();

    String dateLabel = '';
    String timeLabel = '';
    final dt = DateTime.tryParse(startRaw);
    if (dt != null) {
      final local = dt.toLocal();
      dateLabel = '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
      timeLabel = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      final dtEnd = DateTime.tryParse(endRaw)?.toLocal();
      if (dtEnd != null) {
        timeLabel += ' – ${dtEnd.hour.toString().padLeft(2, '0')}:${dtEnd.minute.toString().padLeft(2, '0')}';
      }
    }

    final statusColor = _bookingStatusColor(status);
    final statusLabel = _bookingStatusLabel(status);
    final canCancel = status != 'CANCELED' && status != 'COMPLETED';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(courtName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (bookingId != null) ...[
                const SizedBox(height: 4),
                Text('Бронь #$bookingId', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
              const SizedBox(height: 20),

              _detailRow(Icons.calendar_today_rounded, 'Дата', dateLabel),
              _detailRow(Icons.schedule_rounded, 'Время', timeLabel),
              if (durationHours != null)
                _detailRow(Icons.timelapse_rounded, 'Длительность', '$durationHours ч'),
              if (coachName.isNotEmpty)
                _detailRow(Icons.person_outline_rounded, 'Тренер', coachName),
              if (participants.isNotEmpty)
                _detailRow(Icons.group_outlined, 'Участники', participants.join(', ')),

              if (servicesList.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Услуги', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                ...servicesList.map((s) {
                  final sMap = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
                  final sName = (sMap['service_name'] ?? '').toString();
                  final sQty = (sMap['quantity'] ?? 1).toString();
                  final sPrice = (sMap['price_at_moment'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text('$sName × $sQty', style: const TextStyle(fontSize: 13))),
                        if (sPrice.isNotEmpty) Text('$sPrice тг', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Стоимость', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          price.isNotEmpty && price != '0' ? '$price тг' : 'Бесплатно',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isPaid ? 'Оплачено' : 'Не оплачено',
                        style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Создано: ${_formatIso(createdAt)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],

              if (canCancel) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancelBooking(ctx, b),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                    label: const Text('Отменить бронирование', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _formatIso(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _confirmCancelBooking(BuildContext sheetCtx, Map<String, dynamic> booking) async {
    final nav = Navigator.of(sheetCtx);
    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отменить бронирование?'),
        content: const Text('Вы уверены, что хотите отменить эту бронь? Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Нет')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    nav.pop();
    await _cancelBooking(booking);
  }

  Color _bookingStatusColor(String status) {
    switch (status) {
      case 'CONFIRMED': return Colors.green;
      case 'PENDING': return Colors.orange;
      case 'CANCELED': return Colors.red;
      case 'COMPLETED': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  String _bookingStatusLabel(String status) {
    switch (status) {
      case 'CONFIRMED': return 'Подтверждена';
      case 'PENDING': return 'Ожидание';
      case 'CANCELED': return 'Отменена';
      case 'COMPLETED': return 'Завершена';
      default: return status;
    }
  }

  Widget _buildMemberships() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membershipsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: ElevatedButton(
              onPressed: () async {
                final types = await AppScope.instance.membershipRepository.types();
                if (types.isEmpty || !mounted) return;
                final firstType = (types.first['id'] as num?)?.toInt();
                if (firstType == null) return;
                await AppScope.instance.membershipRepository.buy(firstType);
                if (!mounted) return;
                setState(_reloadAll);
              },
              child: const Text('Купить первый доступный абонемент'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final frozen = m['is_frozen'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((m['membership_type_name'] ?? m['type_name'] ?? 'Абонемент').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('До: ${m['end_date'] ?? '-'}  •  Часы: ${m['hours_remaining'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _freezeOrUnfreeze(m),
                      child: Text(frozen ? 'Разморозить' : 'Заморозить'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorWidget(Object? e, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ошибка загрузки'),
          const SizedBox(height: 8),
          Text(e.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: retry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

Widget _courtPlaceholder(bool isDark) {
  return Container(
    color: isDark ? Colors.grey[800] : Colors.grey[200],
    child: Center(
      child: Icon(Icons.sports_tennis, size: 40, color: isDark ? Colors.white38 : Colors.grey[400]),
    ),
  );
}

Widget _datePickerTile({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.withValues(alpha: 0.6)),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime d) {
  const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

void _showModernDatePicker(BuildContext ctx, DateTime current, ValueChanged<DateTime> onPicked) {
  DateTime temp = current;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите дату', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () { onPicked(temp); Navigator.pop(sheetCtx); },
                  child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: current,
              minimumDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
              maximumDate: DateTime.now().add(const Duration(days: 60)),
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showModernTimePicker(BuildContext ctx, TimeOfDay current, ValueChanged<TimeOfDay> onPicked) {
  DateTime temp = DateTime(2025, 1, 1, current.hour, current.minute);
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите время', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () { onPicked(TimeOfDay(hour: temp.hour, minute: temp.minute)); Navigator.pop(sheetCtx); },
                  child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: temp,
              use24hFormat: true,
              minuteInterval: 15,
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _serviceCheckbox({
  required bool isDark,
  required IconData icon,
  required String title,
  required bool value,
  required ValueChanged<bool?> onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
    ),
    child: CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      dense: true,
    ),
  );
}

List<String> _serviceLabels(List<String> services) {
  return services.map((s) {
    switch (s) {
      case 'inventory': return 'Аренда инвентаря';
      case 'recovery': return 'Восстановительные процедуры';
      case 'sport_bar': return 'Услуги спорт-бара';
      default: return s;
    }
  }).toList();
}

Widget _priceRow(String label, dynamic amount, {bool isDiscount = false, bool isBold = false}) {
  final text = amount?.toString() ?? '—';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          '$text тг',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
            color: isDiscount ? Colors.green : null,
          ),
        ),
      ],
    ),
  );
}

