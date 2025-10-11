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
echo "Branch: ${demo_branch}"

git clone --branch ${demo_branch} ${sirius_repo_url} repo
cd repo

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
SIRIUS_API_URL=http://sirius-api:9001
NEXT_PUBLIC_SIRIUS_API_URL=http://localhost:9001

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

# Pull Docker images (to avoid timeout during compose up)
echo "🐳 Pulling Docker images..."
docker compose pull || echo "⚠️  Some images may need to build"

# Start Docker Compose stack
echo "🚀 Starting SiriusScan services..."
echo "Building and starting services (this may take 5-10 minutes)..."
docker compose up -d --build

# Wait for services to be ready with health checks
echo "⏳ Waiting for services to initialize..."
echo "This may take 5-10 minutes for first-time setup..."

# Wait for database to be ready
echo "Waiting for PostgreSQL..."
timeout 120 bash -c 'until docker compose exec sirius-postgres pg_isready -U postgres; do sleep 3; done' || echo "PostgreSQL timeout"

# Wait for RabbitMQ to be ready
echo "Waiting for RabbitMQ..."
timeout 120 bash -c 'until docker compose exec sirius-rabbitmq rabbitmqctl status; do sleep 3; done' || echo "RabbitMQ timeout"

# Check API build status
echo "Checking API service build status..."
docker compose logs sirius-api | tail -20

# Wait for API to be ready
echo "Waiting for API service..."
timeout 180 bash -c 'until curl -f http://localhost:9001/health; do sleep 5; done' || echo "API timeout - checking logs..."

# If API failed, show logs
if ! curl -f http://localhost:9001/health 2>/dev/null; then
    echo "❌ API service failed to start. Checking logs..."
    docker compose logs sirius-api | tail -50
    echo "Checking all service status..."
    docker compose ps
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

