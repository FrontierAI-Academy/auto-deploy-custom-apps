# auto-deploy-custom-apps

## What this does  
Este repositorio proporciona un instalador sencillo + plantillas de apps para desplegar en un servidor con Docker Swarm:  
- Instalación automática mínima: Docker + Swarm + Traefik + Portainer con dominio (cliente no técnico)  
- Plantillas de stacks para desplegar fácilmente dos grupos: **Base** (Postgres + Redis) y **Apps** (RabbitMQ + MinIO + Chatwoot + n8n) vía Portainer.

## Usage  
1. Clona o accede al script de instalación:  
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/FrontierAI-Academy/auto-deploy-custom-apps/main/bootstrap-portainer.sh)"
