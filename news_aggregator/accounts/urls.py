from django.urls import path
from .views import LoginView, RegisterView, CurrentUserView, LogoutView, CookieTokenRefreshView as Cus

urlpatterns = [
    path('auth/login/', LoginView.as_view(), name="login"),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/user/', CurrentUserView.as_view(), name='current-user'),
    path('token/refresh/', Cus.as_view(), name='token_refresh'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
]