# frozen_string_literal: true
require 'json'

module Pharos
  module Phases
    class ConfigureEtcdChanges < Pharos::Phase
      title 'Configure etcd member changes'

      def call
        store_initial_cluster_state

        if etcd.healthy?
          add_new_members if initial_cluster_state == 'existing'
        end
      end

      def store_initial_cluster_state
        return if cluster_context['etcd-initial-cluster-state']

        if @ssh.file('/etc/kubernetes/manifests/pharos-etcd.yaml').exist?
          cluster_context['etcd-initial-cluster-state'] = 'existing'
        else
          cluster_context['etcd-initial-cluster-state'] = 'new'
        end
      end

      def add_new_members
        member_list = etcd.members
        new_members = @config.etcd_hosts.select { |h|
          !member_list.find { |m|
            m['name'] == peer_name(h) && m['peerURLs'] == ["https://#{h.peer_address}:2380"]
          }
        }
        new_members.each do |h|
          logger.info { "Adding new etcd peer #{peer_name(h)}, https://#{h.peer_address}:2380 ..." }
          etcd.add_member(h)
        end
      end

      # @return [Pharos::Etcd::Client]
      def etcd
        @etcd ||= Pharos::Etcd::Client.new(@ssh)
      end

      # @param peer [Pharos::Configuration::Host]
      # @return [String]
      def peer_name(peer)
        peer_index = @config.etcd_hosts.find_index { |h| h == peer }
        "etcd#{peer_index + 1}"
      end

      # @return [String,NilClass]
      def initial_cluster_state
        cluster_context['etcd-initial-cluster-state']
      end
    end
  end
end
