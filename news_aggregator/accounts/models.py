from django.contrib.auth.models import AbstractUser

class CustomUser(AbstractUser):
    # Todo: See what additional fields are needed

    def __str__(self):
        return self.username
