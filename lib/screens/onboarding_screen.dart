import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/avatar_parts_config.dart';
import '../config/limits.dart';
import '../providers/auth_provider.dart';
import 'avatar_creation_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _smartGoalController = TextEditingController();

  int _currentPage = 0;
  Map<String, String> _avatarConfig = AvatarPartsConfig.defaultConfig;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authInstanceProvider).currentUser;
    if (authUser != null && authUser.displayName != null) {
      final displayName = authUser.displayName!.trim();
      _nameController.text = displayName.length > TextLimits.name
          ? displayName.substring(0, TextLimits.name)
          : displayName;
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final isSubmitting = ref.watch(authNotifierProvider).isLoading;

    // ── Sign-in screen (not yet authenticated) ───────────────────────
    if (user == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade900, Colors.deepPurple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏰', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 16),
                  const Text(
                    'KINGDOM',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cooperative Spiritual Habits & Accountability',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () => ref
                              .read(authNotifierProvider.notifier)
                              .signInWithGoogle(),
                    icon: const Icon(Icons.login, color: Colors.black),
                    label: Text(
                      isSubmitting ? 'Signing in...' : 'Sign in with Google',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Onboarding flow (3 pages) ────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentPage + 1} of 3'),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        children: [
          // ─ Page 1: Display Name ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome! What should we call you?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This name will be visible to members of your cell group building.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  maxLength: TextLimits.name,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.trim().isNotEmpty) _nextPage();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Next: Design Your Avatar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─ Page 2: Avatar Creation ─────────────────────────────────
          Column(
            children: [
              Expanded(
                child: AvatarCreationPanel(
                  initialConfig: _avatarConfig,
                  onConfigChanged: (config) {
                    _avatarConfig = config;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Next: Set SMART Goal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─ Page 4: SMART Goal ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set Your Initial SMART Goal',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Specific, Measurable, Achievable, Relevant, Time-bound spiritual habit. '
                  '(This content remains 100% PRIVATE to you).',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _smartGoalController,
                  maxLines: 4,
                  maxLength: TextLimits.goalText,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Read 1 chapter of the Gospel of John every morning at 7:30 AM',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              final name = _nameController.text.trim();
                              final goal = _smartGoalController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a display name (Step 1)',
                                    ),
                                  ),
                                );
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                return;
                              }
                              if (goal.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter your SMART goal before completing setup.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              ref
                                  .read(authNotifierProvider.notifier)
                                  .completeOnboarding(
                                    name: name,
                                    avatarConfig: _avatarConfig,
                                    smartGoalText: goal,
                                  );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isSubmitting
                            ? 'Creating Profile...'
                            : 'Complete Setup 🚀',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
