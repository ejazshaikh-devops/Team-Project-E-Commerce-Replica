# Copy to terraform.tfvars and fill in values
# NEVER commit terraform.tfvars to g
region             = "ap-south-1"
project            = "abhi-ejaz"
env                = "prod"
db_username        = "abhi_ejaz"
db_password        = "Asp_9020" # change this
db_name            = "abhi_ejaz_shop"
node_instance_type = "c7i-flex.large"
node_min           = 1
node_max           = 5
node_desired       = 1
