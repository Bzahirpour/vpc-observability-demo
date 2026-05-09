#!/bin/bash
set -euo pipefail
# Instance B: isolated demo target.
# nginx serves on port 80 so that once the SG inbound rule is added,
# curl from Instance A gets a real 200 response instead of timing out.
dnf install -y nginx
systemctl enable --now nginx
