#!/bin/bash
set -e

# Default variables
EMAIL=""
DOMAINS=()
CERTBOT_CONF_DIR="./certbot/conf"
CERTBOT_WWW_DIR="./certbot/www"
NGINX_SERVICE_NAME="nginx"
IS_STAGING="false"

# Usage help message
usage() {
    echo "Usage: $0 -d \"domain1.com domain2.com\" -e \"email@example.com\" [options]"
    echo ""
    echo "Required:"
    echo "  -d, --domains      Space-separated list of domains (e.g., \"api.mindev.ai\")"
    echo "  -e, --email        Email address for Let's Encrypt notifications"
    echo ""
    echo "Options:"
    echo "  --conf-dir         Certbot config directory (default: $CERTBOT_CONF_DIR)"
    echo "  --www-dir          Certbot webroot directory (default: $CERTBOT_WWW_DIR)"
    echo "  --nginx-service    Docker Compose Nginx service name (default: $NGINX_SERVICE_NAME)"
    echo "  --staging          Enable Let's Encrypt staging environment (values: true/false, default: false)"
    exit 1
}

# Parse named parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domains)
            # Read space-separated domains into an array
            IFS=' ' read -r -a DOMAINS <<< "$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        --conf-dir)
            CERTBOT_CONF_DIR="$2"
            shift 2
            ;;
        --www-dir)
            CERTBOT_WWW_DIR="$2"
            shift 2
            ;;
        --nginx-service)
            NGINX_SERVICE_NAME="$2"
            shift 2
            ;;
        --staging)
            IS_STAGING="true"
            shift 1
            ;;
        *)
            usage
            ;;
    esac
done

# Validate required variables
if [[ ${#DOMAINS[@]} -eq 0 ]] || [[ -z "$EMAIL" ]]; then
    echo -e "❌ Error: Both --domains (-d) and --email (-e) parameters are required. \n"
    usage
fi

# Extract primary domain for directory structure mapping
PRIMARY_DOMAIN="${DOMAINS[0]}"

# Display configuration
echo -e "🔧 SSL Configuration: \nEmail: $EMAIL\nDomains: ${DOMAINS[*]}\nCert Dir: $CERTBOT_CONF_DIR\nWWW Dir: $CERTBOT_WWW_DIR"
echo -e "Nginx Service: $NGINX_SERVICE_NAME\nStaging: $IS_STAGING\n"

# 1. Ask for confirmation before wiping everything
echo "⚠️ WARNING: This will completely wipe existing certificates in $CERTBOT_CONF_DIR and start from scratch."
echo "Target Domains: ${DOMAINS[*]}"
read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Initialization aborted."
    exit 0
fi

# 2. Stop running containers and clear old data
echo "Stopping existing containers and wiping old certs..."
docker compose down
rm -strict -rf "$CERTBOT_CONF_DIR"/* 2>/dev/null || true
rm -strict -rf "$CERTBOT_WWW_DIR"/* 2>/dev/null || true

# 3. Create dummy certificates so Nginx doesn't crash on startup
echo "Creating dummy certificates for ${PRIMARY_DOMAIN}..."
mkdir -p "$CERTBOT_CONF_DIR/live/${PRIMARY_DOMAIN}"

# Generate a self-signed key valid for 1 day
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout "$CERTBOT_CONF_DIR/live/${PRIMARY_DOMAIN}/privkey.pem" \
  -out "$CERTBOT_CONF_DIR/live/${PRIMARY_DOMAIN}/fullchain.pem" \
  -subj "/CN=${PRIMARY_DOMAIN}"

# 4. Start Nginx with the dummy certificates
echo "Starting Nginx (${NGINX_SERVICE_NAME}) in the background..."
docker compose up -d "$NGINX_SERVICE_NAME"

# Wait a brief moment to ensure containers and health checks clear up
echo "Waiting for services to settle..."
sleep 5

# 5. Delete the dummy certificate files right before requesting real ones
echo "Removing dummy certificates to prepare for Let's Encrypt..."
rm -f "$CERTBOT_CONF_DIR/live/${PRIMARY_DOMAIN}/privkey.pem"
rm -f "$CERTBOT_CONF_DIR/live/${PRIMARY_DOMAIN}/fullchain.pem"

# 6. Run Certbot to request production certificates
echo "Requesting official Let's Encrypt certificates (Staging: ${IS_STAGING})..."

STAGING_FLAG=""
if [ "$IS_STAGING" = "true" ]; then
    STAGING_FLAG="--staging"
fi

docker compose run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  --email "$EMAIL" \
  $STAGING_FLAG \
  $(printf -- "-d %s " "${DOMAINS[@]}") \
  --agree-tos \
  --non-interactive \
  --force-renewal

# 7. Reload Nginx to read the actual production certificates
echo "Reloading Nginx with production certificates..."
docker compose exec "$NGINX_SERVICE_NAME" nginx -s reload

echo "✅ Success! SSL certificates are active for ${DOMAINS[*]}."
