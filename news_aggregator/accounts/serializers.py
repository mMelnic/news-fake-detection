from dj_rest_auth.serializers import UserDetailsSerializer
from accounts.models import CustomUser

class UserSerializer(UserDetailsSerializer):
    class Meta(UserDetailsSerializer.Meta):
        model = CustomUser
        fields = ('id', 'username', 'email', 'first_name', 'last_name')
