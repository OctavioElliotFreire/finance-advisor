import 'dart:html' as html;

/// go_router reads the browser's actual current URL (not just the
/// `initialLocation` constructor param) when it builds on web. Left alone,
/// Supabase's raw invite-redirect fragment (`#access_token=...&type=invite`)
/// gets parsed as a route path and throws a GoException before our own code
/// ever runs. Rewriting the address bar to a clean route first — via the
/// same `history.replaceState` mechanism any SPA router uses — means
/// go_router sees a normal, resolvable location by the time it initializes.
void cleanupInviteRedirectUrl(String cleanPath) {
  html.window.history.replaceState(null, '', cleanPath);
}
