# 1. Lookup existing Cloudflare Zone by Domain Name
data "cloudflare_zone" "main" {
  name = var.domain_name
}

# 2. Automated ACM DNS Validation Record in Cloudflare
resource "cloudflare_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.main.id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  ttl     = 60
  proxied = false # DNS validation record must NOT be proxied through Cloudflare CDN
}

# 3. ACM Certificate Validation Resource
resource "aws_acm_certificate_validation" "cert_valid" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in cloudflare_record.acm_validation : r.hostname]
}

# 4. Cloudflare CNAME Record Pointing Subdomain to AWS ALB
resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.main.id
  name    = var.subdomain
  value   = aws_lb.main.dns_name
  type    = "CNAME"
  proxied = true # Enables Cloudflare CDN, Free SSL, & DDoS protection
  ttl     = 1    # Automatic TTL when proxied
}
