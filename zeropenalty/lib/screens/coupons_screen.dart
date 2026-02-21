import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('My Rewards'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final allCoupons = profileProvider.coupons;
          final filteredCoupons = allCoupons.where((c) {
            if (_filter == 'available')
              return c.status == CouponStatus.available;
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
    final isAvailable = coupon.status == CouponStatus.available;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isAvailable
                      ? AppColors.primary.withOpacity(0.3)
                      : context.borderColor),
              boxShadow: [
                if (isAvailable)
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AppColors.primary.withOpacity(0.1)
                        : context.surfaceBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(coupon.emoji,
                        style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isAvailable
                                ? context.textPrimary
                                : context.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(coupon.offer,
                          style: TextStyle(
                              fontSize: 13, color: context.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 12, color: context.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              coupon.location,
                              style: TextStyle(
                                  fontSize: 11, color: context.textMuted),
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
                    children: [
                      ElevatedButton(
                        onPressed: () => _useCoupon(context, coupon, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Use Now'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Exp in ${coupon.expiresAt.difference(DateTime.now()).inDays}d',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.danger),
                      ),
                    ],
                  )
                else
                  Text(
                    coupon.status.name.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.textMuted),
                  ),
              ],
            ),
          ),
          // Ticket notches
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
      ),
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
              child: Text(
                coupon.code,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 15),
            Text('This reward will be marked as used.',
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
