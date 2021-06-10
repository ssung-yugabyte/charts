#!/usr/bin/env bash

DD_AGENT_MAJOR_VERSION=7 DD_API_KEY={{ .Values.yugaware.cloud.universe_datadog_api_key }} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

usermod -a -G systemd-journal dd-agent

for check in journald sshd yugabyte; do
  mkdir -p /etc/datadog-agent/conf.d/$check.d/
done

cat <<EOF >> /etc/datadog-agent/datadog.yaml
log_level: INFO
logs_enabled: true
EOF

cat <<EOF >> /etc/datadog-agent/conf.d/journald.d/conf.yaml
logs:
  - type: journald
    service: journald
    source: journald
    exclude_units:
      - sshd.service
EOF

cat <<EOF >> /etc/datadog-agent/conf.d/sshd.d/conf.yaml
logs:
  - type: journald
    service: sshd
    source: sshd
    include_units:
      - sshd.service
EOF

echo "logs:" > /etc/datadog-agent/conf.d/yugabyte.d/conf.yaml

for process in master tserver; do
  cat <<EOF >> /etc/datadog-agent/conf.d/yugabyte.d/conf.yaml
  - type: file
    log_processing_rules:
      - type: multi_line
        name: multi_line
        pattern: ^[IWEF][0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}\.
    path: /mnt/d0/$process/logs/yb-$process.INFO
    service: yb-$process
    source: yugabyte
    sourcecategory: database
    start_position: beginning
EOF
done

for check in journald sshd yugabyte; do
  chown -R dd-agent:dd-agent /etc/datadog-agent/conf.d/$check.d
done
