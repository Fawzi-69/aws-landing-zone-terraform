# Reusable three-tier VPC:
#   public       -> internet-facing (ALB, NAT); no auto-assigned public IPs
#   private-app  -> application workloads, outbound via NAT
#   private-data -> databases/caches, fully isolated (no internet route) and
#                   fenced off with a restrictive NACL that only talks to the
#                   app tier.
# Flow logs are shipped to an encrypted CloudWatch log group, and the VPC's
# default security group is stripped of every rule.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  nat_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
  # App route tables: one per NAT when enabled, otherwise a single isolated table.
  app_rt_count = var.enable_nat_gateway ? local.nat_count : 1
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# --- Subnets ------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Hardened: no implicit public IPs — front with an ALB or attach EIPs explicitly.
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name}-public-${var.azs[count.index]}", Tier = "public" })
}

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "${var.name}-app-${var.azs[count.index]}", Tier = "private-app" })
}

resource "aws_subnet" "private_data" {
  count = length(var.private_data_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "${var.name}-data-${var.azs[count.index]}", Tier = "private-data" })
}

# --- NAT ----------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

# --- Route tables -------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = local.app_rt_count
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-app-${count.index}" })
}

resource "aws_route" "app_nat" {
  count = var.enable_nat_gateway ? local.nat_count : 0

  route_table_id         = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private_app" {
  count     = length(aws_subnet.private_app)
  subnet_id = aws_subnet.private_app[count.index].id
  # One table per AZ when using per-AZ NAT, otherwise the single shared table.
  route_table_id = aws_route_table.private_app[var.single_nat_gateway || !var.enable_nat_gateway ? 0 : count.index].id
}

# Data tier: local-only route table, deliberately no path to the internet.
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-data" })
}

resource "aws_route_table_association" "private_data" {
  count          = length(aws_subnet.private_data)
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}

# --- Data-tier NACL: only the app tier may reach it, only on data ports -------

resource "aws_network_acl" "data" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private_data[*].id
  tags       = merge(var.tags, { Name = "${var.name}-data" })
}

locals {
  # One ingress rule per (app subnet, data port). Rule numbers stay unique and
  # well below the 32766 ceiling.
  data_nacl_ingress = flatten([
    for ci, cidr in var.private_app_subnet_cidrs : [
      for pi, port in var.data_tier_ingress_ports : {
        key         = "${ci}-${pi}"
        rule_number = 100 + ci * 100 + pi
        cidr        = cidr
        port        = port
      }
    ]
  ])
}

resource "aws_network_acl_rule" "data_ingress" {
  for_each = { for r in local.data_nacl_ingress : r.key => r }

  network_acl_id = aws_network_acl.data.id
  rule_number    = each.value.rule_number
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

# Stateless NACLs need an explicit return path: ephemeral ports back to the app tier.
resource "aws_network_acl_rule" "data_egress_ephemeral" {
  count = length(var.private_app_subnet_cidrs)

  network_acl_id = aws_network_acl.data.id
  rule_number    = 100 + count.index
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.private_app_subnet_cidrs[count.index]
  from_port      = 1024
  to_port        = 65535
}

# --- VPC endpoints ------------------------------------------------------------
# Gateway endpoints (S3, DynamoDB) keep S3/DynamoDB traffic on the AWS backbone
# and, crucially, give the isolated data tier — which has no internet route — a
# path to those services. Interface endpoints do the same for control-plane APIs
# like SSM (so instances stay patchable/manageable without a NAT path).

locals {
  gateway_endpoint_route_table_ids = concat(
    aws_route_table.private_app[*].id,
    [aws_route_table.private_data.id],
  )
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_gateway_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.gateway_endpoint_route_table_ids

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_gateway_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.gateway_endpoint_route_table_ids

  tags = merge(var.tags, { Name = "${var.name}-dynamodb" })
}

resource "aws_security_group" "endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  # checkov:skip=CKV2_AWS_5:Attached to the interface VPC endpoints below via security_group_ids; checkov's graph doesn't follow the count-indexed reference.
  name_prefix = "${var.name}-vpce-"
  description = "Allows HTTPS from within the VPC to interface endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  # Stateful SG: inbound 443 is answered without an explicit egress rule, so no
  # egress is granted (default-deny outbound).

  tags = merge(var.tags, { Name = "${var.name}-vpce" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_interface_endpoints ? toset(var.interface_endpoint_services) : []

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.value}" })
}

# --- Lock down the default security group -------------------------------------

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  # No ingress/egress blocks -> all traffic denied on the default SG.
  tags = merge(var.tags, { Name = "${var.name}-default-locked" })
}

# --- Flow logs ----------------------------------------------------------------

data "aws_iam_policy_document" "flow_logs_kms" {
  # checkov:skip=CKV_AWS_109:KMS key policy resource is implicitly this key; root admin avoids lockout.
  # checkov:skip=CKV_AWS_111:Root-account admin on the key is the AWS-recommended baseline.
  # checkov:skip=CKV_AWS_356:"*" in a KMS key policy refers only to this key.
  statement {
    sid       = "EnableIamUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  description             = "Encrypts VPC flow logs for ${var.name}."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.flow_logs_kms.json
  tags                    = var.tags
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  # checkov:skip=CKV_AWS_338:Flow logs are high-volume; retention is operator-tunable via flow_logs_retention_days rather than forced to 1 year.
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = aws_kms_key.flow_logs[0].arn
  tags              = var.tags
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${var.name}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    sid     = "DeliverFlowLogs"
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    # Scoped to this VPC's log group only — no wildcard resource.
    resources = ["${aws_cloudwatch_log_group.flow_logs[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "deliver-flow-logs"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  tags            = var.tags
}
