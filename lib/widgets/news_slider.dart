import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NewsSlider extends StatefulWidget {
  const NewsSlider({super.key});

  @override
  State<NewsSlider> createState() => _NewsSliderState();
}

class _NewsSliderState extends State<NewsSlider> {
  final _controller = PageController(viewportFraction: 1);
  Timer? _timer;
  int _index = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _count <= 1 || !_controller.hasClients) return;
      final next = (_index + 1) % _count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('news')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 170,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (_count != docs.length) {
          _count = docs.length;
          if (_index >= _count && _count > 0) {
            _index = 0;
          }
          _startTimer();
        }
        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 136,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: docs.length,
                  onPageChanged: (v) => setState(() => _index = v),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final title = (data['title'] ?? '').toString();
                    final body = (data['body'] ?? '').toString();
                    final imageUrl = (data['imageUrl'] ?? '').toString();
                    return Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5C2798), Color(0xFF261446)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withOpacity(0.8)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 78,
                            height: 108,
                            decoration: BoxDecoration(
                              color: AppColors.cardSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.campaign, color: AppColors.hotPink),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Latest News',
                                  style: TextStyle(
                                    color: AppColors.hotPink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (docs.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    docs.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.hotPink : AppColors.textMuted.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
