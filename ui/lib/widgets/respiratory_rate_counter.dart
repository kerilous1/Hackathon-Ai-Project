import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';

class RespiratoryRateCounterDialog extends StatefulWidget {
  final ChildModel child;
  final Function(int bpm) onFinished;

  const RespiratoryRateCounterDialog({
    super.key,
    required this.child,
    required this.onFinished,
  });

  @override
  State<RespiratoryRateCounterDialog> createState() => _RespiratoryRateCounterDialogState();
}

class _RespiratoryRateCounterDialogState extends State<RespiratoryRateCounterDialog>
    with SingleTickerProviderStateMixin {
  int _secondsRemaining = 60;
  int _breathCount = 0;
  Timer? _timer;
  bool _isRunning = false;
  late AnimationController _chestAnimController;

  @override
  void initState() {
    super.initState();
    _chestAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chestAnimController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _secondsRemaining = 60;
      _breathCount = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isRunning = false;
        });
      }
    });
  }

  void _onChestTapped() {
    if (!_isRunning) {
      _startTimer();
    }
    setState(() {
      _breathCount++;
    });
    _chestAnimController.forward(from: 0.0);
  }

  int get _fastBreathingThreshold {
    if (widget.child.ageInDays < 60) {
      return 60;
    } else if (widget.child.ageInMonths < 12) {
      return 50;
    } else {
      return 40;
    }
  }

  bool get _isFastBreathing => _breathCount >= _fastBreathingThreshold;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مؤقت عد معدل التنفس 🫁',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'عتبة التنفس السريع لعمر ${widget.child.name} (${widget.child.ageFormattedArabic}): ≥ $_fastBreathingThreshold نفس/دقيقة',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.medicalTealDark,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Animated Chest Tap Target
            GestureDetector(
              onTap: _onChestTapped,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.15).animate(
                  CurvedAnimation(parent: _chestAnimController, curve: Curves.easeOutBack),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isFastBreathing && _secondsRemaining == 0
                        ? AppColors.redDangerGradient
                        : AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (_isFastBreathing && _secondsRemaining == 0
                                ? AppColors.emergencyRed
                                : AppColors.medicalTeal)
                            .withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 36, color: Colors.white),
                      const SizedBox(height: 4),
                      Text(
                        '$_breathCount',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'انقر مع كل شهيق',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Countdown Timer Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  'الوقت المتبقي: $_secondsRemaining ثانية',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _secondsRemaining <= 10 ? AppColors.emergencyRed : AppColors.slateNavy,
                  ),
                ),
              ],
            ),

            if (_secondsRemaining == 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isFastBreathing ? AppColors.emergencyRedBg : AppColors.safeEmeraldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFastBreathing ? AppColors.emergencyRedBorder : AppColors.safeEmeraldBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFastBreathing ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: _isFastBreathing ? AppColors.emergencyRed : AppColors.safeEmerald,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isFastBreathing
                            ? '🚨 تنفس سريع ملحوظ ($_breathCount ≥ $_fastBreathingThreshold) يشير لاحتمال التهاب رئوي.'
                            : '🟢 معدل التنفس طبيعي ($_breathCount < $_fastBreathingThreshold نفس/دقيقة).',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isFastBreathing ? AppColors.emergencyRedDark : AppColors.safeEmeraldDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _startTimer,
                    child: Text(_isRunning ? 'إعادة البدء' : 'بدء المؤقت'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _breathCount > 0
                        ? () {
                            widget.onFinished(_breathCount);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('اعتماد النتيجة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
