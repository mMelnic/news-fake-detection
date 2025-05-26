from django.contrib.auth.models import AbstractUser
from django.db import models
from django_countries.fields import CountryField

class CustomUser(AbstractUser):
    bio = models.TextField(blank=True, null=True)
    display_name = models.CharField(max_length=100, blank=True, null=True)
    preferred_language = models.CharField(max_length=10, blank=True, null=True)
    country = CountryField(blank=True, null=True)
    
    def __str__(self):
        return self.username
