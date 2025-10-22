# 🚀 auto-deploy-custom-apps

## 🧠 What this does  
Este repositorio proporciona un instalador sencillo + plantillas de apps para desplegar en un servidor con Docker Swarm:

- **Instalación automática mínima:** Docker + Swarm + Traefik + Portainer con dominio (sin conocimientos técnicos).  
- **Plantillas de stacks** para desplegar fácilmente dos grupos:  
  - 🧩 **Base:** Postgres + Redis  
  - ⚙️ **Apps:** RabbitMQ + MinIO + Chatwoot + n8n (requiere que Base esté desplegado primero)

---

## 🧰 Usage  

### 1️⃣ Instalar entorno base (Bootstrap)
Ejecuta en tu VPS limpio (Ubuntu 22+):

bash -c "$(curl -fsSL https://raw.githubusercontent.com/FrontierAI-Academy/auto-deploy-custom-apps/main/bootstrap-portainer.sh)"

Durante la instalación, se te pedirá:
- **DOMAIN** → tu dominio (ej. midominio.com)
- **EMAIL** → para certificados SSL (Let's Encrypt)

Esto instalará:
- Docker + Docker Swarm  
- Traefik (con SSL automático)  
- Portainer → https://portainerapp.tu-dominio.com  
  - Usuario: admin  
  - Contraseña: GBMmWvoKPt9JKHVaPsTWwmA2vgmavYcS

---

### 2️⃣ Agregar las plantillas a Portainer  
En Portainer, entra a:

Settings → App Templates → Custom URL

y coloca esta URL:

https://raw.githubusercontent.com/FrontierAI-Academy/auto-deploy-custom-apps/main/templates.json

Guarda los cambios.  
Ahora en App Templates verás dos opciones:

- 🧩 Base — Postgres + Redis  
- ⚙️ Apps — RabbitMQ + MinIO + Chatwoot + n8n

---

### 3️⃣ Desplegar stacks

1. Primero despliega “Base”  
   Espera a que Postgres y Redis estén en estado Running.

2. Antes de desplegar “Apps”, crea las bases de datos necesarias:  
   Entra al contenedor Postgres desde Portainer → Console → Connect y ejecuta:

psql -U postgres -c "CREATE DATABASE chatwoot;"
psql -U postgres -c "CREATE DATABASE n8n_fila;"

3. Luego despliega “Apps”  
   Esto instalará RabbitMQ, MinIO, Chatwoot y n8n automáticamente con SSL.

---

### 4️⃣ Inicializar Chatwoot

Después de desplegar “Apps”, abre la consola del contenedor chatwoot_chatwoot_app y ejecuta:

bundle exec rails db:chatwoot_prepare

Esto creará las tablas internas y el usuario administrador por defecto.

---

## 🌐 Subdominios utilizados

Asegúrate de crear los registros DNS tipo A apuntando a la IP del servidor para:

portainerapp.tu-dominio.com
rabbitmqapp.tu-dominio.com
miniofrontapp.tu-dominio.com
miniobackapp.tu-dominio.com
chatwootapp.tu-dominio.com
n8napp.tu-dominio.com
n8nwebhookapp.tu-dominio.com

Traefik emitirá automáticamente los certificados SSL cuando los dominios resuelvan correctamente.

---

## ✅ Resultado final

Tu entorno quedará listo con:

| Servicio | URL | Descripción |
|-----------|-----|-------------|
| **Portainer** | https://portainerapp.tu-dominio.com | Panel principal para gestionar los stacks |
| **RabbitMQ** | https://rabbitmqapp.tu-dominio.com | Broker de mensajería |
| **MinIO Console** | https://miniofrontapp.tu-dominio.com | Interfaz de administración |
| **MinIO S3** | https://miniobackapp.tu-dominio.com | Endpoint S3 compatible |
| **Chatwoot** | https://chatwootapp.tu-dominio.com | Plataforma de atención al cliente |
| **n8n Editor** | https://n8napp.tu-dominio.com | Panel de edición de flujos |
| **n8n Webhook** | https://n8nwebhookapp.tu-dominio.com | Endpoint para webhooks externos |

---

🧩 Tips finales:
- Si los certificados SSL no se generan, revisa que los DNS ya apunten al servidor.  
- Puedes ver los logs con docker service logs -f <nombre-del-servicio>.  
- No elimines las redes externas (traefik_public, general_network, agent_network).

---

💡 Made for simple, zero-DevOps deployments by FrontierAI Academy.
