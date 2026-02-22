import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/coupon.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  String _filter = 'available';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('My Rewards'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ProfileProvider>().loadProfile(),
          ),
        ],
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final allCoupons = profileProvider.coupons;
          final filteredCoupons = allCoupons.where((c) {
            if (_filter == 'available')
              return c.status == CouponStatus.available ||
                  c.status == CouponStatus.locked;
            if (_filter == 'used') return c.status == CouponStatus.used;
            return true;
          }).toList();

          return Column(
            children: [
              _buildFilters(),
              Expanded(
                child: filteredCoupons.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredCoupons.length,
                        itemBuilder: (context, index) => _buildCouponCard(
                            context, filteredCoupons[index], profileProvider),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _filterChip('Available', 'available'),
          const SizedBox(width: 10),
          _filterChip('Used', 'used'),
          const SizedBox(width: 10),
          _filterChip('All', 'all'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? Colors.transparent : context.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCouponCard(
      BuildContext context, Coupon coupon, ProfileProvider provider) {
    final bool isAvailable = coupon.status == CouponStatus.available;
    final bool isLocked = coupon.status == CouponStatus.locked;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          colorFilter: isLocked
              ? const ColorFilter.matrix([
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLocked
                    ? context.borderColor
                    : AppColors.primary.withOpacity(0.3),
              ),
              boxShadow: isAvailable
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Emoji Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? context.surfaceBg
                        : AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      coupon.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.title,
                        style: TextStyle(
                          color: isLocked
                              ? context.textMuted
                              : context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coupon.offer,
                        style: TextStyle(
                          color: isLocked
                              ? context.textMuted.withOpacity(0.6)
                              : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '🔒 ${coupon.description}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              color: context.textMuted, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              coupon.location,
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isAvailable)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _useCoupon(context, coupon, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Use Now',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Exp: ${coupon.expiresAt.difference(DateTime.now()).inDays}d',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.surfaceBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      coupon.status.name.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.textMuted,
                          letterSpacing: 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Ticket Notches
        Positioned(
          left: -8,
          top: 40,
          child: CircleAvatar(radius: 8, backgroundColor: context.bg),
        ),
        Positioned(
          right: -8,
          top: 40,
          child: CircleAvatar(radius: 8, backgroundColor: context.bg),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.redeem,
              size: 80, color: context.textMuted.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text('No rewards yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textSecondary)),
          const SizedBox(height: 10),
          Text('Unlock badges to earn exclusive stickers and coupons!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted)),
        ],
      ),
    );
  }

  void _useCoupon(
      BuildContext context, Coupon coupon, ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Redeem Reward?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Show this code to the vendor:',
                style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    coupon.code,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.copy,
                        size: 20, color: AppColors.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: coupon.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Code copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text('Show this to the vendor OR copy code for online use.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later')),
          ElevatedButton(
            onPressed: () {
              provider.useCoupon(coupon.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Reward redeemed successfully! 🥳')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Mark as Used'),
          ),
        ],
      ),
    );
  }
}
