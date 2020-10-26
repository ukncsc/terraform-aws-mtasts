provider "aws" {
region = "eu-west-2"
}

module "mtastspolicyhosting" {
  count = length(var.domains)
  source          = "github.com/ukncsc/terraform-aws-mtasts/mta-sts-module"
  domain          = element(var.domains,count.index)
  mode            = var.policy
  delegated       = contains(var.delegated,element(var.domains,count.index))
}

output "output" {
value = join("\n",module.mtastspolicyhosting.*.output)
}
