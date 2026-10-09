from django.test import TestCase
from django.urls import reverse

from .models import Category, Provider


class ProviderTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.tailor = Category.objects.create(name="Couture")
        cls.garage = Category.objects.create(name="Mécanique")
        cls.visible = Provider.objects.create(
            name="Atelier Awa",
            category=cls.tailor,
            city="Abidjan",
            phone="+225 07 00 00 00 00",
            is_approved=True,
        )
        cls.hidden = Provider.objects.create(
            name="Garage Kofi",
            category=cls.garage,
            city="Bouaké",
            phone="+225 05 11 22 33 44",
        )

    def test_list_hides_unapproved(self):
        response = self.client.get(reverse("directory:list"))
        self.assertContains(response, "Atelier Awa")
        self.assertNotContains(response, "Garage Kofi")

    def test_search_by_name(self):
        response = self.client.get(reverse("directory:list"), {"q": "awa"})
        self.assertContains(response, "Atelier Awa")

    def test_filter_by_category(self):
        response = self.client.get(
            reverse("directory:list"), {"category": self.garage.pk}
        )
        self.assertNotContains(response, "Atelier Awa")

    def test_detail_404_when_unapproved(self):
        response = self.client.get(reverse("directory:detail", args=[self.hidden.pk]))
        self.assertEqual(response.status_code, 404)

    def test_whatsapp_url_keeps_digits_only(self):
        self.assertEqual(self.visible.whatsapp_url, "https://wa.me/2250700000000")

    def test_submit_creates_unapproved_provider(self):
        response = self.client.post(
            reverse("directory:submit"),
            {
                "name": "Coiffure Mariam",
                "category": self.tailor.pk,
                "city": "Dakar",
                "phone": "+221 77 000 00 00",
                "description": "",
            },
        )
        self.assertRedirects(response, reverse("directory:thanks"))
        created = Provider.objects.get(name="Coiffure Mariam")
        self.assertFalse(created.is_approved)

    def test_honeypot_blocks_submission(self):
        response = self.client.post(
            reverse("directory:submit"),
            {
                "name": "Bot",
                "category": self.tailor.pk,
                "city": "Lomé",
                "phone": "+228 90 00 00 00",
                "website": "http://spam.example",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Provider.objects.filter(name="Bot").exists())
