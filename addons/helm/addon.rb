# frozen_string_literal: true

Pharos.addon 'helm' do
  version '2.13.1'
  license 'Apache License 2.0'

  LABEL_NAME = 'helm.kontena.io/chart'

  config_schema do
    optional(:charts).each do
      schema do
        required(:name).filled(:str?)
        required(:repo).filled(:str?)
        optional(:version).filled(:str?)
        optional(:namespace).filled(:str?)
        optional(:values).filled(:str?)
        optional(:set).filled(:hash?)
      end
    end
  end

  Chart = custom_type do
    attribute :name, Pharos::Types::Strict::String
    attribute :repo, Pharos::Types::Strict::String
    attribute :version, Pharos::Types::Strict::String.optional
    attribute :namespace, Pharos::Types::Strict::String.default('default')
    attribute :values, Pharos::Types::Strict::String.optional
    attribute :set, Pharos::Types::Strict::Hash.optional

    def release_name
      @release_name ||= name.split('/').last
    end
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
    job = ensure_resource(job)
    while job&.status&.succeeded.to_i.zero? && job&.status&.failed.to_i.zero?
      sleep 1
      job = fetch_resource(job)
    end
  end

  # @param resource [K8s::Resource]
  def ensure_resource(resource)
    old = fetch_resource(resource)
    if old
      kube_client.delete_resource(old, propagationPolicy: 'Background')
      until old.nil?
        sleep 1
        old = fetch_resource(resource)
      end
    end
    kube_client.create_resource(resource)
  end

  # @param resource [K8s::Resource]
  # @return [K8s::Resource,NilClass]
  def fetch_resource(resource)
    kube_client.get_resource(resource)
  rescue K8s::Error::NotFound
    nil
  end

  # @param chart [RecursiveOpenStruct]
  # @param configmap [K8s::Resource]
  # @return [K8s::Resource]
  def build_job(chart, configmap)
    K8s::Resource.new(
      apiVersion: "batch/v1",
      kind: "Job",
      metadata: {
        name: "helm-apply-#{chart.release_name}",
        namespace: "kube-system",
        labels: {
          LABEL_NAME => chart.release_name
        }
      },
      spec: {
        backoffLimit: 100,
        template: {
          metadata: {
            labels: {
              LABEL_NAME => chart.release_name
            }
          },
          spec: {
            restartPolicy: "OnFailure",
            serviceAccountName: "tiller",
            containers: [
              {
                name: "helm",
                image: "#{cluster_config.image_repository}/pharos-helm-worker:#{self.class.version}",
                args: build_args(chart),
                env: [
                  {
                    name: "NAME",
                    value: chart.name
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
        name: "helm-apply-values-#{chart.release_name}",
        namespace: "kube-system",
        labels: {
          LABEL_NAME => chart.release_name
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
      "install", "--name", chart.release_name, chart.name
    ]
    args.concat(["--namespace", chart.namespace]) if chart.namespace
    args.concat(["--version", chart.version]) if chart.version

    args.concat(chart.set.to_h.flat_map { |key, val| ["--set", "#{key}=#{val}"] }) if chart.set

    args
  end

  # @param chart [RecursiveOpenStruct]
  # @return [String]
  def values_content(chart)
    return '' unless chart.values

    File.read(chart.values)
  end
end
