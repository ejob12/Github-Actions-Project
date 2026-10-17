cat <<'EOF' > install-maven.sh
#!/bin/bash

set -e

echo "=================================="
echo " Installing Apache Maven on Ubuntu"
echo "=================================="

# Update package lists
echo "[1/4] Updating package lists..."
sudo apt-get update

# Install Java and Maven
echo "[2/4] Installing Java and Maven..."
sudo apt-get install -y openjdk-17-jdk maven

# Verify Java
echo "[3/4] Verifying Java installation..."
java -version

# Verify Maven
echo "[4/4] Verifying Maven installation..."
mvn -version

echo "=================================="
echo " Maven installation completed!"
echo "=================================="
EOF