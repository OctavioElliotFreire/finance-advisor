/// pt-BR display label for a household member's raw backend role
/// (`'owner'`/`'member'`). Falls back to the raw value for anything else so
/// an unexpected role never disappears silently.
String roleLabel(String role) {
  return switch (role) {
    'owner' => 'Responsável',
    'member' => 'Membro',
    'viewer' => 'Visualizador',
    _ => role,
  };
}
