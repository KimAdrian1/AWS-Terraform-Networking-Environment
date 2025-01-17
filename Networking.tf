provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""

}
# The Virtual Private Network(VPC) to be created that will house all other resources
resource "aws_vpc" "NetworkEnvironmentVPC" {
  tags = {
    Name = "NetworkEnvironmentVPC"
  }
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = "true"
}

# Internet Gateway to allow resources in the VPC to communicate with the the public internet
resource "aws_internet_gateway" "NetworkEnvironmentIGW" {
  tags = {
    Name = "IGW"
  }
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
}

# An Elastic IP address which would be used by the NAT Gateway
resource "aws_eip" "EIPSubnet1NGW" {
  tags = {
    Name = "EIPforNatGateway"
  }
}

# A NAT Gateway to allow outbound traffic from the private subnets to the internet
resource "aws_nat_gateway" "Subnet1NGW" {
  subnet_id     = aws_subnet.Subnet1.id
  allocation_id = aws_eip.EIPSubnet1NGW.id
  tags = {
    Name = "NATGatewayforSubnet1"
  }

}

# 4 Suubnets housed in availability zones us-east-1a and us-east-1b(2 subnets in each AZ) with their corresponding route table associations
resource "aws_subnet" "Subnet1" {
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
  tags = {
    Name = "PublicSubnet1"
  }
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "aws_route_table_association" "Subnet1RouteAssociation" {
  subnet_id      = aws_subnet.Subnet1.id
  route_table_id = aws_route_table.PublicSubnetsRouteTable.id
}

resource "aws_subnet" "Subnet2" {
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
  tags = {
    Name = "PrivateSubnet1"
  }
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_route_table_association" "Subnet2RouteAssociation" {
  subnet_id      = aws_subnet.Subnet2.id
  route_table_id = aws_route_table.PrivateSubnetsRouteTable.id
}

resource "aws_subnet" "Subnet3" {
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
  tags = {
    Name = "PublicSubnet2"
  }
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}
resource "aws_route_table_association" "Subnet3RouteAssociation" {
  subnet_id      = aws_subnet.Subnet3.id
  route_table_id = aws_route_table.PublicSubnetsRouteTable.id
}

resource "aws_subnet" "Subnet4" {
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
  tags = {
    Name = "PrivateSubnet2"
  }
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
}
resource "aws_route_table_association" "Subnet4RouteAssociation" {
  subnet_id      = aws_subnet.Subnet4.id
  route_table_id = aws_route_table.PrivateSubnetsRouteTable.id
}

# The route table for Private subnets. It routes traffic destined for the Internet to the NAT Gateway
resource "aws_route_table" "PrivateSubnetsRouteTable" {
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Subnet1NGW.id
  }
}

# The route table for Public subnets. It routes traffic destined for the Internet to the Internet Gateway
resource "aws_route_table" "PublicSubnetsRouteTable" {
  vpc_id = aws_vpc.NetworkEnvironmentVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.NetworkEnvironmentIGW.id
  }
}

# An S3 bucket that would contain the web files required by the web server
resource "aws_s3_bucket" "S3Bucket" {
  bucket = "movie-project-thingy-terraform"
}

resource "aws_s3_object" "S3BucketWebsiteZIP" {
  bucket = aws_s3_bucket.S3Bucket.bucket
  key    = "Movie-Website.zip"
  source = "C:/Users/kimathi/Desktop/Road to being the best developer/Responsive html and css/Movie-Website.zip"
}

# An iam role that would be used as the iam Instance Profile for the Target Group web servers
resource "aws_iam_role" "S3Role" {
  name = "EC2-S3GetObject-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    }
  )
}

# The IAM Role Policy which grants s3:GetObject access to the S3 bucket created earlier
resource "aws_iam_role_policy" "S3RolePolicy" {
  name = "S3GetObject-Policy"
  role = aws_iam_role.S3Role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.S3Bucket.arn}/*"
    }]
  })
}

# This resource attaches the IAM Role created earlier to the Insatance Profile that will be used by the web Target Group web servers
resource "aws_iam_instance_profile" "TargetGroupInstanceProfile" {
  name = "TG-InstanceProfile"
  role = aws_iam_role.S3Role.name
}

# Security Group for the Application Load Balancer to allow HTTP traffic
resource "aws_security_group" "ALBSecurityGroup" {
  name        = "ALB-SG"
  description = "Allow inbound HTTP traffic from the public internet"
  vpc_id      = aws_vpc.NetworkEnvironmentVPC.id
}
resource "aws_vpc_security_group_ingress_rule" "ALBSecurityGroupIngress" {
  security_group_id = aws_security_group.ALBSecurityGroup.id
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "ALBSecurityGroupEgress" {
  security_group_id = aws_security_group.ALBSecurityGroup.id
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}

# Security Group for the Bastion Host to allow SSH traffic
resource "aws_security_group" "BastionHostSecurityGroup" {
  name        = "BastionHost-SG"
  description = "Allow inbound SSH traffic from the public internet"
  vpc_id      = aws_vpc.NetworkEnvironmentVPC.id
}
resource "aws_vpc_security_group_ingress_rule" "BastionHostSecurityGroupIngress" {
  security_group_id = aws_security_group.BastionHostSecurityGroup.id
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "BastionHostSecurityGroupEgress" {
  security_group_id = aws_security_group.BastionHostSecurityGroup.id
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}

# Security Group for the Target Group web server instances to allow HTTP traffic
resource "aws_security_group" "TargetGroupSecurityGroupHTTP" {
  name        = "TG-HTTP-SG"
  description = "Allow inbound HTTP traffic from the Application Load Balancer"
  vpc_id      = aws_vpc.NetworkEnvironmentVPC.id
}
resource "aws_vpc_security_group_ingress_rule" "TargetGroupSecurityGroupHTTPIngress" {
  security_group_id            = aws_security_group.TargetGroupSecurityGroupHTTP.id
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.ALBSecurityGroup.id
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "TargetGroupSecurityGroupHTTPEgress" {
  security_group_id = aws_security_group.TargetGroupSecurityGroupHTTP.id
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}

# Security Group for the web server instances to allow SSH Ttraffic
resource "aws_security_group" "TargetGroupSecurityGroupSSH" {
  name        = "TG-SSH-SG"
  description = "Allow inbound SSH traffic from the Bastion Host"
  vpc_id      = aws_vpc.NetworkEnvironmentVPC.id
}
resource "aws_vpc_security_group_ingress_rule" "TargetGroupSecurityGroupSSHIngress" {
  security_group_id            = aws_security_group.TargetGroupSecurityGroupSSH.id
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.BastionHostSecurityGroup.id
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "TargetGroupSecurityGroupSSHEgress" {
  security_group_id = aws_security_group.TargetGroupSecurityGroupSSH.id
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}

# Data source to get the latest Amazon owned AMIs and with "amzn2-ami-hvm" in the AMI name
data "aws_ami" "Linux2_AMI" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "owner-id"
    values = ["137112412989"]
  }
}

# SSH Public key to be used by the EC2 instances
resource "aws_key_pair" "InstanceKey" {
  key_name   = "instance-key"
  public_key = file("C:/Users/kimathi/Desktop/AWS stuff/Terraform Network/Terraform instance key.pub")
}

# First t2.micro instance created in the first private subnet with apache installed upon creation
resource "aws_instance" "Instance1" {
  ami           = data.aws_ami.Linux2_AMI.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Subnet2.id
  vpc_security_group_ids = [
    aws_security_group.TargetGroupSecurityGroupHTTP.id, aws_security_group.TargetGroupSecurityGroupSSH.id
  ]
  iam_instance_profile = aws_iam_instance_profile.TargetGroupInstanceProfile.name
  key_name             = aws_key_pair.InstanceKey.key_name
  user_data            = <<-EOF
  #!/bin/bash
  sleep 180
# Update system packages
sudo yum update -y

# Install Apache
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd

# Download and unzip the website files from the S3 bucket
aws s3 cp s3://movie-project-thingy-terraform/Movie-Website.zip /tmp/Movie-Website.zip
sudo unzip /tmp/Movie-Website.zip -d /tmp

# Copy the content of the Movie-Website directory to /var/www/html/
sudo cp -r /tmp/Movie-Website/* /var/www/html/

# Restart Apache
sudo systemctl restart httpd

EOF

  tags = {
    Name = "TargetGroupInstance1"
  }
}

# Second t2.micro instance created in the second private subnet with apache installed upon creation
resource "aws_instance" "Instance2" {
  ami           = data.aws_ami.Linux2_AMI.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Subnet4.id
  vpc_security_group_ids = [
    aws_security_group.TargetGroupSecurityGroupHTTP.id, aws_security_group.TargetGroupSecurityGroupSSH.id
  ]
  iam_instance_profile = aws_iam_instance_profile.TargetGroupInstanceProfile.name
  key_name             = aws_key_pair.InstanceKey.key_name
  user_data            = <<-EOF
  #!/bin/bash
  sleep 180
# Update system packages
sudo yum update -y

# Install Apache
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd

# Download and unzip the website files from the S3 bucket
aws s3 cp s3://movie-project-thingy-terraform/Movie-Website.zip /tmp/Movie-Website.zip
sudo unzip /tmp/Movie-Website.zip -d /tmp

# Copy the content of the Movie-Website directory to /var/www/html/
sudo cp -r /tmp/Movie-Website/* /var/www/html/

# Restart Apache
sudo systemctl restart httpd

EOF

  tags = {
    Name = "TargetGroupInstance2"
  }

}

# Bastion Host Instance created in the first public subnet for SSH access into the target group web server instances
resource "aws_instance" "BastionHostInstance" {
  ami                         = data.aws_ami.Linux2_AMI.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.Subnet1.id
  vpc_security_group_ids = [
    aws_security_group.BastionHostSecurityGroup.id
  ]
  key_name = aws_key_pair.InstanceKey.key_name
  tags = { Name = "BastionHostInstance"
  }
}

# Target Group for the Application Load Balancer
resource "aws_lb_target_group" "ALBTargetGroup" {
  name     = "ALB-TG"
  vpc_id   = aws_vpc.NetworkEnvironmentVPC.id
  port     = 80
  protocol = "HTTP"
  health_check {
    path = "/"
  }
}

# Registers the web server instances with the Target Group
resource "aws_lb_target_group_attachment" "ALBTargetGroupAttachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.ALBTargetGroup.arn
  target_id        = element([aws_instance.Instance1.id, aws_instance.Instance2.id], count.index)
  port             = 80
}


# A listener for the Application Load Balancer which checks for incoming HTTP traffic on port 80
resource "aws_lb_listener" "ALBListener" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ALBTargetGroup.arn
  }
}

# The ALB responsible for load balancing traffic between the 2 web servers in availability zone us-east-1a and us-east-1b
resource "aws_lb" "ALB" {
  load_balancer_type = "application"
  name               = "ALB"
  subnets            = [aws_subnet.Subnet1.id, aws_subnet.Subnet3.id]
  security_groups    = [aws_security_group.ALBSecurityGroup.id]
  internal           = false
}

# The Outputs required from some of the resources created
output "ALB_DNS" {
  description = "The domain name of the Application Load Balancer"
  value       = aws_lb.ALB.dns_name
}

output "BastionHostInstance_PublicIP" {
  description = "The Public IP address of the Bastion Host Instance"
  value       = aws_instance.BastionHostInstance.public_ip
}

output "Instance1_PrivateIP" {
  description = "The Private IP address of Instance 1"
  value       = aws_instance.Instance1.private_ip
}

output "Instance2_PrivateIP" {
  description = "The Private IP address of Instance 2"
  value       = aws_instance.Instance2.private_ip
}


