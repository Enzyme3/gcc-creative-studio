# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Authentication guards and user retrieval."""


import asyncio
import logging

from fastapi import Depends, HTTPException, status, Header

# --- Google Auth for Identity Platform / IAP ---
from google.auth.transport import requests as google_auth_requests
from google.oauth2 import id_token

from src.config.config_service import config_service
from src.users.user_model import UserModel, UserRoleEnum
from src.users.user_service import UserService

logger = logging.getLogger(__name__)


async def get_current_user(
    x_goog_iap_jwt_assertion: str = Header(None),
    user_service: UserService = Depends(UserService),
) -> UserModel:
    """Dependency that handles the entire authentication and user provisioning flow.

    1. For local environment, bypasses authentication and returns a mocked Local Admin profile.
    2. For production/development, verifies the Google-issued IAP JWT token from the header.
    3. Extracts user information (email, name, picture).
    4. Just-In-Time (JIT) provisions the user profile in Postgres if they are new.
    """
    try:
        email = None
        name = None
        picture = ""
        token_info_hd = None

        if config_service.ENVIRONMENT == "local":
            # --- Local Bypass: Return Mock User Profile ---
            logger.info(
                "Bypassing authentication for local environment. Returning Mock User Profile."
            )
            email = "local-admin@example.com"
            name = "Local Admin"
            picture = ""
        else:
            # --- Development/Production: Validate Google IAP JWT Token ---
            if not x_goog_iap_jwt_assertion:
                logger.error("Missing X-Goog-IAP-JWT-Assertion header.")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication token is missing.",
                )

            logger.info("Verifying IAP JWT Token assertion...")
            expected_audience = config_service.IAP_AUDIENCE
            decoded_token = await asyncio.to_thread(
                id_token.verify_iap_token,
                x_goog_iap_jwt_assertion,
                google_auth_requests.Request(),
                audience=expected_audience,
            )

            email = decoded_token.get("email")
            name = decoded_token.get(
                "name", email.split("@")[0] if email else "IAP User"
            )
            picture = decoded_token.get("picture", "")
            token_info_hd = (
                email.split("@")[1] if email and "@" in email else None
            )

        if not email:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: User identity could not be confirmed from token.",
            )

        # If ALLOWED_ORGS is configured, check the user's organization.
        if config_service.ALLOWED_ORGS:
            if (
                not token_info_hd
                or token_info_hd not in config_service.ALLOWED_ORGS
            ):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"User from '{token_info_hd}' is not part of an allowed organization.",
                )

        # Just-In-Time (JIT) User Provisioning:
        # Create a user profile in our database on their first API call.
        user_doc = await user_service.create_user_if_not_exists(
            email=email,
            name=name,
            picture=picture,
        )

        if not user_doc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not create or retrieve user profile.",
            )

        if not user_doc.picture and picture:
            logger.info("Updating picture for user: %s", email)
            user_doc.picture = picture
            if user_doc.id:
                await user_service.user_repo.update(
                    user_doc.id, {"picture": picture}
                )

        return user_doc

    except HTTPException as e:
        logger.error("[get_current_user - Exception]: %s", e)
        raise e
    except Exception as e:
        logger.error("[get_current_user - Exception]: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred during authentication: {e}",
        ) from e


class RoleChecker:
    """Dependency that checks if the authenticated user has the required roles.
    It depends on `get_current_user` to ensure the user is authenticated first.
    """

    def __init__(self, allowed_roles: list[UserRoleEnum]):
        self.allowed_roles = allowed_roles

    def __call__(self, user: UserModel = Depends(get_current_user)):
        """Checks the user's roles against the allowed roles."""
        is_authorized = any(role in self.allowed_roles for role in user.roles)

        if not is_authorized:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "You do not have sufficient permissions to perform this "
                    "action."
                ),
            )
