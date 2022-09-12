---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
  labels:
    k8s-app: siterm-agent-nrp-01.nrp-nautilus.io
  name: siterm-agent-nrp-01.nrp-nautilus.io
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: siterm-agent-nrp-01.nrp-nautilus.io
  strategy:
    type: Recreate
  template:
    metadata:
      annotations:
      labels:
        k8s-app: siterm-agent-nrp-01.nrp-nautilus.io
    spec:
      hostNetwork: true
      terminationGracePeriodSeconds: 30
      containers:
      - image: sdnsense/site-agent-sense:dev
        imagePullPolicy: "Always"
        name: siterm-agent
        resources: {}
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
        volumeMounts:
        - mountPath: /etc/dtnrm.yaml
          name: sitermagent
          subPath: sense-siterm-agent.yaml
        - mountPath: /etc/grid-security/hostcert.pem
          name: agent-hostcert
          readOnly: true
          subPath: hostcert.pem
        - mountPath: /etc/grid-security/hostkey.pem
          name: agent-hostkey
          readOnly: true
          subPath: hostkey.pem
        - mountPath: /etc/iproute2/rt_tables
          name: etc-iproute2
          readOnly: true
      nodeSelector:
          kubernetes.io/hostname: nrp-01.nrp-nautilus.io
      restartPolicy: Always
      serviceAccountName: ""
      volumes:
      - configMap:
          defaultMode: 420
          items:
          - key: sense-siterm-agent
            path: sense-siterm-agent.yaml
          name: sense-agent-nrp-01.nrp-nautilus.io
        name: sitermagent
      - name: agent-hostcert
        secret:
          secretName: sense-agent-nrp-01.nrp-nautilus.io
          items:
          - key: agent-hostcert
            path: hostcert.pem
          defaultMode: 0644
      - name: agent-hostkey
        secret:
          secretName: sense-agent-nrp-01.nrp-nautilus.io
          items:
          - key: agent-hostkey
            path: hostkey.pem
          defaultMode: 0644
      - name: etc-iproute2
        hostPath:
          path: /etc/iproute2/rt_tables
status: {}
