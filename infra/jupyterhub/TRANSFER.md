# One-Time GCS → EFS Shared Data Transfer

Copies data from a GCS bucket into the `efs-persist-shared` volume (`/home/shared`),
which is mounted read-write on every JupyterHub user server.

## 1. Apply the loader pod

```yaml
# gcs-loader.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gcs-loader
  namespace: jupyterhub
spec:
  restartPolicy: Never
  containers:
  - name: loader
    image: google/cloud-sdk:slim
    command: ["sleep", "3600"]
    volumeMounts:
    - name: shared
      mountPath: /home/shared
  volumes:
  - name: shared
    persistentVolumeClaim:
      claimName: efs-persist-shared
```

```bash
kubectl apply -f gcs-loader.yaml
```

## 2. Exec in and authenticate

```bash
kubectl exec -it -n jupyterhub gcs-loader -- bash

# Inside the pod — prints a URL to open in your browser
gcloud auth login
```

Open the printed URL in your local browser and paste the auth code back into the terminal.

## 3. Copy data

```bash
gsutil -m cp -r gs://YOUR_BUCKET/data /home/shared/
```

The `-m` flag enables parallel transfers. Replace `gs://YOUR_BUCKET/data` with your actual bucket path.

## 4. Clean up

```bash
exit
kubectl delete pod -n jupyterhub gcs-loader
```

## Notes

- `/home/shared` is mounted on every user server at spawn time — no restart needed.
- GCP egress fees apply (~$0.08/GB) since data crosses from GCP to AWS.
- The pod has a 1-hour sleep window (`sleep 3600`). If the transfer takes longer, increase that value before applying.
