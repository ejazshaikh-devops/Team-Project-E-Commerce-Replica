# ── Security Group: RDS ────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Allow MariaDB from EKS nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MariaDB from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes_extra.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── RDS Parameter Group (MariaDB tuning) ───────────────────
resource "aws_db_parameter_group" "mariadb" {
  name   = "${var.project}-mariadb-params"
  family = "mariadb10.11"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }
    parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }
}

# ── RDS MariaDB Instance ────────────────────────────────────
resource "aws_db_instance" "mariadb" {
  identifier = "${var.project}-mariadb"

  engine         = "mariadb"
  engine_version = "10.11"
  instance_class = "db.t3.micro" # upgrade to db.t3.small for prod

  allocated_storage     = 20
  max_allocated_storage = 100 # auto-scales up to 100GB
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mariadb.name

  multi_az            = false # set true for production HA
  publicly_accessible = false # DB stays private, accessed via EKS
  deletion_protection = false # set true for production
  skip_final_snapshot = true  # set false for production

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = {
    Name = "${var.project}-mariadb"
  }
}
