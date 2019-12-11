apiVersion: v1
kind: Secret
metadata:
  name: packet-cloud-config
  namespace: kube-system
data:
  apiKey: ${api_key} # Base64 encoded API token
  projectID: ${project_id} # Base64 encoded project ID
