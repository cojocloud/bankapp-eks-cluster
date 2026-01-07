provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "cojocloud_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cojocloud-vpc"
  }
}

resource "aws_subnet" "cojocloud_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.cojocloud_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.cojocloud_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "cojocloud-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "cojocloud_igw" {
  vpc_id = aws_vpc.cojocloud_vpc.id

  tags = {
    Name = "cojocloud-igw"
  }
}

resource "aws_route_table" "cojocloud_route_table" {
  vpc_id = aws_vpc.cojocloud_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cojocloud_igw.id
  }

  tags = {
    Name = "cojocloud-route-table"
  }
}

resource "aws_route_table_association" "cojocloud_association" {
  count          = 2
  subnet_id      = aws_subnet.cojocloud_subnet[count.index].id
  route_table_id = aws_route_table.cojocloud_route_table.id
}

resource "aws_security_group" "cojocloud_cluster_sg" {
  vpc_id = aws_vpc.cojocloud_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cojocloud-cluster-sg"
  }
}

resource "aws_security_group" "cojocloud_node_sg" {
  vpc_id = aws_vpc.cojocloud_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cojocloud-node-sg"
  }
}

resource "aws_eks_cluster" "cojocloud" {
  name     = "cojocloud-cluster"
  role_arn = aws_iam_role.cojocloud_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.cojocloud_subnet[*].id
    security_group_ids = [aws_security_group.cojocloud_cluster_sg.id]
  }
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.cojocloud.name
  addon_name   = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


resource "aws_eks_node_group" "cojocloud" {
  cluster_name    = aws_eks_cluster.cojocloud.name
  node_group_name = "cojocloud-node-group"
  node_role_arn   = aws_iam_role.cojocloud_node_group_role.arn
  subnet_ids      = aws_subnet.cojocloud_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.cojocloud_node_sg.id]
  }
}

resource "aws_iam_role" "cojocloud_cluster_role" {
  name = "cojocloud-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cojocloud_cluster_role_policy" {
  role       = aws_iam_role.cojocloud_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "cojocloud_node_group_role" {
  name = "cojocloud-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cojocloud_node_group_role_policy" {
  role       = aws_iam_role.cojocloud_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cojocloud_node_group_cni_policy" {
  role       = aws_iam_role.cojocloud_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "cojocloud_node_group_registry_policy" {
  role       = aws_iam_role.cojocloud_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cojocloud_node_group_ebs_policy" {
  role       = aws_iam_role.cojocloud_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
