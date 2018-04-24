# frozen_string_literal: true
require 'json'

module Pharos
  module Phases
    class ConfigureEtcdChanges < Pharos::Phase
      title 'Configure etcd member changes'

      def call
        store_initial_cluster_state

        if initial_cluster_state == 'existing' && etcd.healthy?
          remove_old_members
          add_new_members
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
        if new_members.size > (member_list.size / 2.0).ceil
          fail "Cannot add majority of etcd peers"
        end
        new_members.each do |h|
          logger.info { "Adding new etcd peer #{peer_name(h)}, https://#{h.peer_address}:2380 ..." }
          etcd.add_member(h)
        end
      end

      def remove_old_members
        member_list = etcd.members
        remove_members = member_list.select { |m|
          !@config.etcd_hosts.find { |h|
            m['name'] == peer_name(h) && m['peerURLs'] == ["https://#{h.peer_address}:2380"]
          }
        }
        if remove_members.size > (member_list.size / 2.0).ceil
          fail "Cannot remove majority of etcd peers"
        end
        remove_members.each do |m|
          logger.info { "Remove old etcd peer #{m['name']}, #{m['peerURLs'].join(', ')} ..." }
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
