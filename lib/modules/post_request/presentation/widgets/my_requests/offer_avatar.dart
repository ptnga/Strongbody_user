import 'package:flutter/material.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';

import '../../../domain/entities/my_request_entity.dart';

/// Ảnh provider của offer (chữ viết tắt khi không có ảnh), viền trắng để xếp chồng.
class OfferAvatar extends StatelessWidget {
  final RequestOfferEntity offer;

  /// Vị trí trong dải avatar — chọn màu nền.
  final int index;
  final double size;

  const OfferAvatar({
    super.key,
    required this.offer,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => InitialsAvatar(
    name: offer.sellerName,
    imageUrl: offer.sellerAvatar,
    colorSeed: index,
    size: size,
    border: true,
  );
}
