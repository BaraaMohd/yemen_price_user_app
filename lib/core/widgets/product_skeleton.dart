// #4 - Skeleton Loading Widget
// Drop-in replacement shimmer placeholders for product cards while data loads.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmer card placeholder used while products are loading.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A3642) : Colors.grey.shade200;
    final highlightColor = isDark ? const Color(0xFF3A4A58) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _block(44, 44, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _block(16, double.infinity),
                        const SizedBox(height: 8),
                        _block(12, 120),
                      ],
                    ),
                  ),
                  _block(28, 60, radius: 8),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _block(12, 80),
                  const Spacer(),
                  _block(12, 60),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _block(double height, double width, {double radius = 6}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Renders a list of [count] skeleton cards.
class ProductListSkeleton extends StatelessWidget {
  final int count;
  const ProductListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, _) => const ProductCardSkeleton(),
    );
  }
}
