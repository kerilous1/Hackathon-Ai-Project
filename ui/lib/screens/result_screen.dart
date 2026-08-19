/// PEDI-GUIDE AI — Result Screen
/// ==============================
/// Detailed clinical assessment result view with triage card,
/// recommendation, evidence chunks, differential questions, and citations.

import 'package:flutter/material.dart';
import '../models/clinical_model.dart';

class ResultScreen extends StatelessWidget {
  final String query;
  final ClinicalResult result;

  const ResultScreen({
    super.key,
    required this.query,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: const Color(0xFFE2E8F0),
        elevation: 0,
        title: const Text(
          'Clinical Assessment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Query display ──
            _buildQueryCard(),
            const SizedBox(height: 16),

            // ── Triage Card ──
            _buildTriageCard(),
            const SizedBox(height: 12),

            // ── Confidence Gauge ──
            _buildConfidenceRow(),
            const SizedBox(height: 16),

            // ── Recommendation ──
            _buildSectionHeader('📋 Clinical Recommendation'),
            const SizedBox(height: 8),
            _buildRecommendationCard(),
            const SizedBox(height: 20),

            // ── Differential Verification ──
            if (result.differentialQuestions.isNotEmpty) ...[
              _buildSectionHeader('🔎 Differential Verification'),
              const SizedBox(height: 8),
              _buildDifferentialCard(),
              const SizedBox(height: 20),
            ],

            // ── Evidence Chunks ──
            if (result.chunks.isNotEmpty) ...[
              _buildSectionHeader(
                  '📖 Retrieved Evidence (${result.chunks.length} chunks)'),
              const SizedBox(height: 8),
              ...result.chunks.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildEvidenceCard(entry.key + 1, entry.value),
                    ),
                  ),
              const SizedBox(height: 12),
            ],

            // ── Citations Table ──
            if (result.citedPages.isNotEmpty) ...[
              _buildSectionHeader('🏷️ Citations'),
              const SizedBox(height: 8),
              _buildCitationsCard(),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // QUERY CARD
  // ═══════════════════════════════════════════
  Widget _buildQueryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLINICAL QUERY',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (result.searchQuery.isNotEmpty &&
              result.searchQuery != query) ...[
            const SizedBox(height: 8),
            Text(
              '🔄 Search: ${result.searchQuery}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TRIAGE CARD
  // ═══════════════════════════════════════════
  Widget _buildTriageCard() {
    final config = _getTriageConfig(result.triageLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            config.color.withValues(alpha: 0.18),
            config.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: config.color, width: 5),
          top: BorderSide(color: config.color.withValues(alpha: 0.1)),
          right: BorderSide(color: config.color.withValues(alpha: 0.1)),
          bottom: BorderSide(color: config.color.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${config.emoji} ${config.label}',
            style: TextStyle(
              color: config.color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            config.description,
            style: TextStyle(
              color: config.color.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CONFIDENCE ROW
  // ═══════════════════════════════════════════
  Widget _buildConfidenceRow() {
    final confConfig = _getConfidenceConfig(result.confidence);

    return Row(
      children: [
        const Text(
          'Confidence: ',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: confConfig.gradientColors),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${confConfig.emoji} ${result.confidence} — ${result.topScore.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // RECOMMENDATION CARD
  // ═══════════════════════════════════════════
  Widget _buildRecommendationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.5),
        ),
      ),
      child: SelectableText(
        result.responseText,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DIFFERENTIAL VERIFICATION
  // ═══════════════════════════════════════════
  Widget _buildDifferentialCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify these clinical signs per IMCI protocol:',
            style: TextStyle(
              color: Color(0xFF93C5FD),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...result.differentialQuestions.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      q,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // EVIDENCE CHUNK CARD
  // ═══════════════════════════════════════════
  Widget _buildEvidenceCard(int index, EvidenceChunk chunk) {
    final scoreColor = chunk.score >= 70
        ? const Color(0xFF4ADE80)
        : chunk.score >= 55
            ? const Color(0xFFFBBF24)
            : const Color(0xFFF87171);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Chunk $index',
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              // Score badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chunk.scorePercent,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Used badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chunk.used
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chunk.used ? '✅ Used' : '⬜ Not used',
                  style: TextStyle(
                    color: chunk.used
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Source info
          Text(
            '📑 ${chunk.section.length > 50 ? '${chunk.section.substring(0, 47)}...' : chunk.section}  |  📄 p. ${chunk.pageDisplay}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          // Text content (truncated with expand)
          Text(
            chunk.text.length > 300
                ? '${chunk.text.substring(0, 300)}...'
                : chunk.text,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CITATIONS CARD
  // ═══════════════════════════════════════════
  Widget _buildCitationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Section',
                    style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 1,
                child: Text('Page',
                    style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 1,
                child: Text('Cited',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 16),
          // Rows
          ...result.chunks.asMap().entries.map((entry) {
            final chunk = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      chunk.section.length > 35
                          ? '${chunk.section.substring(0, 32)}...'
                          : chunk.section,
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'p. ${chunk.pageDisplay}',
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      chunk.used ? '✅' : '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFCBD5E1),
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CONFIG HELPERS
  // ═══════════════════════════════════════════
  _TriageConfig _getTriageConfig(String level) {
    switch (level) {
      case 'RED':
        return _TriageConfig(
          color: const Color(0xFFEF4444),
          emoji: '🔴',
          label: 'URGENT REFERRAL',
          description:
              'Pre-referral treatment & immediate hospital referral required',
        );
      case 'YELLOW':
        return _TriageConfig(
          color: const Color(0xFFF59E0B),
          emoji: '🟡',
          label: 'CLINIC TREATMENT',
          description: 'Specific medical treatment at clinic with follow-up',
        );
      case 'GREEN':
        return _TriageConfig(
          color: const Color(0xFF22C55E),
          emoji: '🟢',
          label: 'HOME MANAGEMENT',
          description: 'Supportive home care, feeding, and fluids',
        );
      default:
        return _TriageConfig(
          color: const Color(0xFF64748B),
          emoji: '🛡️',
          label: 'OUT OF SCOPE / REFUSAL',
          description: 'Query outside IMCI guidelines scope',
        );
    }
  }

  _ConfidenceConfig _getConfidenceConfig(String confidence) {
    switch (confidence) {
      case 'HIGH':
        return _ConfidenceConfig(
          emoji: '🟢',
          gradientColors: [const Color(0xFF22C55E), const Color(0xFF16A34A)],
        );
      case 'MEDIUM':
        return _ConfidenceConfig(
          emoji: '🟡',
          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        );
      default:
        return _ConfidenceConfig(
          emoji: '🔴',
          gradientColors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
        );
    }
  }
}

class _TriageConfig {
  final Color color;
  final String emoji;
  final String label;
  final String description;

  _TriageConfig({
    required this.color,
    required this.emoji,
    required this.label,
    required this.description,
  });
}

class _ConfidenceConfig {
  final String emoji;
  final List<Color> gradientColors;

  _ConfidenceConfig({
    required this.emoji,
    required this.gradientColors,
  });
}
