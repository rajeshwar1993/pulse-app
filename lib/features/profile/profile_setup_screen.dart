import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/avatar_gallery.dart';
import '../../core/services/profile_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/widgets.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _selectedAvatarUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _timezone {
    // Get device timezone
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60);

    // Format as UTC offset (e.g., "UTC+05:30")
    final sign = hours >= 0 ? '+' : '';
    return 'UTC$sign$hours:${minutes.abs().toString().padLeft(2, '0')}';
  }

  bool get _isValid {
    return _nameController.text.trim().length >= 2 &&
        _selectedAvatarUrl != null;
  }

  Future<void> _createProfile() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileService = ref.read(profileServiceProvider);
      await profileService.createProfile(
        displayName: _nameController.text.trim(),
        avatarUrl: _selectedAvatarUrl!,
        timezone: _timezone,
      );

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n.failedCreateProfile(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrls = AvatarGallery.getAvatarUrls();

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(l10n.setUpYourProfile),
        backgroundColor: AppColors.offWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Message
            if (_errorMessage != null) ...[
              PulseErrorBanner(message: _errorMessage!),
              const SizedBox(height: 24),
            ],

            // Display Name
            Text(
              l10n.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            PulseTextField(
              controller: _nameController,
              hintText: l10n.enterYourName,
              maxLength: 50,
              suffixText: '${_nameController.text.length}/50',
              counterText: '',
              onChanged: (_) => setState(() {}),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),

            // Avatar Gallery
            Text(
              l10n.chooseYourAvatar,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: avatarUrls.length,
              itemBuilder: (context, index) {
                final url = avatarUrls[index];
                return PulseAvatar.selectable(
                  imageUrl: url,
                  selected: url == _selectedAvatarUrl,
                  onTap: _isLoading
                      ? null
                      : () => setState(() => _selectedAvatarUrl = url),
                );
              },
            ),
            const SizedBox(height: 24),

            // Selected Avatar Preview
            if (_selectedAvatarUrl != null) ...[
              Text(
                l10n.selectedAvatar,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Center(
                child: PulseAvatar.preview(imageUrl: _selectedAvatarUrl!),
              ),
              const SizedBox(height: 24),
            ],

            // Continue Button
            PulseButton.primary(
              onPressed: _isValid && !_isLoading ? _createProfile : null,
              label: l10n.continueButton,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
