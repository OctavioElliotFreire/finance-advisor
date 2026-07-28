from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = (
        "postgresql+psycopg://finance_app:local-development-only"
        "@localhost:5432/family_finance"
    )

    auth_provider: str = "supabase"
    supabase_url: str = ""
    supabase_jwt_issuer: str = ""
    supabase_jwt_audience: str = "authenticated"
    supabase_jwt_secret: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""

    pluggy_client_id: str = ""
    pluggy_client_secret: str = ""

    # Matches Flutter Web dev servers on any localhost port (PLAN.md "Local
    # API Addresses"). Override in production to the real deployed origin(s).
    cors_allowed_origin_regex: str = r"http://localhost(:\d+)?"

    llm_provider: str = "anthropic"
    anthropic_api_key: str = ""
    gemini_api_key: str = ""


settings = Settings()
