# frozen_string_literal: true

require 'json'

module Pharos
  module Phases
    class ConfigureEtcdChanges < Pharos::Phase
      title 'Configure etcd member changes'

      def call
        store_initial_cluster_state

        return if initial_cluster_state != 'existing' || !etcd.healthy?

        removed = remove_old_members
        sleep 10 if removed.positive? # try to be gentle
        add_new_members
      end

      def store_initial_cluster_state
        return if cluster_context['etcd-initial-cluster-state']

        state = if ssh.file('/etc/kubernetes/manifests/pharos-etcd.yaml').exist?
                  'existing'
                else
                  'new'
                end

        cluster_context['etcd-initial-cluster-state'] = state
      end

      def add_new_members
        member_list = etcd.members
        new_members = @config.etcd_hosts.reject { |h|
          member_list.find { |m|
            m['peerURLs'] == ["https://#{h.peer_address}:2380"]
          }
        }
        if new_members.size > 1
          fail "Cannot add multiple etcd peers at once"
        end
        new_members.each do |h|
          logger.info { "Adding new etcd peer https://#{h.peer_address}:2380 ..." }
          etcd.add_member(h)
        end

        new_members.size
      end

      def remove_old_members
        member_list = etcd.members
        remove_members = member_list.reject { |m|
          @config.etcd_hosts.find { |h|
            m['peerURLs'] == ["https://#{h.peer_address}:2380"]
          }
        }
        if remove_members.size / member_list.size.to_f >= 0.5
          fail "Cannot remove majority of etcd peers"
        end
        remove_members.each do |m|
          logger.info { "Removing old etcd peer #{m['peerURLs'].join(', ')} ..." }
          etcd.remove_member(m['id'])
        end

        remove_members.size
      end

      # @return [Pharos::Etcd::Client]
      def etcd
        @etcd ||= Pharos::Etcd::Client.new(ssh)
      end

      # @return [String,NilClass]
      def initial_cluster_state
        cluster_context['etcd-initial-cluster-state']
      end
    end
  end
end
