#!/bin/bash
# 1. Update and install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo apt-get install -y docker-compose
sudo systemctl start docker
sudo systemctl enable docker

# 2. Prepare a directory for the game data (persistent storage)
mkdir -p /home/minecraftadmin/minecraft-data
chown -R 1000:1000 /home/minecraftadmin/minecraft-data 

# 3. Run the Minecraft Container
cat <<EOT > /home/minecraftadmin/docker-compose.yml
version: '3.8'
services:
  minecraft-server:
    image: itzg/minecraft-server
    container_name: minecraft-server
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      MEMORY: "${minecraft_memory}"
      TYPE: "PAPER"
    volumes:
      - /home/minecraftadmin/minecraft-data:/data
    restart: always
EOT

# 4. Start the Minecraft server
cd /home/minecraftadmin
sudo docker-compose up -d