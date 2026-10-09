# Annuaire local

Petit annuaire de prestataires (couture, mécanique, coiffure...) en Django.
Sert de support pour apprendre à déployer une application web sur un VPS.

Stack : Django 5.2, PostgreSQL, Gunicorn, Nginx, systemd, Let's Encrypt.

## En local

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # mettre DEBUG=1, laisser DB_NAME vide (SQLite)
python manage.py migrate
python manage.py loaddata categories
python manage.py createsuperuser
python manage.py runserver
```

Les prestataires proposés via le formulaire restent cachés tant qu'ils ne sont
pas validés dans l'admin (`/admin/`).

Tests : `python manage.py test`

## Déploiement : organisation

Un seul VPS (Contabo, Ubuntu 24.04) partagé par toute la classe.
Chaque étudiant a :

- son utilisateur Linux (connexion SSH par clé),
- sa base PostgreSQL,
- son service Gunicorn (`annuaire-<user>`),
- son site Nginx sur `https://<user>.<ip-avec-tirets>.sslip.io`.

Pas besoin de nom de domaine : [sslip.io](https://sslip.io) résout
`alice.203-0-113-10.sslip.io` vers `203.0.113.10`, ce qui suffit à Let's Encrypt
pour délivrer un vrai certificat.

## Côté formateur (une fois)

1. Se connecter en root, cloner ce dépôt, puis :

   ```bash
   CERTBOT_EMAIL=formateur@example.com ./deploy/server-setup.sh
   ```

2. Interdire le login root par mot de passe (`PermitRootLogin prohibit-password`
   dans `/etc/ssh/sshd_config`), après avoir vérifié que votre clé fonctionne.

3. Pour chaque étudiant, avec sa clé publique :

   ```bash
   ./deploy/add-student.sh alice /chemin/vers/alice.pub
   ```

   Le script affiche l'adresse du site et le mot de passe de la base (une seule
   fois). À transmettre à l'étudiant.

4. Après la session : `./deploy/remove-student.sh alice`.

## Côté étudiant

Remplacer `alice` et l'adresse par les vôtres.

```bash
ssh alice@203.0.113.10
```

**1. Récupérer le code**

```bash
git clone https://github.com/kodjo-touglo/annuaire.git
cd annuaire
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**2. Configurer**

```bash
cp .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(50))"   # pour SECRET_KEY
nano .env
```

À remplir : `SECRET_KEY`, `ALLOWED_HOSTS` (votre adresse sslip.io),
`DB_NAME`, `DB_USER`, `DB_PASSWORD`. Garder `DEBUG=0` et `HTTPS=0` pour l'instant.

**3. Préparer l'application**

```bash
python manage.py migrate
python manage.py loaddata categories
python manage.py collectstatic --noinput
python manage.py createsuperuser
```

**4. Démarrer**

```bash
sudo annuaire-restart
```

Ouvrir `http://alice.203-0-113-10.sslip.io`. Le site répond en HTTP.

**5. Activer HTTPS**

```bash
sudo annuaire-https
```

Puis mettre `HTTPS=1` dans `.env` et relancer avec `sudo annuaire-restart`.
Le cadenas apparaît, et HTTP est redirigé vers HTTPS.

**6. Vérifier**

```bash
python manage.py check --deploy
```

Lire chaque avertissement et décider quoi en faire.

**7. Mettre à jour après un `git push`**

```bash
./deploy/deploy.sh
```

## Dépannage

| Symptôme | Où regarder |
|----------|-------------|
| 502 Bad Gateway | `journalctl -u annuaire-alice -n 50` : Gunicorn ne tourne pas |
| 400 Bad Request | `ALLOWED_HOSTS` ne contient pas l'adresse utilisée |
| 403 sur le formulaire | cookies : `HTTPS=1` alors que le site est en HTTP |
| CSS absent | `collectstatic` oublié, ou droits sur le dossier personnel |
| Erreur à l'upload d'une photo | taille > 5 Mo (Nginx) ou > 2 Mo (formulaire) |
| Certificat refusé | l'adresse sslip.io ne pointe pas vers l'IP du VPS |

Les logs Nginx (`/var/log/nginx/error.log`) sont réservés au formateur.

## Structure

```
config/       réglages, urls, wsgi
directory/    modèles, vues, formulaires, admin, templates, tests
deploy/       scripts et modèles de configuration serveur
```
