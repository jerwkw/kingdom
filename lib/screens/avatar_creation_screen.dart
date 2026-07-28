import 'package:flutter/material.dart';
import '../config/avatar_parts_config.dart';
import '../widgets/avatar_renderer.dart';

/// Reusable avatar creation / editing panel.
///
/// Shows a live preview at the top and scrollable customisation sections below.
/// Used during onboarding and can be re-opened later from the Avatar tab.
class AvatarCreationPanel extends StatefulWidget {
  final String roleId;
  final Map<String, String>? initialConfig;
  final ValueChanged<Map<String, String>> onConfigChanged;

  const AvatarCreationPanel({
    super.key,
    required this.roleId,
    this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<AvatarCreationPanel> createState() => _AvatarCreationPanelState();
}

class _AvatarCreationPanelState extends State<AvatarCreationPanel> {
  late Map<String, String> _config;

  @override
  void initState() {
    super.initState();
    _config = Map<String, String>.from(
      widget.initialConfig ?? AvatarPartsConfig.defaultConfig,
    );
  }

  void _update(String key, String value) {
    final updated = Map<String, String>.from(_config);
    updated[key] = value;

    // Auto-fix body type if gender changes and current selection is restricted
    if (key == 'gender') {
      final available = AvatarPartsConfig.bodyTypesForGender(value);
      if (!available.any((o) => o.id == updated['bodyType'])) {
        updated['bodyType'] = 'standard';
      }
      // Same for hairstyles
      final availableHair = AvatarPartsConfig.hairStylesForGender(value);
      if (!availableHair.any((o) => o.id == updated['hairStyle'])) {
        updated['hairStyle'] = 'short_classic';
      }
    }

    setState(() {
      _config = updated;
    });

    widget.onConfigChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final currentGender = _config['gender'] ?? 'neutral';

    return Column(
      children: [
        // ── Live Preview ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Center(
            child: AvatarRenderer(
              roleId: widget.roleId,
              avatarConfig: _config,
              size: 150,
            ),
          ),
        ),

        // ── Customisation Sections ────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _SectionTitle(label: 'Gender'),
              _ChipSelector(
                options: AvatarPartsConfig.genders,
                selectedId: _config['gender'] ?? 'neutral',
                onSelected: (id) => _update('gender', id),
              ),

              _SectionTitle(label: 'Body Type'),
              _ChipSelector(
                options: AvatarPartsConfig.bodyTypesForGender(currentGender),
                selectedId: _config['bodyType'] ?? 'standard',
                onSelected: (id) => _update('bodyType', id),
              ),

              _SectionTitle(label: 'Skin Tone'),
              _ColorCircleSelector(
                options: AvatarPartsConfig.skinTones,
                selectedId: _config['skinTone'] ?? 'medium',
                onSelected: (id) => _update('skinTone', id),
              ),

              _SectionTitle(label: 'Face Shape'),
              _ChipSelector(
                options: AvatarPartsConfig.faceShapes,
                selectedId: _config['faceShape'] ?? 'round',
                onSelected: (id) => _update('faceShape', id),
              ),

              _SectionTitle(label: 'Eyes'),
              _ChipSelector(
                options: AvatarPartsConfig.eyeStyles,
                selectedId: _config['eyeStyle'] ?? 'friendly',
                onSelected: (id) => _update('eyeStyle', id),
              ),

              _SectionTitle(label: 'Nose'),
              _ChipSelector(
                options: AvatarPartsConfig.noseStyles,
                selectedId: _config['noseStyle'] ?? 'small',
                onSelected: (id) => _update('noseStyle', id),
              ),

              _SectionTitle(label: 'Mouth'),
              _ChipSelector(
                options: AvatarPartsConfig.mouthStyles,
                selectedId: _config['mouthStyle'] ?? 'smile',
                onSelected: (id) => _update('mouthStyle', id),
              ),

              _SectionTitle(label: 'Hair Style'),
              _ChipSelector(
                options: AvatarPartsConfig.hairStylesForGender(currentGender),
                selectedId: _config['hairStyle'] ?? 'short_classic',
                onSelected: (id) => _update('hairStyle', id),
              ),

              _SectionTitle(label: 'Hair Color'),
              _ColorCircleSelector(
                options: AvatarPartsConfig.hairColors,
                selectedId: _config['hairColor'] ?? 'black',
                onSelected: (id) => _update('hairColor', id),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared UI Components ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}

/// Horizontal list of labelled choice chips for text-based options.
class _ChipSelector extends StatelessWidget {
  final List<AvatarOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _ChipSelector({
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((opt) {
        final isSelected = opt.id == selectedId;
        return ChoiceChip(
          label: Text(opt.label),
          selected: isSelected,
          selectedColor: Colors.indigo.shade100,
          onSelected: (_) => onSelected(opt.id),
        );
      }).toList(),
    );
  }
}

/// Horizontal list of coloured circles for skin tone / hair colour.
class _ColorCircleSelector extends StatelessWidget {
  final List<AvatarOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _ColorCircleSelector({
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt.id == selectedId;
        return GestureDetector(
          onTap: () => onSelected(opt.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: opt.color ?? Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.indigo : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 6)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
