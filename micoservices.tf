resource "null_resource" "apply_yaml" {
  depends_on = [
    module.eks,
    helm_release.alb_ingress
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-Command"]
    command = <<-EOT
      $ErrorActionPreference = "Stop"

      # If you fixed trust and want to assume eks-admin-role, use the next line; otherwise keep it without --role-arn:
      aws eks update-kubeconfig --name eks-cluster-assement --region ap-south-1 --role-arn arn:aws:iam::888696596070:role/eks-admin-role

      $kubectl = "C:\\Users\\bamitd\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Kubernetes.kubectl_Microsoft.Winget.Source_8wekyb3d8bbwe\\kubectl.exe"

      # Sanity
      & $kubectl version --client
      & $kubectl config current-context

      # Apply manifests (use absolute paths for reliability)
      & $kubectl apply -f "${path.root}/kubernetes/namespaces.yaml"
      & $kubectl apply -f "${path.root}/kubernetes/microservices/user/"
      & $kubectl apply -f "${path.root}/kubernetes/microservices/order/"
      & $kubectl apply -f "${path.root}/kubernetes/ingress/ingress.yaml"
    EOT
  }
}