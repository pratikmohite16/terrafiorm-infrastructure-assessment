#!/bin/bash
set -euo pipefail
yum update -y
amazon-linux-extras install nginx1 -y
# Install Grafana OSS
cat >/etc/yum.repos.d/grafana.repo <<'R'
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
R
yum install -y grafana
systemctl enable grafana-server
systemctl start grafana-server

# (optional) configure CloudWatch data source via provisioning later or manual UI
