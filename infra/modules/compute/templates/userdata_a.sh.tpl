#!/bin/bash
set -euo pipefail

# Terraform substitutes these at plan time:
APP_LOG_GROUP="${app_log_group}"
INSTANCE_B_IP="${instance_b_private_ip}"

# ─── CloudWatch agent ─────────────────────────────────────────────────────────
dnf install -y amazon-cloudwatch-agent

# $${aws:InstanceId} is CW agent template syntax — bash does not expand it.
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CW_EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app.log",
            "log_group_name": "$APP_LOG_GROUP",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "InstanceId": "\$${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["*"],
        "metrics_collection_interval": 60
      }
    }
  }
}
CW_EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ─── App heartbeat: structured JSON log every minute ─────────────────────────
touch /var/log/app.log
chmod 644 /var/log/app.log

cat > /usr/local/bin/app-heartbeat.sh << 'SCRIPT_EOF'
#!/bin/bash
TOKEN=$(curl -sf --max-time 2 \
  -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "")
INSTANCE_ID=$(curl -sf --max-time 2 \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/instance-id" 2>/dev/null || echo "unknown")
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"INFO\",\"message\":\"app heartbeat\",\"instance_id\":\"$INSTANCE_ID\"}" \
  >> /var/log/app.log
SCRIPT_EOF
chmod +x /usr/local/bin/app-heartbeat.sh

cat > /etc/systemd/system/app-heartbeat.service << 'SVC_EOF'
[Unit]
Description=App heartbeat — writes structured JSON to /var/log/app.log

[Service]
Type=oneshot
ExecStart=/usr/local/bin/app-heartbeat.sh
SVC_EOF

cat > /etc/systemd/system/app-heartbeat.timer << 'TMR_EOF'
[Unit]
Description=App heartbeat timer — fires every 60 s

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
TMR_EOF

# ─── Probe Instance B: generates REJECT entries in VPC Flow Logs ──────────────
# Instance B's security group has no inbound rules, so every TCP SYN is
# rejected and logged with action=REJECT in the flow log.

cat > /usr/local/bin/probe-instance-b.sh << PROBE_EOF
#!/bin/bash
curl -sf --connect-timeout 2 --max-time 3 "http://$INSTANCE_B_IP/" > /dev/null 2>&1 || true
PROBE_EOF
chmod +x /usr/local/bin/probe-instance-b.sh

cat > /etc/systemd/system/probe-instance-b.service << 'PROBE_SVC_EOF'
[Unit]
Description=Probe Instance B — intentionally rejected; generates VPC Flow Log REJECT entries

[Service]
Type=oneshot
ExecStart=/usr/local/bin/probe-instance-b.sh
PROBE_SVC_EOF

cat > /etc/systemd/system/probe-instance-b.timer << 'PROBE_TMR_EOF'
[Unit]
Description=Probe Instance B timer

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
PROBE_TMR_EOF

systemctl daemon-reload
systemctl enable --now app-heartbeat.timer
systemctl enable --now probe-instance-b.timer
