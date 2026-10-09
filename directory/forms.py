from django import forms

from .models import Provider

MAX_PHOTO_SIZE = 2 * 1024 * 1024


class ProviderForm(forms.ModelForm):
    # Honeypot: hidden from humans, bots tend to fill every field
    website = forms.CharField(required=False)

    class Meta:
        model = Provider
        fields = ["name", "category", "city", "phone", "description", "photo"]

    def clean_website(self):
        if self.cleaned_data["website"]:
            raise forms.ValidationError("Spam détecté.")
        return ""

    def clean_photo(self):
        photo = self.cleaned_data.get("photo")
        if photo and photo.size > MAX_PHOTO_SIZE:
            raise forms.ValidationError("La photo ne doit pas dépasser 2 Mo.")
        return photo
