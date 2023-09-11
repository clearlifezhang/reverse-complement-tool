# setupth.sh
#
# Setup reverse-complement-tool with nginx and gunicorn
#
# See for reference
# https://www.digitalocean.com/community/tutorials/how-to-serve-flask-applications-with-gunicorn-and-nginx-on-ubuntu-22-04
#
# ami-024e6efaf93d85776

set -e

# 1. Configure script variables
OPUSER=ubuntu
PROJ_DIR=/home/$OPUSER/reverse-complement-tool

# NOTE: Update this address with your domain
SERVER_NAME="ec2-34-229-252-123.compute-1.amazonaws.com"

sudo chmod 755 /home/$OPUSER

# 2. Requires git SSH key
cd /home/$OPUSER

# git clone git@github.com:clearlifezhang/reverse-complement-tool.git
#  -- OR --
## scp local git repo to ec2; running the following command in local machine
# scp -i "your-key-pair.pem" ~/reverse-complement-tool ubuntu@ec2-34-229-252-123.compute-1.amazonaws.com:/home/$OPUSER/

mv reverse-complement-tool reverse-complement-tool
cd $PROJ_DIR

# 3. Setup Python
sudo apt update
sudo apt install nginx -y
sudo apt install -y python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools
sudo apt install -y python3-venv

python3 -m venv takehomeenv
source takehomeenv/bin/activate
pip install wheel
pip install gunicorn flask

# 4. Open firewall
sudo ufw allow 8080


# 5. Setup gunicorn service
# 5a. Configure gunicorn.socket file
gsocket_content=$(cat <<EOF
[Unit]
Description=gunicorn qserve socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
EOF
)
gsocket_filename="/etc/systemd/system/gunicorn.socket"
echo "$gsocket_content" | sudo tee "$gsocket_filename" >/dev/null
echo "File '$gsocket_filename' created and edited with sudo."

# 5b.Configure gunicorn.service file
gunicorn_service_content=$(cat <<EOF
[Unit]
Description=Gunicorn instance to serve qserve
Requires=gunicorn.socket
After=network.target

[Service]
User=$OPUSER
Group=www-data
WorkingDirectory=$PROJ_DIR
Environment="PATH=$PROJ_DIR/takehomeenv/bin"
ExecStart=$PROJ_DIR/takehomeenv/bin/gunicorn \
        --access-logfile - \
        --workers 3 \
        --bind unix:/run/gunicorn.sock wsgi:app

[Install]
WantedBy=multi-user.target
EOF
)
gunicorn_service_filename="/etc/systemd/system/gunicorn.service"
echo "$gunicorn_service_content" | sudo tee "$gunicorn_service_filename" >/dev/null

# Launch gunicorn socket
sudo systemctl enable gunicorn.socket
sudo systemctl start gunicorn.socket
sudo systemctl status gunicorn.socket

# Restart gunicorn
curl --unix-socket /run/gunicorn.sock localhost
sudo systemctl status gunicorn
sudo systemctl daemon-reload
sudo systemctl restart gunicorn

# 6. Configure nginx service
# Configure nginx file  # Update URL with IP addresss
nginx_content=$(cat <<EOF
server {
    listen 8080;
    server_name $SERVER_NAME;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $PROJ_DIR;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF
)
nginx_filename="/etc/nginx/sites-available/reverse-complement-tool"
echo "$nginx_content" | sudo tee "$nginx_filename" > /dev/null
echo "File '$nginx_filename' created and edited with sudo."

# 7. Restart everything, verify functionality
sudo systemctl restart gunicorn
sudo systemctl daemon-reload
sudo systemctl restart gunicorn.socket gunicorn.service
sudo nginx -t && sudo systemctl restart nginx
# sudo ufw delete allow 5000
sudo ufw allow 'Nginx Full'
