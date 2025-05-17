from allauth.account.adapter import DefaultAccountAdapter

class MyAccountAdapter(DefaultAccountAdapter):
    def get_email_confirmation_url(self, request, emailconfirmation):
        confirmation_key = emailconfirmation.key
        return f"http://localhost:3000/email-confirmation?key={confirmation_key}"
