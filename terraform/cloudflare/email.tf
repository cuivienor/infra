# Email DNS records for Resend SMTP
#
# SPF, DKIM, and MX records required for sending email via Resend.
# Used by Authelia for password reset emails.
# Values from Resend dashboard (uses Amazon SES under the hood).

# SPF record - authorizes Amazon SES to send email for paniland.com
# Resend requires this on the "send" subdomain
resource "cloudflare_record" "spf" {
  zone_id = var.cloudflare_zone_id
  name    = "send"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 3600

  comment = "SPF for Resend (Amazon SES) - managed by Terraform"
}

# MX record for bounce handling
# Resend requires this on the "send" subdomain
resource "cloudflare_record" "resend_mx" {
  zone_id         = var.cloudflare_zone_id
  name            = "send"
  type            = "MX"
  content         = "feedback-smtp.us-east-1.amazonses.com"
  priority        = 10
  ttl             = 3600
  allow_overwrite = true

  comment = "MX for Resend bounce handling - managed by Terraform"
}

# DKIM record - cryptographic signature for email authentication
resource "cloudflare_record" "resend_dkim" {
  zone_id = var.cloudflare_zone_id
  name    = "resend._domainkey"
  type    = "TXT"
  content = var.resend_dkim_value
  ttl     = 3600

  comment = "DKIM for Resend - managed by Terraform"
}
