#!/bin/bash
set -e

# Configuration
DOMAINS=("test.com")
EMAIL="kjknfnfi@gmail.com"
CERTBOT_CONF_DIR="./certbot/conf"
CERTBOT_WWW_DIR="./certbot/www"
NGINX_SERVICE_NAME="nginx"
IS_STAGING="true"


# 1. Ask for confirmation before wiping everything
echo "⚠️ WARNING: This will completely wipe existing certificates in $CERTBOT_CONF_DIR and start from scratch."
read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Initialization aborted."
    exit 0
fi

# 2. Stop running containers and clear old data
echo "Stopping existing containers and wiping old certs..."
docker compose down
rm -rf "$CERTBOT_CONF_DIR"/*
rm -rf "$CERTBOT_WWW_DIR"/*

# 3. Create dummy certificates so Nginx doesn't crash on startup
echo "Creating dummy certificates for ${DOMAINS[0]}..."
mkdir -p "$CERTBOT_CONF_DIR/live/${DOMAINS[0]}"

# Generate a self-signed key valid for 1 day
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout "$CERTBOT_CONF_DIR/live/${DOMAINS[0]}/privkey.pem" \
  -out "$CERTBOT_CONF_DIR/live/${DOMAINS[0]}/fullchain.pem" \
  -subj "/CN=${DOMAINS[0]}"

# 4. Start Nginx with the dummy certificates
echo "Starting Nginx in the background..."
docker compose up -d "$NGINX_SERVICE_NAME"

# Wait a brief moment to ensure containers and health checks clear up
echo "Waiting for services to settle..."
sleep 5

# 5. Delete the dummy certificate files right before requesting real ones
# (Certbot requires the directory structure to exist, but files must be overwritten)
echo "Removing dummy certificates to prepare for Let's Encrypt..."
rm -f "$CERTBOT_CONF_DIR/live/${DOMAINS[0]}/privkey.pem"
rm -f "$CERTBOT_CONF_DIR/live/${DOMAINS[0]}/fullchain.pem"

# 6. Run Certbot to request production certificates
echo "Requesting official Let's Encrypt certificates..."
docker compose run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  --email "$EMAIL" \
  $([ "$IS_STAGING" = "true" ] && echo "--staging") \
  $(printf -- "-d %s " "${DOMAINS[@]}") \
  --agree-tos \
  --non-interactive \
  --force-renewal

# 7. Reload Nginx to read the actual production certificates
echo "Reloading Nginx with production certificates..."
docker compose exec "$NGINX_SERVICE_NAME" nginx -s reload

echo "✅ Success! Real SSL certificates are active for ${DOMAINS[*]}."
