"""
Authentication service - handles JWT and OAuth2
"""
import logging
from datetime import datetime, timedelta
from typing import Optional
import jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from config import get_settings
from models import User
from schemas import UserCreate, UserGoogleAuth, UserResponse

logger = logging.getLogger(__name__)
settings = get_settings()

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthService:
    """Authentication service"""

    @staticmethod
    def hash_password(password: str) -> str:
        """Hash a password"""
        return pwd_context.hash(password)

    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a password against hash"""
        return pwd_context.verify(plain_password, hashed_password)

    @staticmethod
    def create_access_token(user_id: int, expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token"""
        if expires_delta is None:
            expires_delta = timedelta(hours=settings.JWT_EXPIRATION_HOURS)

        expire = datetime.utcnow() + expires_delta
        to_encode = {
            "sub": str(user_id),
            "exp": expire,
            "iat": datetime.utcnow(),
        }

        encoded_jwt = jwt.encode(
            to_encode,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM,
        )
        return encoded_jwt

    @staticmethod
    def decode_token(token: str) -> Optional[dict]:
        """Decode and validate JWT token"""
        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET_KEY,
                algorithms=[settings.JWT_ALGORITHM],
            )
            user_id: str = payload.get("sub")
            if user_id is None:
                return None
            return {"user_id": int(user_id)}
        except jwt.ExpiredSignatureError:
            logger.warning("Token has expired")
            return None
        except jwt.InvalidTokenError:
            logger.warning("Invalid token")
            return None

    @staticmethod
    def register_user(db: Session, user_create: UserCreate) -> User:
        """Register a new user with email/password"""
        # Check if user exists
        existing_user = db.query(User).filter(User.email == user_create.email).first()
        if existing_user:
            raise ValueError("User with this email already exists")

        hashed_password = AuthService.hash_password(user_create.password)

        db_user = User(
            email=user_create.email,
            username=user_create.username,
            full_name=user_create.full_name,
            hashed_password=hashed_password,
            role=user_create.role or "requestor",
            is_active=True,
        )

        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        logger.info(f"Registered new user: {user_create.email}")
        return db_user

    @staticmethod
    def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
        """Authenticate user with email and password"""
        user = db.query(User).filter(User.email == email).first()
        if not user or not user.hashed_password:
            return None
        if not AuthService.verify_password(password, user.hashed_password):
            return None
        if not user.is_active:
            return None
        return user

    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
        """Get user by ID"""
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        """Get user by email"""
        return db.query(User).filter(User.email == email).first()

    @staticmethod
    def get_user_by_google_id(db: Session, google_id: str) -> Optional[User]:
        """Get user by Google ID"""
        return db.query(User).filter(User.google_id == google_id).first()

    @staticmethod
    def create_or_update_google_user(
        db: Session, google_auth: UserGoogleAuth
    ) -> User:
        """Create or update user from Google OAuth"""
        user = AuthService.get_user_by_google_id(db, google_auth.google_id)

        if user:
            # Update existing user
            user.full_name = google_auth.full_name
            db.commit()
            db.refresh(user)
        else:
            # Check if email already exists
            user = AuthService.get_user_by_email(db, google_auth.email)
            if user:
                # Link Google account to existing user
                user.google_id = google_auth.google_id
                db.commit()
                db.refresh(user)
            else:
                # Create new user
                username = google_auth.email.split("@")[0]
                # Ensure unique username
                base_username = username
                counter = 1
                while db.query(User).filter(User.username == username).first():
                    username = f"{base_username}{counter}"
                    counter += 1

                user = User(
                    email=google_auth.email,
                    username=username,
                    full_name=google_auth.full_name,
                    google_id=google_auth.google_id,
                    is_active=True,
                    role="requestor",
                )
                db.add(user)
                db.commit()
                db.refresh(user)

        logger.info(f"Created/updated Google user: {google_auth.email}")
        return user
