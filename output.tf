output "cluster_id" {
  value = aws_eks_cluster.cojocloud.id
}

output "node_group_id" {
  value = aws_eks_node_group.cojocloud.id
}

output "vpc_id" {
  value = aws_vpc.cojocloud_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.cojocloud_subnet[*].id
}
