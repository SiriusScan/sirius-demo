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
apt-get install -y \
    docker.io \
    docker-compose-plugin \
    git \
    jq \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

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

# Clone SiriusScan repository
echo "📥 Cloning SiriusScan repository..."
echo "Repository: ${sirius_repo_url}"
echo "Branch: ${demo_branch}"

git clone --branch ${demo_branch} ${sirius_repo_url} repo
cd repo

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

# API
API_PORT=9001
GO_ENV=production

# UI
NODE_ENV=production
NEXTAUTH_SECRET=demo_secret_change_in_production
NEXTAUTH_URL=http://localhost:3000

# Redis/Valkey
VALKEY_HOST=sirius-valkey
VALKEY_PORT=6379

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@sirius-rabbitmq:5672/

# Engine
ENGINE_MAIN_PORT=5174
GRPC_AGENT_PORT=50051

# Logging
LOG_LEVEL=info
EOF

echo "✅ Environment configuration created"

# Pull Docker images (to avoid timeout during compose up)
echo "🐳 Pulling Docker images..."
docker compose pull || echo "⚠️  Some images may need to build"

# Start Docker Compose stack
echo "🚀 Starting SiriusScan services..."
docker compose up -d

# Wait for containers to start
echo "⏳ Waiting for containers to initialize..."
sleep 10

# Show running containers
echo "📊 Running containers:"
docker compose ps

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

