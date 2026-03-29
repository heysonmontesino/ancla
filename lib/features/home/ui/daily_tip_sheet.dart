import 'package:flutter/material.dart';

import 'tip_card_painter.dart';
import 'tip_share_service.dart';

class DailyTipSheet extends StatefulWidget {
  const DailyTipSheet({super.key, required this.tipText});

  final String tipText;

  @override
  State<DailyTipSheet> createState() => _DailyTipSheetState();
}

class _DailyTipSheetState extends State<DailyTipSheet> {
  final GlobalKey _cardKey = GlobalKey();
  TipCardStyle _style = TipCardStyle.forest;
  bool _isSharing = false;

  double get _tipFontSize => widget.tipText.length > 80 ? 17 : 22;

  Future<void> _shareCard() async {
    setState(() => _isSharing = true);
    try {
      await TipShareService.captureAndShare(_cardKey, widget.tipText);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir este consejo ahora mismo.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: CustomPaint(
                    key: ValueKey<TipCardStyle>(_style),
                    painter: TipCardPainter(style: _style),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.anchor_rounded,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.tipText,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _tipFontSize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.anchor_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ancla',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: TipCardStyle.values
              .map(
                (style) => Padding(
                  padding: EdgeInsets.only(
                    right: style == TipCardStyle.values.last ? 0 : 12,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _style = style),
                    child: _StylePreviewCircle(
                      style: style,
                      isSelected: _style == style,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSharing ? null : _shareCard,
            icon: const Icon(Icons.share_rounded),
            label: Text(
              _isSharing ? 'Preparando imagen...' : 'Compartir esta frase',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2D4A2D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StylePreviewCircle extends StatelessWidget {
  const _StylePreviewCircle({required this.style, required this.isSelected});

  final TipCardStyle style;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _gradientFor(style),
        ),
      ),
    );
  }

  Gradient _gradientFor(TipCardStyle style) {
    switch (style) {
      case TipCardStyle.forest:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2E1A), Color(0xFF2D4A2D)],
        );
      case TipCardStyle.dawn:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A2E), Color(0xFF4A2D3A), Color(0xFF6B3D2A)],
        );
      case TipCardStyle.night:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0E17), Color(0xFF0B0E17)],
        );
    }
  }
}
