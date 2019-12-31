# MariaDB master-slave replication on k8s
* Under development

## Deployment
### Cluster deployment
```
$ git clone https://github.com/MochaCaffe/mariadb-kubernetes.git
$ cd mariadb-kubernetes
```
- Edit the following Base64 credentials inside secrets.yaml:
``` yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  admin_password: 
  slave_password: 
  db_username: 
  db_password:
  backup_password:
```
``` bash
$ kubectl apply -f secrets.yaml
```
- Create a backup volume to be shared between pods in order to sync data at initialization. The provisioner has to accept Read-Write-Many volumes.
```
$ kubectl create -f pvc.yaml
```
- Deploy MariaDB instances (by default: 3 replicas)
```
$ kubectl apply -f statefulset.yaml
```
The database cluster should be ready now to accept requests and replication should be operational. SQL write requests have to be sent to the current master instance.
### ProxySQL deployment
In order to uniformly send requests (writes,reads) to one entity without knowing the current state of the cluster, we can deploy ProxySQL:
```
$ kubectl apply -f proxy-deploy.yaml
```

