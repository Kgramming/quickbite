"""Application configuration using Pydantic Settings."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # API Configuration
    api_host: str = "127.0.0.1"
    api_port: int = 8002
    log_level: str = "info"

    # Database Configuration
    database_url: str = "postgresql+psycopg://quickbite_user:quickbite_password@127.0.0.1:5434/quickbite_db"
    database_echo: bool = False

    # RabbitMQ Configuration
    rabbitmq_host: str = "127.0.0.1"
    rabbitmq_port: int = 5672
    rabbitmq_user: str = "quickbite"
    rabbitmq_password: str = "quickbite_password"
    rabbitmq_vhost: str = "/"

    # Application
    environment: str = "development"
    debug: bool = False

    # Auth (JWT)
    jwt_secret: str = "dev-only-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_hours: int = 24

    # CORS — explicit origins (no wildcard with credentials)
    cors_origins: str = "http://localhost:3000,http://localhost:8080,http://localhost:5173,http://localhost:8091"

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
