import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';

/// Menampilkan animasi hati di posisi layar yang dipilih (double-tap pesan).
///
/// Memakai [Overlay] agar animasi tidak terpotong oleh bubble dan tetap
/// terlihat di atas elemen lain.
void showHeartBurst(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: globalPosition.dx - 42,
      top: globalPosition.dy - 42,
      child: const SizedBox(
        width: 84,
        height: 84,
        child: HeartBurst(),
      ),
    ),
  );

  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 800), () {
    if (entry.mounted) entry.remove();
  });
}

/// Bubble "sedang mengetik" dengan tiga titik yang beranimasi naik-turun.
///
/// Meniru tampilan WhatsApp: tiga titik bergerak bergantian agar terasa
/// hidup saat lawan chat sedang menulis.
class TypingIndicatorBubble extends StatefulWidget {
  const TypingIndicatorBubble({super.key});

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WhatsAppTheme.darkBubbleIncoming,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(2),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Tiap titik punya fase tertunda agar geraknya berurutan.
              final phase = (_controller.value - i * 0.2) % 1.0;
              final lift = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              return Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 4, bottom: lift * 4),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: WhatsAppTheme.darkTextSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Animasi hati melayang yang muncul saat pengguna double-tap pesan
/// untuk bereaksi cepat.
class HeartBurst extends StatelessWidget {
  const HeartBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        // Skala: membesar lalu mengecil, opasitas: muncul lalu menghilang.
        final scale = 0.6 + (t < 0.4 ? (t / 0.4) * 0.7 : (1 - (t - 0.4) / 0.6) * 0.4);
        final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.redAccent,
              size: 84,
            ),
          ),
        );
      },
    );
  }
}
