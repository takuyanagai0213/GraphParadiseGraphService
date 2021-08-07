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
  region = "us-west-2"
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
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "handson"
  }
}
resource "aws_subnet" "public_1c" {
  vpc_id = "${aws_vpc.main.id}"

  availability_zone = "us-west-2a"

  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "handson-public-1c"
  }
}
# Internet Gateway
# https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "handson"
  }
}

# Route Table
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "handson-public"
  }
}

# Route
# https://www.terraform.io/docs/providers/aws/r/route.html
resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.public.id}"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

# Association
# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "public_1c" {
  subnet_id      = "${aws_subnet.public_1c.id}"
  route_table_id = "${aws_route_table.public.id}"
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
  network_mode = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  # 起動するコンテナの定義
  container_definitions = <<JSON
  [
    {
      "name": "web",
      "image": var.image,
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
# resource "aws_lb_target_group" "main" {
#   name = "handson"

#   # ターゲットグループを作成するVPC
#   vpc_id = "${aws_vpc.main.id}"

#   # ALBからECSタスクのコンテナへトラフィックを振り分ける設定
#   port        = 80
#   protocol    = "HTTP"
#   target_type = "ip"

#   # コンテナへの死活監視設定
#   health_check = {
#     port = 80
#     path = "/"
#   }
# }

# ALB Listener Rule
# https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html
# resource "aws_lb_listener_rule" "main" {
#   # ルールを追加するリスナー
#   listener_arn = "${aws_lb_listener.main.arn}"

#   # 受け取ったトラフィックをターゲットグループへ受け渡す
#   action {
#     type             = "forward"
#     target_group_arn = "${aws_lb_target_group.main.id}"
#   }

#   # ターゲットグループへ受け渡すトラフィックの条件
#   condition {
#     field  = "path-pattern"
#     values = ["*"]
#   }
# }
# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "ecs" {
  name        = "handson-ecs"
  description = "handson ecs"

  # セキュリティグループを配置するVPC
  vpc_id      = "${aws_vpc.main.id}"

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
    Name = "handson-ecs"
  }
}

# SecurityGroup Rule
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group_rule" "ecs" {
  security_group_id = "${aws_security_group.ecs.id}"

  # インターネットからセキュリティグループ内のリソースへのアクセス許可設定
  type = "ingress"

  # TCPでの80ポートへのアクセスを許可する
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # 同一VPC内からのアクセスのみ許可
  cidr_blocks = ["10.0.0.0/16"]
}

# ECS Service
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html
resource "aws_ecs_service" "main" {
  name = "handson"

  # 依存関係の記述。
  # "aws_lb_listener_rule.main" リソースの作成が完了するのを待ってから当該リソースの作成を開始する。
  # "depends_on" は "aws_ecs_service" リソース専用のプロパティではなく、Terraformのシンタックスのため他の"resource"でも使用可能
  # depends_on = ["aws_lb_listener_rule.main"]

  # 当該ECSサービスを配置するECSクラスターの指定
  cluster = "${aws_ecs_cluster.main.name}"

  # データプレーンとしてFargateを使用する
  launch_type = "FARGATE"

  # ECSタスクの起動数を定義
  desired_count = "1"

  # 起動するECSタスクのタスク定義
  task_definition = "${aws_ecs_task_definition.main.arn}"

  # ECSタスクへ設定するネットワークの設定
  network_configuration {    
    # タスクの起動を許可するサブネット
    subnets         = ["${aws_subnet.public_1c.id}"]
    # タスクに紐付けるセキュリティグループ
    security_groups = ["${aws_security_group.ecs.id}"]
    # パブリックIPの自動割り当て
    assign_public_ip = true
  }

  # ECSタスクの起動後に紐付けるELBターゲットグループ
  # load_balancer = [
  #   {
  #     target_group_arn = "${aws_lb_target_group.main.arn}"
  #     container_name   = "nginx"
  #     container_port   = "80"
  #   },
  # ]
}