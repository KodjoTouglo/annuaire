# Annuaire local

Petit annuaire de prestataires (couture, mécanique, coiffure...) en Django.
Sert de support pour apprendre à déployer une application conteneurisée sur
un VPS avec Docker.

Stack : Django 5.2, Gunicorn, PostgreSQL 16, Nginx, Docker Compose,
Let's Encrypt.

## Architecture

```
Internet -> Nginx du serveur (HTTPS, un bloc par étudiant)
         -> 127.0.0.1:APP_PORT
         -> conteneur proxy (nginx : fichiers statiques et médias)
         -> conteneur web (Gunicorn + Django)
         -> conteneur db (PostgreSQL, volume pgdata)
```

Trois services dans `docker-compose.yml`, trois volumes : `pgdata` pour la
base, `static` et `media` partagés entre `web` et `proxy`.

## En local

Docker Desktop (ou Docker Engine) suffit.

```bash
cp .env.example .env        # remplir SECRET_KEY et DB_PASSWORD
docker compose up -d --build
docker compose exec web python manage.py load_demo
docker compose exec web python manage.py createsuperuser
```

Le site répond sur http://localhost:8000 (ou le port mis dans `APP_PORT`).

Au démarrage, le conteneur `web` lance les migrations et `collectstatic`
(voir `docker/entrypoint.sh`).

Tests : `docker compose exec web python manage.py test`

## Déploiement : organisation

Un seul VPS (Contabo, Ubuntu 24.04) partagé par toute la classe.
Chaque étudiant a :

- son utilisateur Linux (connexion SSH par clé),
- son propre Docker en mode rootless : ses conteneurs tournent avec ses
  droits, pas ceux de root, et il ne voit pas ceux des autres,
- un port réservé (`APP_PORT`) sur 127.0.0.1,
- son adresse `https://<user>.<ip-avec-tirets>.sslip.io`.

Pas besoin de nom de domaine : [sslip.io](https://sslip.io) résout
`michel.203-0-113-10.sslip.io` vers `203.0.113.10`, ce qui suffit à Let's Encrypt
pour délivrer un vrai certificat.

## Côté formateur (une fois)

1. Se connecter en root, cloner ce dépôt, puis :

   ```bash
   CERTBOT_EMAIL=formateur@example.com ./deploy/server-setup.sh
   ```

   Le script installe Docker depuis le dépôt officiel, prépare le mode
   rootless, télécharge une seule fois les images de base et désactive le
   démon Docker système (le groupe `docker` donnerait les droits root).

2. Interdire le login root par mot de passe (`PermitRootLogin prohibit-password`
   dans `/etc/ssh/sshd_config`), après avoir vérifié que votre clé fonctionne.

3. Pour chaque étudiant, avec sa clé publique :

   ```bash
   ./deploy/add-student.sh michel /chemin/vers/michel.pub
   ```

   Le script affiche l'adresse du site et le port à transmettre à l'étudiant.

4. Après la session : `./deploy/remove-student.sh michel`.

## Côté étudiant

Remplacer `michel`, l'adresse et le port par les vôtres.

```bash
ssh michel@203.0.113.10
```

**1. Récupérer le code**

```bash
git clone https://github.com/KodjoTouglo/annuaire.git
cd annuaire
```

**2. Configurer**

```bash
cp .env.example .env
python3 -c "import secrets; print(secrets.token_urlsafe(50))"   # pour SECRET_KEY
nano .env
```

À remplir : `SECRET_KEY`, `ALLOWED_HOSTS` (votre adresse sslip.io),
`APP_PORT` (donné par le formateur), `DB_PASSWORD` (au choix).
Garder `DEBUG=0` et `HTTPS=0` pour l'instant.

**3. Construire et démarrer**

```bash
docker compose up -d --build
docker compose ps
```

**4. Préparer les données**

```bash
docker compose exec web python manage.py load_demo
docker compose exec web python manage.py createsuperuser
```

`load_demo` charge les catégories et 16 prestataires fictifs avec leur photo
(crédits dans `directory/fixtures/photos/CREDITS.md`).

Ouvrir `http://michel.203-0-113-10.sslip.io`. Le site répond en HTTP.

**5. Activer HTTPS**

```bash
sudo annuaire-https
```

Puis mettre `HTTPS=1` dans `.env` et relancer avec `docker compose up -d`.
Le cadenas apparaît, et HTTP est redirigé vers HTTPS.

**6. Vérifier**

```bash
docker compose exec web python manage.py check --deploy
```

**7. Mettre à jour après un `git push`**

```bash
./deploy/deploy.sh
```

## Dépannage

| Symptôme | Où regarder |
|----------|-------------|
| 502 Bad Gateway | `docker compose ps` puis `docker compose logs web` |
| 400 Bad Request | `ALLOWED_HOSTS` ne contient pas l'adresse utilisée |
| 403 sur le formulaire | cookies : `HTTPS=1` alors que le site est en HTTP |
| `port is already allocated` | `APP_PORT` n'est pas celui donné par le formateur |
| `Cannot connect to the Docker daemon` | se reconnecter en SSH, ou `systemctl --user start docker` |
| Erreur à l'upload d'une photo | taille > 5 Mo (Nginx) ou > 2 Mo (formulaire) |
| Certificat refusé | l'adresse sslip.io ne pointe pas vers l'IP du VPS |

## Structure

```
config/              réglages, urls, wsgi
directory/           modèles, vues, formulaires, admin, templates, tests
docker/              entrypoint et configuration du nginx du conteneur proxy
Dockerfile           image de l'application
docker-compose.yml   les trois services et leurs volumes
deploy/              scripts et modèle de configuration du serveur
```
