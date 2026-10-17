cat <<'EOF' > install-sonarqube-latest.sh
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=========================================="
echo " Installing Latest SonarQube with Docker"
echo "=========================================="

# 1. Install Docker if it is not already available
if ! command -v docker >/dev/null 2>&1; then
    echo "[1/7] Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-v2
    sudo systemctl enable --now docker
else
    echo "[1/7] Docker is already installed."
    sudo systemctl enable --now docker
fi

# 2. Configure Linux requirements for Elasticsearch
echo "[2/7] Configuring Linux kernel parameters..."
sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072

sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null <<'SYSCTL'
vm.max_map_count=524288
fs.file-max=131072
SYSCTL

sudo sysctl --system >/dev/null

# 3. Create the installation directory
echo "[3/7] Creating installation directory..."
sudo mkdir -p /opt/sonarqube-docker
sudo chown "$USER":"$(id -gn)" /opt/sonarqube-docker
cd /opt/sonarqube-docker

# 4. Create Docker Compose configuration
echo "[4/7] Creating Docker Compose configuration..."

if [ ! -f .env ]; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    printf 'POSTGRES_PASSWORD=%s\n' "$DB_PASSWORD" > .env
    chmod 600 .env
fi

cat > compose.yaml <<'COMPOSE'
services:
  db:
    image: postgres:18
    container_name: sonarqube-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Missing POSTGRES_PASSWORD}
      POSTGRES_DB: sonarqube
    volumes:
      - postgresql_data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar -d sonarqube"]
      interval: 10s
      timeout: 5s
      retries: 10

  sonarqube:
    image: sonarqube:latest
    container_name: sonarqube
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: ${POSTGRES_PASSWORD:?Missing POSTGRES_PASSWORD}
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs

volumes:
  postgresql_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
COMPOSE

# 5. Pull the images
echo "[5/7] Downloading the latest images..."
sudo docker compose pull

# 6. Start the services
echo "[6/7] Starting PostgreSQL and SonarQube..."
sudo docker compose up -d

# 7. Display installation status
echo "[7/7] Checking installation..."
sudo docker compose ps

echo
echo "=========================================="
echo " Installation commands completed."
echo "=========================================="
echo "SonarQube URL: http://YOUR_EC2_PUBLIC_IP:9000"
echo "Default login: admin"
echo "Default password: admin"
echo
echo "Check startup logs with:"
echo "sudo docker compose -f /opt/sonarqube-docker/compose.yaml logs -f sonarqube"
echo
echo "Database password is stored in:"
echo "/opt/sonarqube-docker/.env"
echo "Keep this file private."
EOF

chmod +x install-sonarqube-latest.sh
./install-sonarqube-latest.sh