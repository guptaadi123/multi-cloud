provider "aws" {
  region = "ap-south-1"
  profile = "default"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAiIfmR4xGl2LxteU6/6hjhXKFBOJfvYrd19+rtcFp9xyyCT5ZmevY3nfDkHlH82Ul0DK0QY8V1u4XnX4FDS233sLzEG4Txlf3X+yxYRX44J7ArbdvouhxwKgXNSLXn2RLyVgjIy+UP9mdw6dHT4UW4xQt6UaFm7hy3Umivpa2zdqOsYjWj+dmUkCaIFS76nLl2DhCE31LMeIpejAiSpqiICNDWSZMj278azHMwL4beZD2fh1bJpNWOkOyTVQWNAPWSSf88Twm3W1MvzTUPV+9DnYUnc3Xy+EbSJiRr+FS4FzLvaHbok7Y1zeoiknL46DsCpi2slvGn4BHY2hFm8+eVQ== rsa-key-20200610 "
}
resource "aws_security_group" "security1" {
  name        = "security1"
  description = "Security for allowing ssh and 80"
  vpc_id      = "vpc-0285986a"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_ebs_volume" "data-vol" {
       availability_zone = "ap-south-1a"
       size = 1
       tags = {
              Name = "data-volumne"
       }
}

resource "aws_instance" "myin" {
 ami            ="ami-0447a12f28fddb066"
 instance_type  = "t2.micro"
 availability_zone = "ap-south-1a"
 key_name       = "deployer-key"
 security_groups = ["security1"]
 user_data = <<-EOF
         #! /bin/bash
         sudo yum install httpd -y
         sudo yum install git -y
         sudo yum install java -y
         sudo systemctl start httpd
         sudo systemctl enable httpd
         sudo su - root
         (
            
            echo n # Add a new partition
            echo p # Primary partition
            echo 1 # Partition number
            echo   # First sector (Accept default: 1)
            echo   # Last sector (Accept default: varies)
            echo w # Write changes
         ) | sudo fdisk /dev/xvdf
         mkfs.ext4 /dev/xvdf1
         mount /dev/xvdf1 /var/www/html/
         git clone https://github.com/guptaadi123/trial.git >> cd /aditya
         cd /aditya
         sudo cp * /var/www/html
 EOF
 tags = {
    Name = "adityaos"
 }
}


resource "aws_volume_attachment" "new_vol_attach" {
        device_name = "/dev/sdf"
        volume_id =   "${aws_ebs_volume.data-vol.id}"
        instance_id = "${aws_instance.myin.id}"
        force_detach = true
}
resource "aws_s3_bucket" "task1" {
    bucket = "automatebucket1"
    acl    = "public-read"


    tags = {
	Name    = "task1"
	Environment = "Dev"
    }
    versioning {
	enabled =true
    }
}

resource "aws_s3_bucket" "web_distribution" {
  bucket = "example311414554"
  acl    = "private"
  force_destroy = "true"
}
resource "aws_cloudfront_origin_access_identity" "web_distribution" {
}
data "aws_iam_policy_document" "web_distribution" {
  statement {
    actions = ["s3:GetObject"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.web_distribution.iam_arn}"]
    }
    resources = ["${aws_s3_bucket.web_distribution.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "web_distribution" {
  bucket = "${aws_s3_bucket.web_distribution.id}"
  policy = "${data.aws_iam_policy_document.web_distribution.json}"
}
resource "aws_cloudfront_distribution" "web_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  wait_for_deployment = false
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = "${aws_s3_bucket.web_distribution.bucket_regional_domain_name}"
    origin_id   = "web_distribution_origin"
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.web_distribution.cloudfront_access_identity_path}"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "web_distribution_origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
      headers = ["Origin"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}



resource "null_resource" "nulllocal1"  {


depends_on = [
    aws_volume_attachment.new_vol_attach ,
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.myin.public_ip}"
  	}
}

output "myos_ip" {
  value = aws_instance.myin.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.myin.public_ip} > publicip.txt"
  	}
}




