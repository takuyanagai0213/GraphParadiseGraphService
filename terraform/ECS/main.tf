terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "image" {}

# Configure the AWS Provider
provider "aws" {
  region     = "us-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
# IAM
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
# VPC
# https://www.terraform.io/docs/providers/aws/r/vpc.html
resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "go-vpc"
  }
}
resource "aws_subnet" "public_1c" {
  vpc_id = aws_vpc.main.id

  availability_zone = "us-west-2a"

  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "go-public-subnet-1c"
  }
}
resource "aws_subnet" "public_1a" {
  vpc_id = aws_vpc.main.id

  availability_zone = "us-west-2c"

  cidr_block = "192.168.2.0/24"

  tags = {
    Name = "go-public-subnet-1c"
  }
}
# Internet Gateway
# https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "go-gw"
  }
}

# Route Table
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "go-public-rt"
  }
}

# Route
# https://www.terraform.io/docs/providers/aws/r/route.html
resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.main.id
}

# Association
# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_iam_role_policy_attachment" "amazon_ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# Task Definition
# https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html
resource "aws_ecs_task_definition" "main" {
  family = "service"

  # データプレーンの選択
  requires_compatibilities = ["FARGATE"]

  # ECSタスクが使用可能なリソースの上限
  # タスク内のコンテナはこの上限内に使用するリソースを収める必要があり、メモリが上限に達した場合OOM Killer にタスクがキルされる
  cpu    = "256"
  memory = "1024"

  # ECSタスクのネットワークドライバ
  network_mode       = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  # 起動するコンテナの定義
  container_definitions = <<JSON
  [
    {
      "name": "web",
      "image": "${var.image}",
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ]
  JSON
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "MyEcsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
# ECS Cluster
# https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html
resource "aws_ecs_cluster" "main" {
  name = "test_cluster"
}
# ELB Target Group
# https://www.terraform.io/docs/providers/aws/r/lb_target_group.html
resource "aws_lb_target_group" "main" {
  name = "handson"

  # ターゲットグループを作成するVPC
  vpc_id = aws_vpc.main.id

  # ALBからECSタスクのコンテナへトラフィックを振り分ける設定
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  # コンテナへの死活監視設定
  health_check {
    port = 80
    path = "/"
  }
}
# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "alb" {
  name        = "app-alb"
  description = "app alb"
  vpc_id      = aws_vpc.main.id

  # セキュリティグループ内のリソースからインターネットへのアクセスを許可する
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-alb"
  }
}
# ALB
# https://www.terraform.io/docs/providers/aws/d/lb.html
resource "aws_lb" "main" {
  load_balancer_type = "application"
  name               = "app-lb"

  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.public_1c.id}","${aws_subnet.public_1a.id}"]
}
# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "ecs" {
  name        = "go-ecs"
  description = "go-app ecs"

  # セキュリティグループを配置するVPC
  vpc_id = aws_vpc.main.id

  # セキュリティグループ内のリソースからインターネットへのアクセス許可設定
  # 今回の場合DockerHubへのPullに使用する。
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "go-ecs"
  }
}

# SecurityGroup Rule
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group_rule" "ecs" {
  security_group_id = aws_security_group.ecs.id

  # インターネットからセキュリティグループ内のリソースへのアクセス許可設定
  type = "ingress"

  # TCPでの80ポートへのアクセスを許可する
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # 同一VPC内からのアクセスのみ許可
  cidr_blocks = ["192.168.0.0/16"]
}

# ECS Service
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html
resource "aws_ecs_service" "main" {
  name = "go-service"

  # 依存関係の記述。
  # "aws_lb_listener_rule.http_to_https" リソースの作成が完了するのを待ってから当該リソースの作成を開始する。
  # "depends_on" は "aws_ecs_service" リソース専用のプロパティではなく、Terraformのシンタックスのため他の"resource"でも使用可能
  depends_on = ["aws_lb_listener_rule.http_to_https"]

  # 当該ECSサービスを配置するECSクラスターの指定
  cluster = aws_ecs_cluster.main.name

  # データプレーンとしてFargateを使用する
  launch_type = "FARGATE"

  # ECSタスクの起動数を定義
  desired_count = "1"

  # 起動するECSタスクのタスク定義
  task_definition = aws_ecs_task_definition.main.arn

  # ECSタスクへ設定するネットワークの設定
  network_configuration {
    # タスクの起動を許可するサブネット
    subnets = ["${aws_subnet.public_1c.id}"]
    # タスクに紐付けるセキュリティグループ
    security_groups = ["${aws_security_group.ecs.id}"]
    # パブリックIPの自動割り当て
    assign_public_ip = true
  }

  # ECSタスクの起動後に紐付けるELBターゲットグループ
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "web"
    container_port   = "80"
  }
}
variable "domain" {
  description = "Route 53 で管理しているドメイン名"
  type        = string

  #FIXME:
  default = "www.graph-paradise.com"
}

# Route53 Hosted Zone
# https://www.terraform.io/docs/providers/aws/d/route53_zone.html
data "aws_route53_zone" "main" {
  name         = "graph-paradise.com"
  private_zone = false
}

# ACM
# https://www.terraform.io/docs/providers/aws/r/acm_certificate.html
resource "aws_acm_certificate" "main" {
  domain_name = "graph-paradise.com"

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 record
# https://www.terraform.io/docs/providers/aws/r/route53_record.html
resource "aws_route53_record" "validation" {
  depends_on = ["aws_acm_certificate.main"]

  zone_id = "${data.aws_route53_zone.main.id}"

  ttl = 60
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
}

# ACM Validate
# https://www.terraform.io/docs/providers/aws/r/acm_certificate_validation.html
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = "${aws_acm_certificate.main.arn}"

  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

# Route53 record
# https://www.terraform.io/docs/providers/aws/r/route53_record.html
resource "aws_route53_record" "main" {
  type = "A"

  name    = "graph-paradise.com"
  zone_id = "${data.aws_route53_zone.main.id}"

  alias {
    name                   = "${aws_lb.main.dns_name}"
    zone_id                = "${aws_lb.main.zone_id}"
    evaluate_target_health = true
  }
}

# ALB Listener
# https://www.terraform.io/docs/providers/aws/r/lb_listener.html
resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.main.arn}"

  certificate_arn = "${aws_acm_certificate.main.arn}"

  port     = "443"
  protocol = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.main.id}"
  }
}

# ALB Listener Rule
# https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html
resource "aws_lb_listener_rule" "http_to_https" {
  listener_arn = "${aws_lb_listener.https.arn}"

  priority = 99

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["graph-paradise.com"]
    }
  }
}

# Security Group Rule
# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "alb_https" {
  security_group_id = "${aws_security_group.alb.id}"

  type = "ingress"

  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}