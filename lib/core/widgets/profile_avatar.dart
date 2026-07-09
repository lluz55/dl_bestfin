import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bestfin/core/providers/user_profile_provider.dart';

/// Avatar circular do perfil do usuário: foto quando existe, senão as
/// iniciais do nome, senão um ícone genérico de pessoa.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  final UserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (profile.hasPhoto) {
      return CircleAvatar(
        // O caminho da foto muda a cada troca (timestamp no nome do arquivo),
        // então a key garante que o avatar não reutilize a imagem anterior.
        key: ValueKey(profile.photoPath),
        radius: radius,
        backgroundColor: cs.surfaceContainerHighest,
        backgroundImage: FileImage(File(profile.photoPath!)),
      );
    }

    if (profile.initials case final initials?) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.surfaceContainerHighest,
      child: Icon(
        Icons.person_outline_rounded,
        size: radius * 1.1,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
