# frozen_string_literal: true

Pharos.addon 'helm' do
  version '2.12.1'
  license 'Apache License 2.0'

  config_schema do
    optional(:charts).each do
      schema do
        required(:name).filled(:str?)
        required(:repo).filled(:str?)
        optional(:version).filled(:str?)
        optional(:namespace).filled(:str?)
        optional(:values).filled(:str?)
      end
    end
  end

  Chart = custom_type do
    attribute :name, Pharos::Types::Strict::String
    attribute :repo, Pharos::Types::Strict::String
    attribute :version, Pharos::Types::Strict::String.optional
    attribute :namespace, Pharos::Types::Strict::String.default('default')
    attribute :values, Pharos::Types::Strict::String.optional
  end

  config do
    attribute :charts, Pharos::Types::Array.of(Chart)
  end

  install do
    apply_resources
    apply_charts
  end

  def apply_charts
    return unless config.charts

    config.charts.each do |chart|
      logger.info "Applying chart #{chart.name} ..."
      create_chart_job(chart)
    end
  end

  # @param chart [RecursiveOpenStruct]
  def create_chart_job(chart)
    configmap = build_configmap(chart)
    job = build_job(chart, configmap)
    ensure_resource(configmap)
    ensure_resource(job)
  end

  # @param resource [K8s::Resource]
  def ensure_resource(resource)
    old_or_error = kube_client.get_resource(resource) rescue $?
    if old_or_error.is_a?(K8s::Resource)
      kube_client.delete_resource(old_or_error, propagationPolicy: 'Background')
      while old_or_error.is_a?(K8s::Resource) do
        sleep 1
        old_or_error = kube_client.get_resource(resource) rescue $?
      end
    end
    kube_client.create_resource(resource)
  end

  # @param chart [RecursiveOpenStruct]
  # @param configmap [K8s::Resource]
  # @return [K8s::Resource]
  def build_job(chart, configmap)
    K8s::Resource.new(
      apiVersion: "batch/v1",
      kind: "Job",
      metadata: {
        name: "helm-apply-#{chart.name.split('/').last}",
        namespace: "kube-system",
        labels: {
          'helm.pharos.sh/chart': chart.name.split('/').last
        }
      },
      spec: {
        backoffLimit: 1000,
        template: {
          metadata: {
            labels: {
              'helm.pharos.sh/chart': chart.name.split('/').last
            }
          },
          spec: {
            restartPolicy: "OnFailure",
            serviceAccountName: "tiller",
            containers: [
              {
                name: "helm",
                image: "quay.io/jakolehm/helm-worker:latest",
                args: build_args(chart),
                env: [
                  {
                    name: "NAME",
                    value: chart.name.split('/').last
                  },
                  {
                    name: "VERSION",
                    value: chart.version
                  },
                  {
                    name: "REPO",
                    value: chart.repo
                  }
                ],
                volumeMounts: [
                  {
                    name: "values",
                    mountPath: "/config"
                  }
                ]
              }
            ],
            volumes: [
              {
                name: "values",
                configMap: {
                  name: configmap.metadata.name
                }
              }
            ]
          }
        }
      }
    )
  end

  # @param chart [RecursiveOpenStruct]
  # @return [K8s::Resource]
  def build_configmap(chart)
    K8s::Resource.new(
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: {
        name: "helm-apply-values-#{chart.name.split('/').last}",
        namespace: "kube-system",
        labels: {
          'helm.pharos.sh/chart': chart.name.split('/').last
        }
      },
      data: {
        "values.yaml" => values_content(chart)
      }
    )
  end

  # @param chart [RecursiveOpenStruct]
  # @return [Array<String>]
  def build_args(chart)
    args = [
      "install", "--name", chart.name.split('/').last, chart.name
    ]
    args.concat(["--namespace", chart.namespace]) if chart.namespace
    args.concat(["--version", chart.version]) if chart.version

    args
  end

  # @param chart [RecursiveOpenStruct]
  # @return [String]
  def values_content(chart)
    return '' unless chart.values

    File.read(chart.values)
  end
end
