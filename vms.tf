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