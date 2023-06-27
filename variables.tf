variable "vpc_cidr_range" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type = map(string)
  default = {
    "a" = "10.0.0.0/24"
    "b" = "10.0.1.0/24"
    "c" = "10.0.2.0/24"
  }
}

variable "private_subnets" {
  type = map(string)
  default = {
    "a" = "10.0.3.0/24"
    "b" = "10.0.4.0/24"
    "c" = "10.0.5.0/24"
  }
}

variable "public_ingress_cidr" {
  type        = string
  description = "The CIDR range from which inbound traffic will be allowed through the EKS cluster and node security groups. In a production system this should be 0.0.0.0/0."
}

variable "eks_version" {
  type    = string
  default = "1.23"
}

variable "ssh_key_name" {
  type        = string
  description = "The name of the SSH key for accessing the jump box, which must be already configured the Wickr AWS account"
}