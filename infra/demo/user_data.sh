#!/bin/bash
set -e

exec > >(tee -a /var/log/sirius-bootstrap.log)
exec 2>&1

echo "========================================="
echo "SiriusScan Demo Bootstrap Script"
echo "Started at: $(date)"
echo "========================================="

# ── System packages ──────────────────────────────────────────────────────────
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

apt-get install -y \
    git \
    jq \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    openssl

# ── Docker ───────────────────────────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

docker --version
docker compose version

# ── Clone only the sirius-demo repo (for compose file + fixtures) ────────────
mkdir -p /opt/sirius
cd /opt/sirius

git clone --depth 1 https://github.com/SiriusScan/sirius-demo.git demo
cd /opt/sirius/demo

# ── Generate secrets ─────────────────────────────────────────────────────────
GENERATED_API_KEY=$(openssl rand -hex 32)
GENERATED_NEXTAUTH_SECRET=$(openssl rand -hex 32)
GENERATED_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)
GENERATED_PG_PASSWORD=$(openssl rand -hex 16)

# ── Write .env ───────────────────────────────────────────────────────────────
cat > .env << ENVEOF
# Auto-generated demo secrets — $(date -u +%Y-%m-%dT%H:%M:%SZ)
DEMO_MODE=true
NEXT_PUBLIC_DEMO_MODE=true

# Secrets
POSTGRES_PASSWORD=$GENERATED_PG_PASSWORD
NEXTAUTH_SECRET=$GENERATED_NEXTAUTH_SECRET
INITIAL_ADMIN_PASSWORD=$GENERATED_ADMIN_PASSWORD
SIRIUS_API_KEY=$GENERATED_API_KEY

# Database
POSTGRES_USER=postgres
POSTGRES_DB=sirius
DATABASE_URL=postgresql://postgres:$GENERATED_PG_PASSWORD@sirius-postgres:5432/sirius

# Public-facing URL (uses Elastic IP)
NEXT_PUBLIC_SIRIUS_API_URL=http://${elastic_ip}:9001
NEXTAUTH_URL=http://${elastic_ip}:3000

# Image tag
IMAGE_TAG=${image_tag}
ENVEOF

echo "Secrets generated and written to .env"

# ── Pull images from GHCR ───────────────────────────────────────────────────
echo "Pulling images from GHCR (tag: ${image_tag})..."
docker compose -f docker-compose.demo.yml pull

# ── Start services ───────────────────────────────────────────────────────────
echo "Starting SiriusScan services..."
docker compose -f docker-compose.demo.yml up -d

# ── Wait for health ──────────────────────────────────────────────────────────
echo "Waiting for services to initialize..."

echo "Waiting for PostgreSQL..."
timeout 120 bash -c 'until docker inspect --format="{{.State.Health.Status}}" sirius-postgres 2>/dev/null | grep -q healthy; do sleep 3; done' \
  || echo "PostgreSQL health timeout"

echo "Waiting for RabbitMQ..."
timeout 120 bash -c 'until docker inspect --format="{{.State.Health.Status}}" sirius-rabbitmq 2>/dev/null | grep -q healthy; do sleep 3; done' \
  || echo "RabbitMQ health timeout"

echo "Waiting for API..."
timeout 180 bash -c 'until curl -sf http://localhost:9001/health > /dev/null; do sleep 5; done' \
  || echo "API health timeout"

# ── Diagnostics ──────────────────────────────────────────────────────────────
echo "=== Container Status ==="
docker compose -f docker-compose.demo.yml ps -a

FAILED=$(docker compose -f docker-compose.demo.yml ps -a --format "{{.Name}}\t{{.Status}}" | grep -i "exited\|failed" || true)
if [ -n "$FAILED" ]; then
    echo "Failed containers:"
    echo "$FAILED"
    echo "$FAILED" | awk '{print $1}' | while read c; do
        echo "--- Logs for $c ---"
        docker compose -f docker-compose.demo.yml logs "$c" --tail=50
    done
fi

mkdir -p /var/log/sirius

echo "========================================="
echo "Bootstrap completed at: $(date)"
echo "========================================="
echo ""
echo "Access:"
echo "  UI:  http://${elastic_ip}:3000"
echo "  API: http://${elastic_ip}:9001"
echo ""
echo "API Key (for seeding / authenticated requests):"
echo "  $GENERATED_API_KEY"
echo "========================================="
