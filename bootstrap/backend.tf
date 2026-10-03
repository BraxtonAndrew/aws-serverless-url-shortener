terraform {
  backend "s3" {
    bucket       = "braxton-terraform-state-2026"
    key          = "url-shortener/bootstrap.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}