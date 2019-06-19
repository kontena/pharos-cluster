# frozen_string_literal: true

Pharos.addon('kontena-stats') do
  prometheus_version = '2.9.2'
  node_exporter_version = '0.18.0'
  kube_state_metrics_version = '1.6.0'
  kube_rbac_proxy_version = '0.4.0'
  prom_label_proxy_version = '0.1.0'
  version "#{prometheus_version}+kontena.2"
  license 'Kontena License'
  priority 9

  default_values(
    replicas: 1,
    tolerations: [],
    retention: {
      time: '30d',
      size: '1GB'
    },
    persistence: {
      enabled: false,
      size: '5Gi'
    },
    node_exporter: {
      enabled: true
    },
    kube_state_metrics: {
      enabled: true
    },
    alert_managers: []
  )

  config_schema {
    optional(:replicas).filled(:int?)
    optional(:tolerations).each(:hash?)
    optional(:node_selector).filled(:hash?)
    optional(:retention).schema do
      required(:time).filled(:str?)
      required(:size).filled(:str?)
    end
    optional(:persistence).schema do
      required(:enabled).filled(:bool?)
      optional(:size).filled(:str?)
    end
    optional(:node_exporter).schema do
      required(:enabled).filled(:bool?)
    end
    optional(:kube_state_metrics).schema do
      required(:enabled).filled(:bool?)
    end
    optional(:alert_managers).each(:str?)
  }

  install {
    apply_resources(
      prometheus_version: prometheus_version,
      node_exporter_version: node_exporter_version,
      kube_state_metrics_version: kube_state_metrics_version,
      kube_rbac_proxy_version: kube_rbac_proxy_version,
      prom_label_proxy_version: prom_label_proxy_version
    )
  }
end
