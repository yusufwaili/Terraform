terraform {
    required_version = "value"

    cloud {
        organization = "value"
        workspaces {
            name = "value"
        }    
    }
    
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.49.0"
        }
    }
}