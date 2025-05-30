from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.middleware import csrf

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from .serializers import UserSerializer

def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }

class LoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request, format=None):
        data = request.data
        response = Response()
        username = data.get('username', None)
        password = data.get('password', None)
        user = authenticate(username=username, password=password)

        if user is not None:
            if user.is_active:
                data = get_tokens_for_user(user)
                response.set_cookie(
                    key = settings.SIMPLE_JWT['AUTH_COOKIE'],
                    value = data["access"],
                    expires = settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'],
                    secure = settings.SIMPLE_JWT['AUTH_COOKIE_SECURE'],
                    httponly = settings.SIMPLE_JWT['AUTH_COOKIE_HTTP_ONLY'],
                    samesite = settings.SIMPLE_JWT['AUTH_COOKIE_SAMESITE']
                )
                response.set_cookie(
                    key=settings.SIMPLE_JWT['REFRESH_COOKIE'],
                    value=data['refresh'],
                    expires=settings.SIMPLE_JWT['REFRESH_TOKEN_LIFETIME'],
                    secure=settings.SIMPLE_JWT['REFRESH_COOKIE_SECURE'],
                    httponly=settings.SIMPLE_JWT['REFRESH_COOKIE_HTTP_ONLY'],
                    samesite=settings.SIMPLE_JWT['REFRESH_COOKIE_SAMESITE'],
                )
                csrf.get_token(request)
                response.data = {"Success" : "Login successfully","data":data}
                return response
            else:
                return Response({"No active" : "This account is not active!!"}, status=status.HTTP_404_NOT_FOUND)
        else:
            return Response({"Invalid" : "Invalid username or password!!"}, status=status.HTTP_404_NOT_FOUND)
        
User = get_user_model()

class RegisterView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    def post(self, request):
        data = request.data
        username = data.get('username')
        password = data.get('password')
        email = data.get('email')

        if not username or not password or not email:
            return Response({'error': 'All fields are required'}, status=400)

        try:
            validate_password(password)
        except ValidationError as e:
            return Response({'error': e.messages}, status=400)

        if User.objects.filter(username=username).exists():
            return Response({'error': 'Username exists'}, status=400)
        if User.objects.filter(email=email).exists():
            return Response({'error': 'Email exists'}, status=400)

        user = User.objects.create(
            username=username,
            email=email,
            password=make_password(password),
            is_active=True
        )

        # Auto-login after registration
        refresh = RefreshToken.for_user(user)
        response = Response({'success': 'User registered'}, status=201)
        
        response.set_cookie(
            key=settings.SIMPLE_JWT['AUTH_COOKIE'],
            value=str(refresh.access_token),
            expires=settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'],
            secure=settings.SIMPLE_JWT['AUTH_COOKIE_SECURE'],
            httponly=settings.SIMPLE_JWT['AUTH_COOKIE_HTTP_ONLY'],
            samesite=settings.SIMPLE_JWT['AUTH_COOKIE_SAMESITE'],
        )
        response.set_cookie(
            key=settings.SIMPLE_JWT['REFRESH_COOKIE'],
            value=str(refresh),
            expires=settings.SIMPLE_JWT['REFRESH_TOKEN_LIFETIME'],
            secure=settings.SIMPLE_JWT['REFRESH_COOKIE_SECURE'],
            httponly=settings.SIMPLE_JWT['REFRESH_COOKIE_HTTP_ONLY'],
            samesite=settings.SIMPLE_JWT['REFRESH_COOKIE_SAMESITE'],
        )
        
        return response
    
class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)
    
class CookieTokenRefreshView(TokenRefreshView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request, *args, **kwargs):
        refresh_token = request.COOKIES.get(settings.SIMPLE_JWT['REFRESH_COOKIE'])
        print(f"Refresh request cookies: {request.COOKIES}")
        print(f"Request headers: {request.headers}")
        print(f"Refresh token: {refresh_token}")
        if refresh_token is None:
            return Response({"detail": "Refresh token not provided."}, status=status.HTTP_401_UNAUTHORIZED)

        data = request.data.copy()
        data['refresh'] = refresh_token
        request._full_data = data

        response = super().post(request, *args, **kwargs)
        if response.status_code == 200 and 'access' in response.data:
            access_token = response.data['access']
            response.set_cookie(
                key=settings.SIMPLE_JWT['AUTH_COOKIE'],
                value=access_token,
                expires=settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'],
                secure=settings.SIMPLE_JWT['AUTH_COOKIE_SECURE'],
                httponly=settings.SIMPLE_JWT['AUTH_COOKIE_HTTP_ONLY'],
                samesite=settings.SIMPLE_JWT['AUTH_COOKIE_SAMESITE'],
            )
        return response
    
class LogoutView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request):
        response = Response()
        response.delete_cookie(settings.SIMPLE_JWT['AUTH_COOKIE'])
        response.delete_cookie(settings.SIMPLE_JWT['REFRESH_COOKIE'])
        response.data = {"success": "Logged out successfully."}
        return response

class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')

        if not user.check_password(old_password):
            return Response({"error": "Old password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            validate_password(new_password, user)
        except ValidationError as e:
            return Response({"error": e.messages}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save()

        return Response({"success": "Password changed successfully."}, status=status.HTTP_200_OK)

class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'id': user.id,
            'username': user.username,
            'display_name': user.display_name or user.username,
            'bio': user.bio or '',
            'email': user.email,
            'preferred_language': user.preferred_language or '',
            'country': str(user.country) if user.country else '',
        })

    def patch(self, request):
        user = request.user
        display_name = request.data.get('display_name')
        bio = request.data.get('bio')
        preferred_language = request.data.get('preferred_language')
        country = request.data.get('country')

        if display_name is not None:
            user.display_name = display_name
        if bio is not None:
            user.bio = bio
        if preferred_language is not None:
            user.preferred_language = preferred_language
        if country is not None:
            user.country = country

        user.save()
        return Response({
            'id': user.id,
            'username': user.username,
            'display_name': user.display_name or user.username,
            'bio': user.bio or '',
            'email': user.email,
            'preferred_language': user.preferred_language or '',
            'country': str(user.country) if user.country else '',
        })
