// ************************************* ОБЩИЕ *************************************
// Токен
variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

// Cloud id
variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

// folder id
variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

// Zone a
variable "zone_a" {
  type        = string
  default     = "ru-central1-a"
  description = "zone"
}
// Zone b
variable "zone_b" {
  type        = string
  default     = "ru-central1-b"
  description = "zone"
}

// Ssh root key
variable "ssh_root_key" {
  type        = string
  description = "ssh-keygen -t ed25519"
}

// Ssh root key path
variable "ssh_root_key_path" {
  type        = string
  description = "ssh-keygen -t ed25519"
}

variable "private_egress_gw_name" {
  type        = string
  default     = "private-eg-gw"
  description = "Gateway network name"
}

// *************************************  VMS  *************************************
/*
cpu - количество ядер процессора
ram - ОЗУ в гигабайтах
core_fraction - процент от процессора
preemptible - прерываемая (1 или 0)
nat - nat (1 или 0)
image - image id операционной системы
serial_port_enable - серийная консоль (1 или 0)
username - имя пользователя для подключения
*/
variable "vms" {
    type = map(map(string))
    default = {
        bastion  = {
            cpu           = 2
            ram           = 2
            core_fraction = 20
            preemptible   = 1
            nat           = 1
            image         = "fd870suu28d40fqp8srr"
        },      
        worker  = {
            cpu           = 2
            ram           = 4
            core_fraction = 20
            preemptible   = 1
            nat           = 1
            image         = "fd870suu28d40fqp8srr"
        },
        master  = {
            cpu           = 2
            ram           = 4
            core_fraction = 20
            preemptible   = 1
            nat           = 1
            image         = "fd870suu28d40fqp8srr"
        },
        meta = {
            serial_port_enable = 1
            username           = "ubuntu"
        }
        names = {
            bastion = "bastion"
            master_1 = "k8s-master-1"
            worker_1 = "k8s-worker-1"
            worker_2 = "k8s-worker-2"
        }
    }
    description = "vms specifications"
}