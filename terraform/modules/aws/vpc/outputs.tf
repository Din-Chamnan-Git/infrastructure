output "vpc_id" {
  value       = aws_vpc.my_vpc.id
  description = "The ID of create VPC"

}

output "subnet_id" {
  value       = aws_subnet.my_subnet.id
  description = "The ID of create subnet"

}

output "igw_id" {
  value       = aws_internet_gateway.my_igw.id
  description = "The ID of create igw"

}

output "route_table_id" {
  value       = aws_route_table.my_route_table.id
  description = "The ID of create route table"

}

output "subnet_id_2" {
  value       = aws_subnet.my_subnet_2.id
  description = "The ID of the second created subnet"
}

output "subnet_ids" {
  value       = [aws_subnet.my_subnet.id, aws_subnet.my_subnet_2.id]
  description = "List of all created subnet IDs"
}
