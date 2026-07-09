import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/user_profile_provider.dart';
import 'package:bestfin/core/widgets/profile_avatar.dart';

/// Editor do perfil do usuário (foto + nome). Aplica as mudanças
/// imediatamente no [userProfileProvider] — usado no onboarding e nas
/// configurações, sem botão de salvar.
class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({super.key});

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late final TextEditingController _nameController;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(userProfileProvider).name ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    _pickingPhoto = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      await ref.read(userProfileProvider.notifier).setPhoto(picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível carregar a imagem: $e')),
        );
      }
    } finally {
      _pickingPhoto = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final profile = ref.watch(userProfileProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            InkWell(
              onTap: _pickPhoto,
              customBorder: const CircleBorder(),
              child: ProfileAvatar(profile: profile, radius: 48),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: cs.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _pickPhoto,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (profile.hasPhoto)
          TextButton(
            onPressed: () =>
                ref.read(userProfileProvider.notifier).removePhoto(),
            child: Text(
              'Remover foto',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Seu nome',
            hintText: 'Como podemos te chamar?',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (value) =>
              unawaited(ref.read(userProfileProvider.notifier).setName(value)),
        ),
      ],
    );
  }
}
