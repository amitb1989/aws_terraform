# variable "domain_name" {
#   type = string
#     default = "amitb-demo.com"
# }

# variable "alb_dns_name" {
#   type = string
#   default = "k8s-apps-aafc3afa1b-1483651481.ap-south-1.elb.amazonaws.com"
# }

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "user" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "user.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60
  records = [var.alb_dns_name]
}

resource "aws_route53_record" "order" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "order.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60
  records = [var.alb_dns_name]
}