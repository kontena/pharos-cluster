# frozen_string_literal: true

module Gem
  autoload :Package, 'rubygems/package'
end

autoload :Zlib, 'zlib'

module Pharos
  module Phases
    class StoreAddonFiles < Pharos::Phase
      require 'rubygems/package'
      title "Store addon files"

      def call
        secret = resource
        logger.info { "Storing addons.tar.gz as pharos-addon-files secret ..." }
        ensure_resource(secret)
      end

      private

      def addons_tar_gz
        logger.info { "Creating addons.tar.gz archive .." }
        buffer = StringIO.new
        Zlib::GzipWriter.wrap(buffer) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            @config.addon_file_paths.map do |relative_path, real_path|
              tar.add_file_simple(
                File.join('pharos-addons', relative_path),
                File.stat(real_path).mode & 0777,
                File.size(real_path)
              ) do |io|
                logger.info { "Adding #{real_path} as addons.tar.gz:#{relative_path}" }
                io.write(File.read(real_path))
              end
            end
          end
        end
        logger.debug { "Archive size: #{buffer.size} byges" }
        buffer.string
      end

      def resource
        K8s::Resource.new(
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: { name: 'pharos-addon-files', namespace: 'kube-system' },
          type: 'Opaque',
          data: {
            "addons.tar.gz" => Base64.encode64(addons_tar_gz)
          }
        )
      end

      def ensure_resource(resource)
        kube_client.update_resource(resource)
      rescue K8s::Error::NotFound
        kube_client.create_resource(resource)
      end
    end
  end
end

