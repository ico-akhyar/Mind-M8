import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../providers/auth_provider.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/premium_plans_screen.dart';
import '../screens/coming_soon_screen.dart';
import '../screens/roast_screen.dart';
import '../screens/subscription_status_screen.dart';


class AppDrawer extends ConsumerStatefulWidget {
  final Future<void> Function()? onSettingsClosed;

  const AppDrawer({super.key, this.onSettingsClosed});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState(); // 👈 Ye line theek rakhni hy
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  int _selectedIndex = 0;

  Widget _buildMenuItem(
      BuildContext context, {
        required int index,
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            icon,
            size: 20,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.8),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
          trailing: isSelected
              ? Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
          )
              : null,
          onTap: () {
            setState(() => _selectedIndex = index);
            onTap();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minLeadingWidth: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            right: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              height: 200,
              padding: const EdgeInsets.only(left: 45, bottom: 24, right: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.25),
                    theme.colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: user?.photoURL != null
                        ? ClipOval(
                      child: Image.network(
                        user!.photoURL!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Icon(
                      FeatherIcons.user,
                      size: 30,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.displayName ?? 'Welcome Back',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Your virtual friend is here',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildMenuItem(
                          context,
                          index: 0,
                          icon: FeatherIcons.messageCircle,
                          title: 'Chat',
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildMenuItem(
                          context,
                          index: 1,
                          icon: FeatherIcons.heart,
                          title: 'Support Mode',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ComingSoonScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          context,
                          index: 5,
                          icon: FeatherIcons.alertTriangle,
                          title: 'Roast Mode',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const RoastScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          context,
                          index: 2, // Make sure this index is unique
                          icon: FeatherIcons.barChart2,
                          title: 'Subscription Status',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SubscriptionStatusScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          context,
                          index: 3,
                          icon: FeatherIcons.unlock,
                          title: 'Upgrade to Premium',
                          onTap: () {
                            Navigator.pop(context); // closes drawer
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PremiumPlansScreen(),
                              ),
                            );
                          },
                        ),
                      ]),
                    ),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: Divider(
                        height: 0,
                        thickness: 0.5,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 16),
                    sliver: SliverList(
                    delegate: SliverChildListDelegate([
                    _buildMenuItem(
    context,
    index: 4,
    icon: FeatherIcons.settings,
    title: 'Settings',
    onTap: () async {
    Navigator.pop(context); // close drawer first
    final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result == 'chats_cleared' && widget.onSettingsClosed!() != null) {
    await widget.onSettingsClosed!(); // ✅ call sync from HomeScreen
    }}
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                children: [
                  const Divider(height: 0, thickness: 0.5, color: Colors.white24),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(FeatherIcons.logOut, size: 18),
                      label: const Text('Sign Out'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        ref.read(authProvider.notifier).signOut();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mind M8 • V1.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}