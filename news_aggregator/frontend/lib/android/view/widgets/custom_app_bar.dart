import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final Widget? leadingIcon;
  final VoidCallback? onPressedLeading;
  final List<Widget>? actions;
  final Widget? profilePicture;
  final VoidCallback? onPressedProfilePicture;

  const CustomAppBar({
    super.key,
    required this.title,
    this.leadingIcon,
    this.onPressedLeading,
    this.actions,
    this.profilePicture,
    this.onPressedProfilePicture,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.lightBrown,
      elevation: 0,
      centerTitle: true,
      title: title,
      leading:
          (leadingIcon != null && onPressedLeading != null)
              ? IconButton(icon: leadingIcon!, onPressed: onPressedLeading)
              : null,
      actions:
          profilePicture != null
              ? [_buildProfilePicture(profilePicture!)]
              : (actions ?? []),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  Widget _buildProfilePicture(Widget profilePicture) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onPressedProfilePicture,
        borderRadius: BorderRadius.circular(60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(60),
          child: profilePicture,
        ),
      ),
    );
  }
}
