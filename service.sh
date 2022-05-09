#!/bin/bash

# Create a systemd service that autostarts & manages a docker-compose instance in the current directory

# Adapted from Uli Köhler - https://techoverflow.net
# Licensed as CC0 1.0 Universal

[ -z "$1" ] && {
    >&2 echo "No argument was supplied. Please specify a folder"
    exit 2
}

[ -d "$1" ] || {
    >&2 echo "'$1' is not a folder"
    exit 1
}

# Elevate priviliges
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi




# Check how docker compose is installed
docker_compose_cmd="$(which docker-compose)"

if [ "$?" = "1" ]; then
    if docker compose 2>/dev/null 1>&2; then
        docker_compose_cmd="$(which docker) compose"
    else
        >&2 echo "Docker compose not installed"
    fi
fi


# cd into folder
cd "$1" || {
    >&2 echo "Cannot cd into '$1'"
    exit 1
}

if ! { [ -f "docker-compose.yaml" ] || [ -f "docker-compose.yml" ]; }; then
    >&2 echo "Cannot find docker-compose.yaml or docker-compose.yml in '$1'"
    exit 1
fi


# From here no commands should fail
set -e



SERVICENAME=$(basename "$1")

service_file="/etc/systemd/system/${SERVICENAME}.service"
echo "Creating systemd service... $service_file"



# Create systemd service file
cat > "$service_file" << EOF
[Unit]
Description=$SERVICENAME
Requires=docker.service
After=docker.service

[Service]
Restart=always
User=root
Group=docker
WorkingDirectory=$(pwd)

# Shutdown container (if running) when unit is started
ExecStartPre=$docker_compose_cmd down

# Start container when unit is started
ExecStart=$docker_compose_cmd up

# Stop container when unit is stopped
ExecStop=$docker_compose_cmd down

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling & starting $SERVICENAME"

# Autostart systemd service
systemctl enable "$SERVICENAME.service"
# Start systemd service now or restart if already running
systemctl restart "$SERVICENAME.service"
