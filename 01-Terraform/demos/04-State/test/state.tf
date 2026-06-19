terraform {
  backend "s3" {
    # Troque pelo nome do SEU bucket (criado no setup). Nome de bucket S3 nao
    # pode ter espacos nem maiusculas — use algo como base-config-<SEU-RM>.
    bucket = "base-config-SEU-RM"
    key    = "demo-state/terraform.tfstate"
    region = "us-east-1"

    # use_lockfile (Terraform 1.10+): trava o estado usando um objeto .tflock
    # no proprio S3, sem precisar de uma tabela DynamoDB separada. Impede que
    # dois 'apply' simultaneos corrompam o estado — exatamente a dor da Vortex.
    use_lockfile = true
  }
}
