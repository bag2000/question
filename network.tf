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