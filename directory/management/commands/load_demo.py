from pathlib import Path

from django.core.files import File
from django.core.management import call_command
from django.core.management.base import BaseCommand

from directory.models import Category, Provider

PHOTOS = Path(__file__).resolve().parents[2] / "fixtures" / "photos"

# name, category, city, phone, photo, description
DEMO = [
    ("Atelier Awa Couture", "Couture", "Abidjan", "+225 07 00 00 00 01", "couture-awa",
     "Robes, pagnes et tenues de cérémonie sur mesure. Retouches rapides."),
    ("Couture Fatou", "Couture", "Dakar", "+221 77 000 00 02", "couture-fatou",
     "Confection homme et femme, broderie traditionnelle."),
    ("Salon Mariam", "Coiffure et beauté", "Abidjan", "+225 05 00 00 00 04", "coiffure-mariam",
     "Tresses, tissages et soins capillaires."),
    ("Beauté Ndeye", "Coiffure et beauté", "Dakar", "+221 76 000 00 05", "beaute-ndeye",
     "Maquillage, manucure et coiffure à domicile."),
    ("Garage Kofi", "Mécanique", "Bouaké", "+225 01 00 00 00 06", "garage-kofi",
     "Vidange, freins, diagnostic électronique."),
    ("Auto Service Issa", "Mécanique", "Ouagadougou", "+226 70 00 00 07", "auto-issa",
     "Réparation moteur et boîte de vitesses, toutes marques."),
    ("Élec Pro Yao", "Électricité", "Abidjan", "+225 07 00 00 00 08", "elec-yao",
     "Installation, dépannage et mise aux normes."),
    ("Lumière Cotonou", "Électricité", "Cotonou", "+229 01 00 00 00 09", "lumiere-cotonou",
     "Câblage de maisons et panneaux solaires."),
    ("Plomberie Koffi", "Plomberie", "Lomé", "+228 91 00 00 10", "plomberie-koffi",
     "Fuites, sanitaires et forage de puits."),
    ("Eau Service Abdou", "Plomberie", "Ouagadougou", "+226 71 00 00 11", "eau-abdou",
     "Installation de citernes et réparation de pompes."),
    ("Chez Tantie Rose", "Restauration", "Abidjan", "+225 05 00 00 00 12", "tantie-rose",
     "Grillades, alloco et plats du jour."),
    ("Maquis du Port", "Restauration", "Cotonou", "+229 02 00 00 00 13", "maquis-port",
     "Poisson braisé et plats locaux, livraison possible."),
    ("Dépannage PC Brice", "Informatique et téléphonie", "Abidjan", "+225 01 00 00 00 14", "depannage-brice",
     "Réparation d'ordinateurs et de téléphones, installation de logiciels."),
    ("Connect Dakar", "Informatique et téléphonie", "Dakar", "+221 78 000 00 15", "connect-dakar",
     "Coques, écrans, batteries et accessoires."),
    ("Menuiserie Tchalla", "Menuiserie", "Bouaké", "+225 07 00 00 00 16", "menuiserie-tchalla",
     "Portes, fenêtres et mobilier en bois sur commande."),
    ("Atelier Bois Lomé", "Menuiserie", "Lomé", "+228 90 00 00 03", "bois-lome",
     "Meubles sur mesure et réparation de charpentes."),
]


class Command(BaseCommand):
    help = "Replace all providers with demo data (fictitious names and phone numbers)."

    def handle(self, *args, **options):
        call_command("loaddata", "categories", verbosity=0)
        categories = {c.name: c for c in Category.objects.all()}

        Provider.objects.all().delete()
        for name, category, city, phone, photo, description in DEMO:
            provider = Provider(
                name=name,
                category=categories[category],
                city=city,
                phone=phone,
                description=description,
                is_approved=True,
            )
            with open(PHOTOS / f"{photo}.jpg", "rb") as f:
                provider.photo.save(f"{photo}.jpg", File(f), save=False)
            provider.save()

        # One pending entry to show moderation in the admin
        Provider.objects.create(
            name="Tailleur Bakary",
            category=categories["Couture"],
            city="Dakar",
            phone="+221 77 000 00 17",
            description="Proposition en attente de validation.",
        )

        self.stdout.write(self.style.SUCCESS(f"{len(DEMO)} providers loaded, 1 pending"))
