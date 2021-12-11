terraform {
  required_providers {
    kubernetes = {}
    helm       = {}
  }
}

resource "aws_secretsmanager_secret" "anchore" {
  name                    = "anchore"
  recovery_window_in_days = 0
}

resource "random_password" "anchore" {
  length           = 24
  special          = true
  override_special = "_%@"
}

resource "aws_secretsmanager_secret_version" "anchore" {
  secret_id     = aws_secretsmanager_secret.anchore.id
  secret_string = "{\"password\": \"${random_password.anchore.result}\"}"
}

resource "helm_release" "anchore" {
  name             = "anchore"
  chart            = var.helm_chart_name
  namespace        = var.namespace
  repository       = var.helm_chart
  timeout          = var.helm_timeout
  version          = var.helm_version
  create_namespace = false
  reset_values     = false

  set {
    name  = "anchoreGlobal.defaultAdminPassword"
    value = random_password.anchore.result
  }

  set {
    name  = "anchoreGlobal.defaultAdminEmail"
    value = var.admin_email
  }
}

resource "kubernetes_secret" "anchore" {
  metadata {
    name      = "anchore-password"
    namespace = var.namespace
    labels = {
      "ConnectOutput" = "true"
    }
  }

  data = {
    password = random_password.anchore.result
  }

  type = "kubernetes.io/basic-auth"
}

resource "kubernetes_ingress" "ingress" {

  wait_for_load_balancer = true

  metadata {
    name      = "anchore"
    namespace = var.namespace

    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "cert-manager"
    }
  }
  spec {
    rule {

      host = "anchore.${var.dns_zone}"

      http {
        path {
          path = "/"
          backend {
            service_name = "anchore-engine-anchore-engine-api"
            service_port = 8228
          }
        }
      }
    }

    tls {
      secret_name = "anchore-tls-secret"
    }
  }

  depends_on = [
    helm_release.anchore,
  ]
}

data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [
    helm_release.anchore,
  ]
}

data "aws_route53_zone" "vpc" {
  name = var.dns_zone
}

resource "aws_route53_record" "anchore_cname" {
  zone_id = data.aws_route53_zone.vpc.zone_id
  name    = "anchore.${var.dns_zone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.ingress_nginx.status.0.load_balancer.0.ingress.0.hostname]

  depends_on = [
    helm_release.anchore
  ]
}
