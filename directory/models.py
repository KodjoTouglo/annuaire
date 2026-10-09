from django.db import models


class Category(models.Model):
    name = models.CharField("nom", max_length=80, unique=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "catégorie"
        verbose_name_plural = "catégories"

    def __str__(self):
        return self.name


class Provider(models.Model):
    name = models.CharField("nom", max_length=120)
    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name="providers",
        verbose_name="catégorie",
    )
    city = models.CharField("ville", max_length=80)
    phone = models.CharField(
        "téléphone",
        max_length=30,
        help_text="Format international, ex : +225 07 00 00 00 00",
    )
    description = models.TextField(blank=True)
    photo = models.ImageField(upload_to="providers/", blank=True)
    # New entries stay hidden until someone approves them in the admin
    is_approved = models.BooleanField("validé", default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "prestataire"
        verbose_name_plural = "prestataires"

    def __str__(self):
        return f"{self.name} ({self.city})"

    @property
    def whatsapp_url(self):
        # wa.me wants digits only, country code included
        digits = "".join(c for c in self.phone if c.isdigit())
        return f"https://wa.me/{digits}"
