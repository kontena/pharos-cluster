# frozen_string_literal: true

Pharos.addon 'pharos-license-enforcer' do
  version '0.3.0'
  license 'Kontena License'

  enable!

  install do
    # Does now "empty" stack deploy --> prunes everything from this addon, e.g. previous versions rbac etc.
    apply_resources

    @cluster_config.master_hosts.each do |m|
      m.transport.file('/etc/kubernetes/manifests/pharos-license-enforcer.yaml').write(enforcer_pod)
    end

    post_install_message(<<~POST_INSTALL_MESSAGE)
      To assign a license to the cluster, use the #{'pharos license assign'.cyan} command.
    POST_INSTALL_MESSAGE
  end

  def enforcer_pod
    <<-POD
  apiVersion: v1
  kind: Pod
  metadata:
    name: pharos-license-enforcer
    namespace: kube-system
  spec:
    terminationGracePeriodSeconds: 30
    hostNetwork: true
    priorityClassName: system-cluster-critical
    containers:
    - name: enforcer
      image: #{cluster_config.image_repository}/pharos-license-enforcer:#{self.class.version}
      args:
        - -interval
        - 60m
        - -kube-config
        - /etc/kubeconfig
      env:
        - name: NODE
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      resources:
        limits:
          memory: 20Mi
        requests:
          cpu: 100m
          memory: 10Mi
      volumeMounts:
      - name: manifests
        mountPath: /etc/kubernetes/manifests
      - name: icebox
        mountPath: /etc/pharos/icebox
      - name: kubeconfig
        mountPath: /etc/kubeconfig
    volumes:
      - name: manifests
        hostPath:
          path: /etc/kubernetes/manifests
      - name: icebox
        hostPath:
          path: /etc/pharos/icebox
      - name: kubeconfig
        hostPath:
          path: /etc/kubernetes/admin.conf
    POD
  end
end
