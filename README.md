# FOPS-10 Поляков Роман
  
  
ПРОБЛЕМА: При создании LoadBalancer в k8s постоянный <pending>. Работаю с yandex cloud, terraform, ansible (действия ниже).  
```
kubectl get svc

NAME         TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
hello        LoadBalancer   10.233.5.16   <pending>     80:31605/TCP   28m
kubernetes   ClusterIP      10.233.0.1    <none>        443/TCP        39m


kubectl describe svc hello

Name:                     hello
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=hello
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.233.5.16
IPs:                      10.233.5.16
Port:                     plaintext  80/TCP
TargetPort:               80/TCP
NodePort:                 plaintext  31605/TCP
Endpoints:                10.233.110.130:80,10.233.98.130:80
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>


kubectl describe deploy hello

Name:                   hello
Namespace:              default
CreationTimestamp:      Thu, 01 Aug 2024 05:01:52 +0000
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=hello
Replicas:               2 desired | 2 updated | 2 total | 2 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=hello
  Containers:
   hello-app:
    Image:         nginx:latest
    Port:          <none>
    Host Port:     <none>
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   hello-5f5c8c5997 (2/2 replicas created)
Events:          <none>

```
  
## Манифесты  
  
```
cat hello.yaml 

apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello-app
        image: nginx:latest


cat load-balancer.yaml 

apiVersion: v1
kind: Service
metadata:
  name: hello
spec:
  type: LoadBalancer
  ports:
  - port: 80
    name: plaintext
    targetPort: 80
  # Kubernetes-метки селектора, использованные в шаблоне подов при создании объекта Deployment.
  selector:
    app: hello
```
  
## Установка k8s kubesprey  
  
```
git clone https://github.com/kubernetes-incubator/kubespray.git
cd kubespray

# Включаю helm
nano inventory/sample/group_vars/k8s_cluster/addons.yml
helm_enabled: true

pip3 install -r requirements.txt --break-system-packages
export PATH="$PATH:/home/ubuntu/.local/bin"
ansible-playbook -u 'ubuntu' -i ../hosts.ini cluster.yml -b

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
```
  
## Создаю сеть, подсеть, балансер, целевую группу для барансера:  
  
```
// Создаем сеть k8s-network
resource "yandex_vpc_network" "k8s-network" {
  name = "k8s-network"
}

// Подсеть в зоне a
resource "yandex_vpc_subnet" "k8s-private-zone-a" {
  name = "k8s-private-zone-a"
  v4_cidr_blocks = ["192.168.99.0/25"]
  zone           = "ru-central1-a"
  network_id =  yandex_vpc_network.k8s-network.id
}

// Подсеть в зоне b
resource "yandex_vpc_subnet" "k8s-private-zone-b" {
  name = "k8s-private-zone-b"
  v4_cidr_blocks = ["192.168.99.128/25"]
  zone           = "ru-central1-b"
  network_id =  yandex_vpc_network.k8s-network.id
}

resource "yandex_lb_network_load_balancer" "k8s-lb" {
  name = "k8s-lb"

  listener {
    name = "http"
    port = 80
    target_port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  listener {
    name = "https"
    port = 443
    target_port = 443
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.target-group-k8s.id}"

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/ping"
      }
    }
  }
}

resource "yandex_lb_target_group" "target-group-k8s" {
  name      = "target-group-k8s"
  region_id = "ru-central1"

  target {
    subnet_id = "${yandex_vpc_subnet.k8s-private-zone-a.id}"
    address   = "${yandex_compute_instance.k8s-worker-1.network_interface.0.ip_address}"
  }

  target {
    subnet_id = "${yandex_vpc_subnet.k8s-private-zone-b.id}"
    address   = "${yandex_compute_instance.k8s-worker-2.network_interface.0.ip_address}"
  }
}

// k8s-default-sg firewall
resource "yandex_vpc_security_group" "k8s-default-sg" {
  description = "ssh from bastion security group"
  network_id  = "${yandex_vpc_network.k8s-network.id}"

  ingress {
    protocol       = "TCP"
    description    = "rule1 description"
    v4_cidr_blocks = ["192.168.99.0/24"]
    from_port      = 0
    to_port        = 65535
  }

  # Временно для дебага
  ingress {
    protocol       = "TCP"
    description    = "rule1 description"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  egress {
      protocol       = "TCP"
      description    = "разрешить весь исходящий трафик"
      v4_cidr_blocks = ["0.0.0.0/0"]
      from_port      = 0
      to_port        = 65535
  }
}
```
  
## Создаю 3 виртуальных машины (master, worker-1, worker-2):  
  
```
// Master 1 subnet a
resource "yandex_compute_instance" "k8s-master-1" {
  name        = var.vms["names"]["master_1"]
  zone        = var.zone_a

  resources {
    cores         = var.vms["master"]["cpu"]
    memory        = var.vms["master"]["ram"]
    core_fraction = var.vms["master"]["core_fraction"]
  }

  boot_disk {
    initialize_params {
      image_id = var.vms["master"]["image"]
    }
  }

  scheduling_policy {
    preemptible = var.vms["master"]["preemptible"]
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.k8s-private-zone-a.id
    ip_address = "192.168.99.10"
    nat        = var.vms["master"]["nat"]
    security_group_ids = [yandex_vpc_security_group.k8s-default-sg.id]
  }

  metadata = {
    serial-port-enable = var.vms["meta"]["serial_port_enable"]
    ssh-keys           = "${var.vms["meta"]["username"]}:${var.ssh_root_key}"
  }
  connection {
      host        = yandex_compute_instance.k8s-master-1.network_interface[0].nat_ip_address
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file(var.ssh_root_key_path)}"
      agent       = false
      timeout     = "300s"
  }

  provisioner "file" {
    source      = var.ssh_root_key_path
    destination = "/home/ubuntu/.ssh/id_ed25519"
  }

  provisioner "file" {
    source      = "../ansible/hosts.ini"
    destination = "/home/ubuntu/hosts.ini"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 /home/ubuntu/.ssh/id_ed25519",
    ]
  }

}

// Worker 1 subnet a
resource "yandex_compute_instance" "k8s-worker-1" {
  name        = var.vms["names"]["worker_1"]
  zone        = var.zone_a

  resources {
    cores         = var.vms["worker"]["cpu"]
    memory        = var.vms["worker"]["ram"]
    core_fraction = var.vms["worker"]["core_fraction"]
  }

  boot_disk {
    initialize_params {
      image_id = var.vms["worker"]["image"]
    }
  }

  scheduling_policy {
    preemptible = var.vms["worker"]["preemptible"]
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.k8s-private-zone-a.id
    nat        = var.vms["worker"]["nat"]
    ip_address = "192.168.99.11"
    security_group_ids = [yandex_vpc_security_group.k8s-default-sg.id]
  }

  metadata = {
    serial-port-enable = var.vms["meta"]["serial_port_enable"]
    ssh-keys           = "${var.vms["meta"]["username"]}:${var.ssh_root_key}"
  }

}

// Worker 2 subnet b
resource "yandex_compute_instance" "k8s-worker-2" {
  name        = var.vms["names"]["worker_2"]
  zone        = var.zone_b

  resources {
    cores         = var.vms["worker"]["cpu"]
    memory        = var.vms["worker"]["ram"]
    core_fraction = var.vms["worker"]["core_fraction"]
  }

  boot_disk {
    initialize_params {
      image_id = var.vms["worker"]["image"]
    }
  }

  scheduling_policy {
    preemptible = var.vms["worker"]["preemptible"]
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.k8s-private-zone-b.id
    nat        = var.vms["worker"]["nat"]
    ip_address = "192.168.99.140"
    security_group_ids = [yandex_vpc_security_group.k8s-default-sg.id]
  }

  metadata = {
    serial-port-enable = var.vms["meta"]["serial_port_enable"]
    ssh-keys           = "${var.vms["meta"]["username"]}:${var.ssh_root_key}"
  }
}
```