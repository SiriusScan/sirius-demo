#!/bin/bash
set -e

# Log all output to file and console
exec > >(tee -a /var/log/sirius-bootstrap.log)
exec 2>&1

echo "========================================="
echo "SiriusScan Demo Bootstrap Script"
echo "Started at: $(date)"
echo "========================================="

# Update system packages
echo "📦 Updating system packages..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."

# Install basic dependencies first
apt-get install -y \
    git \
    jq \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker using official Docker repository
echo "🐳 Installing Docker from official repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
echo "🐳 Starting Docker service..."
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Verify Docker is running
echo "✅ Verifying Docker installation..."
docker --version
docker compose version

# Create directory for SiriusScan
echo "📁 Creating application directory..."
mkdir -p /opt/sirius
cd /opt/sirius

# Pre-clone go-api dependency for API build
echo "📥 Pre-cloning go-api dependency..."
cd /opt
git clone https://github.com/SiriusScan/go-api.git
cd /opt/sirius

# Clone SiriusScan repository
echo "📥 Cloning SiriusScan repository..."
echo "Repository: ${sirius_repo_url}"
echo "Branch/Tag: ${demo_branch}"

# Clone repository (works with both branches and tags)
if ! git clone --branch ${demo_branch} ${sirius_repo_url} repo; then
    echo "❌ Failed to clone branch/tag ${demo_branch}, trying to clone main and checkout tag..."
    git clone ${sirius_repo_url} repo
    cd repo
    git checkout ${demo_branch} || {
        echo "❌ Failed to checkout ${demo_branch}, using main branch"
        git checkout main
    }
else
    cd repo
fi

# Verify what we checked out
echo "✅ Repository cloned successfully"
echo "Current commit: $(git rev-parse HEAD)"
echo "Current branch/tag: $(git describe --tags --exact-match 2>/dev/null || git branch --show-current)"

# Create symlink to go-api for API build
echo "🔗 Creating symlink to go-api..."
ln -sf /opt/go-api ../go-api

# Create .env file for demo mode
echo "⚙️  Configuring demo environment..."
cat > .env << 'EOF'
# Demo Mode Configuration
DEMO_MODE=true
NEXT_PUBLIC_DEMO_MODE=true

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=demo_password_change_in_production
POSTGRES_DB=sirius
POSTGRES_HOST=sirius-postgres
POSTGRES_PORT=5432
DATABASE_URL=postgresql://postgres:demo_password_change_in_production@sirius-postgres:5432/sirius

# API
API_PORT=9001
GO_ENV=production
CORS_ALLOWED_ORIGINS=*
SIRIUS_API_URL=http://sirius-api:9001
NEXT_PUBLIC_SIRIUS_API_URL=http://${elastic_ip}:9001

# UI
NODE_ENV=production
NEXTAUTH_SECRET=demo_secret_change_in_production
NEXTAUTH_URL=http://localhost:3000
SKIP_ENV_VALIDATION=1

# Redis/Valkey
VALKEY_HOST=sirius-valkey
VALKEY_PORT=6379

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@sirius-rabbitmq:5672/

# Engine
ENGINE_MAIN_PORT=5174
GRPC_AGENT_PORT=50051
SIRIUS_API_URL=http://sirius-api:9001
API_BASE_URL=http://sirius-api:9001
AGENT_ID=sirius-engine
HOST_ID=sirius-engine
ENABLE_SCRIPTING=true

# Logging
LOG_LEVEL=info
EOF

echo "✅ Environment configuration created"

# Determine image tag from demo_branch variable
if [[ "${demo_branch}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # Version tag (e.g., v0.4.1)
    IMAGE_TAG="${demo_branch}"
elif [ "${demo_branch}" == "demo" ]; then
    # Demo branch uses latest
    IMAGE_TAG="latest"
else
    # Default to latest
    IMAGE_TAG="latest"
fi
export IMAGE_TAG
echo "📦 Using image tag: $${IMAGE_TAG}"

# Pull Docker images from registry
echo "🐳 Pulling prebuilt images from GitHub Container Registry..."
docker compose pull || echo "⚠️  Some images may need to be built (fallback)"

# Start Docker Compose stack (uses prebuilt images by default)
echo "🚀 Starting SiriusScan services..."
echo "Starting services with prebuilt images (this should take 2-5 minutes)..."
docker compose up -d

# Wait for services to be ready with health checks
echo "⏳ Waiting for services to initialize..."
echo "This may take 5-10 minutes for first-time setup..."

# Wait for database to be ready
echo "Waiting for PostgreSQL..."
timeout 120 bash -c 'until docker compose exec sirius-postgres pg_isready -U postgres; do sleep 3; done' || echo "PostgreSQL timeout"

# Wait for RabbitMQ to be ready
echo "Waiting for RabbitMQ..."
timeout 120 bash -c 'until docker compose exec sirius-rabbitmq rabbitmqctl status; do sleep 3; done' || echo "RabbitMQ timeout"

# Check all service build status
echo "📊 Checking service build status..."
echo "=== All Service Logs (last 30 lines) ==="
docker compose logs --tail=30

# Check API build status specifically
echo ""
echo "=== API Service Logs (last 50 lines) ==="
docker compose logs sirius-api | tail -50

# Check container status
echo ""
echo "=== Container Status ==="
docker compose ps -a

# Check for failed containers
FAILED_CONTAINERS=$(docker compose ps -a --format "{{.Name}}\t{{.Status}}" | grep -i "exited\|failed" || true)
if [ -n "$FAILED_CONTAINERS" ]; then
    echo "❌ Found failed containers:"
    echo "$FAILED_CONTAINERS"
    echo ""
    echo "=== Failed Container Logs ==="
    echo "$FAILED_CONTAINERS" | awk '{print $1}' | while read container; do
        echo "--- Logs for $container ---"
        docker compose logs "$container" | tail -50
    done
fi

# Wait for API to be ready
echo ""
echo "⏳ Waiting for API service..."
timeout 180 bash -c 'until curl -f http://localhost:9001/health; do sleep 5; done' || echo "API timeout - checking logs..."

# If API failed, show comprehensive logs
if ! curl -f http://localhost:9001/health 2>/dev/null; then
    echo "❌ API service failed to start. Comprehensive diagnostics..."
    echo ""
    echo "=== Disk Space ==="
    df -h
    echo ""
    echo "=== Memory Usage ==="
    free -h
    echo ""
    echo "=== Docker System Info ==="
    docker system df
    echo ""
    echo "=== All Service Logs (last 100 lines) ==="
    docker compose logs --tail=100
    echo ""
    echo "=== Container Status (detailed) ==="
    docker compose ps -a
fi

# Show running containers
echo "📊 Running containers:"
docker compose ps

# Show service health status
echo "🔍 Service health status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Create log directory for seeding
mkdir -p /var/log/sirius

echo "========================================="
echo "Bootstrap completed at: $(date)"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Wait for API health check"
echo "2. Seed demo data"
echo ""
echo "Monitor logs with:"
echo "  docker compose logs -f"
echo ""
echo "Access services:"
echo "  UI:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "  API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9001"
echo "========================================="

