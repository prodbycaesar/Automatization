terraform {
    required_providers {
        proxmox = {
            source = "telmate/proxmox"
            version = "3.0.1-rc3"
        }
    }
}

variable "prx_api_url" {
        type = string
}

variable "prx_api_token_id" {
        type = string
        sensitive = true
}

variable "prx_api_token_secret" {
        type =  string
        sensitive = true
}

provider "proxmox" {
    pm_api_url  = var.prx_api_url
    pm_api_token_id = var.prx_api_token_id
    pm_api_token_secret = var.prx_api_token_secret
    pm_tls_insecure = true
}
