/// PEDI-GUIDE AI — Home Screen
/// ============================
/// Main clinical assessment screen with input, demo buttons,
/// triage results, evidence, and session history.

import 'package:flutter/material.dart';
import '../models/clinical_model.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final List<SessionEntry> _history = [];
  bool _isLoading = false;
  late AnimationController _pulseController;

  // Quick demo cases
  static const Map<String, String> demoCases = {
    '🚨 Danger Signs':
        'child not able to drink or breastfeed, vomiting everything, convulsions, lethargic or unconscious',
    '🫁 Pneumonia':
        '6 month old child with cough for 5 days, fast breathing 58 breaths per minute, chest indrawing, stridor when calm',
    '🌐 Arabic':
        'رضيع عمره 3 شهور عنده صعوبة في الرضاعة مع سرعة تنفس وحرارة منخفضة وصفار في الجلد',
    '🛡️ Refusal':
        'What is the recommended nitroglycerin dosage for adult coronary artery disease?',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _analyzeCase(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final result = await ApiService.analyzeCase(query: query.trim());

    setState(() {
      _isLoading = false;
      _history.insert(0, SessionEntry(query: query.trim(), result: result));
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(query: query.trim(), result: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Header ──
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Quick Demo Buttons ──
            SliverToBoxAdapter(child: _buildDemoButtons()),

            // ── Input Area ──
            SliverToBoxAdapter(child: _buildInputArea()),

            // ── Loading Indicator ──
            if (_isLoading) SliverToBoxAdapter(child: _buildLoadingCard()),

            // ── Session History ──
            if (_history.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'SESSION HISTORY',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildHistoryTile(_history[index], index),
                  childCount: _history.length,
                ),
              ),
            ],

            // ── Bottom spacer ──
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          // Logo & Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5), Color(0xFF6DD5FA)],
            ).createShader(bounds),
            child: const Text(
              '🩺 PEDI-GUIDE AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'WHO IMCI Clinical Decision Support',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          // Server status indicator
          FutureBuilder<bool>(
            future: ApiService.healthCheck(),
            builder: (context, snapshot) {
              final connected = snapshot.data ?? false;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: connected
                        ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connected ? Icons.cloud_done : Icons.cloud_off,
                      size: 14,
                      color: connected
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFF87171),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connected ? 'Server Connected' : 'Server Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: connected
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DEMO BUTTONS
  // ═══════════════════════════════════════════
  Widget _buildDemoButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '⚡ QUICK DEMO CASES',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: demoCases.entries.map((entry) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isLoading
                      ? null
                      : () {
                          _queryController.text = entry.value;
                          _analyzeCase(entry.value);
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF1E293B).withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF334155),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // INPUT AREA
  // ═══════════════════════════════════════════
  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF334155),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Text input
            TextField(
              controller: _queryController,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 15,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    'Describe the clinical case...\nمثال: طفل عمره ٦ أشهر مع حمى شديدة وتقيؤ',
                hintStyle: TextStyle(
                  color: const Color(0xFF64748B).withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            // Divider
            Container(
              height: 1,
              color: const Color(0xFF334155).withValues(alpha: 0.5),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _analyzeCase(_queryController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor:
                        const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Analyze Case',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // LOADING CARD
  // ═══════════════════════════════════════════
  Widget _buildLoadingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.5 + (_pulseController.value * 0.5),
                  child: const Text(
                    'Analyzing clinical scenario...',
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'Retrieving evidence & generating assessment',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HISTORY TILE
  // ═══════════════════════════════════════════
  Widget _buildHistoryTile(SessionEntry entry, int index) {
    final triage = entry.result.triageLevel;
    final color = _triageColor(triage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ResultScreen(query: entry.query, result: entry.result),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Triage dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Query preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.query.length > 60
                            ? '${entry.query.substring(0, 60)}...'
                            : entry.query,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_triageLabel(triage)} • ${entry.result.confidence} confidence',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _triageColor(String level) {
    switch (level) {
      case 'RED':
        return const Color(0xFFEF4444);
      case 'YELLOW':
        return const Color(0xFFF59E0B);
      case 'GREEN':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _triageLabel(String level) {
    switch (level) {
      case 'RED':
        return '🔴 Urgent Referral';
      case 'YELLOW':
        return '🟡 Clinic Treatment';
      case 'GREEN':
        return '🟢 Home Care';
      default:
        return '🛡️ Refusal';
    }
  }
}
