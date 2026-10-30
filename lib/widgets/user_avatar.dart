import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool showOnlineBadge;
  final bool isOnline;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 22,
    this.showOnlineBadge = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
        : '?';

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.8,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                errorWidget: (context, url, error) => Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.8,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            )
          : Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
    );

    if (!showOnlineBadge) return avatar;

    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.6,
            height: radius * 0.6,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
