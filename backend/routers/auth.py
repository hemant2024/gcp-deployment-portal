"""
Authentication API routes
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from schemas import LoginRequest, UserCreate, TokenResponse, UserResponse
from services.auth_service import AuthService
from database import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
async def register(
    user_create: UserCreate,
    db: Session = Depends(get_db),
):
    """Register new user"""
    try:
        user = AuthService.register_user(db, user_create)
        token = AuthService.create_access_token(user.id)
        return TokenResponse(
            access_token=token,
            user=UserResponse.from_orm(user),
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/login", response_model=TokenResponse)
async def login(
    credentials: LoginRequest,
    db: Session = Depends(get_db),
):
    """Login with email and password"""
    user = AuthService.authenticate_user(db, credentials.email, credentials.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    token = AuthService.create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        user=UserResponse.from_orm(user),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Refresh access token"""
    user = AuthService.get_user_by_id(db, current_user.id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    token = AuthService.create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        user=UserResponse.from_orm(user),
    )


@router.post("/google-callback", response_model=TokenResponse)
async def google_callback(
    google_token: str,
    db: Session = Depends(get_db),
):
    """
    Google OAuth callback
    In production, validate the token with Google first
    """
    try:
        # TODO: Validate google_token with Google API
        # For now, just create a test user
        from schemas import UserGoogleAuth

        # This would be decoded from the Google ID token
        google_auth = UserGoogleAuth(
            google_id="test_google_id",
            email="user@gmail.com",
            full_name="Test User",
        )

        user = AuthService.create_or_update_google_user(db, google_auth)
        token = AuthService.create_access_token(user.id)

        return TokenResponse(
            access_token=token,
            user=UserResponse.from_orm(user),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ==================== Dependency ====================

async def get_current_user(
    token: str = Header(None),
    db: Session = Depends(get_db),
) -> UserResponse:
    """Get current authenticated user from token"""
    from fastapi import Header

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )

    # Extract token from "Bearer <token>" format
    if token.startswith("Bearer "):
        token = token[7:]

    decoded = AuthService.decode_token(token)
    if not decoded:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user = AuthService.get_user_by_id(db, decoded["user_id"])
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return UserResponse.from_orm(user)
