import httpx

from app.settings import settings


class InviteSender:
    """Sends a household invite email via Supabase Auth's admin invite API.

    Reuses Supabase's own email pipeline instead of standing up dedicated
    email infrastructure — see CLAUDE.md's Lessons Learned for the known
    free-tier rate-limit risk this accepts.
    """

    async def invite_user_by_email(self, email: str, redirect_to: str) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{settings.supabase_url}/auth/v1/invite",
                params={"redirect_to": redirect_to},
                json={"email": email},
                headers={
                    "apikey": settings.supabase_service_role_key,
                    "Authorization": f"Bearer {settings.supabase_service_role_key}",
                    "Content-Type": "application/json",
                },
            )
            resp.raise_for_status()
            return resp.json()


def get_invite_sender() -> InviteSender:
    return InviteSender()
