from django.urls import path
from .views import LoginView, RegisterView, CurrentUserView, CookieTokenRefreshView as Cus

urlpatterns = [
    path('login/', LoginView.as_view(), name="login"),
    path('register/', RegisterView.as_view(), name='register'),
    path('auth/user/', CurrentUserView.as_view(), name='current-user'),
    path('token/refresh/', Cus.as_view(), name='token_refresh'),
]