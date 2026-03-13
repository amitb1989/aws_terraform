# resource "aws_iam_role" "eks_admin" {
#   name = "eks-admin-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect    = "Allow",
#       Principal = { AWS = "arn:aws:iam::888696596070:root" },
#       Action    = "sts:AssumeRole"
#     }]

#   })
# }

resource "aws_iam_role" "eks_admin" {
  name = "eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ✅ Your Existing Trust Policy (kept as-is)
      {
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::888696596070:root"
        },
        Action    = "sts:AssumeRole"
      },

      # ✅ New GitHub Actions OIDC Trust Policy (added)
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            # ✅ Replace these two values with your GitHub values
            "token.actions.githubusercontent.com:sub" = "repo:amitb1989/aws_terraform:*"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "eks_admin_access" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- GitHub Actions OIDC provider (once per AWS account) ---
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]

  # Official GitHub Actions OIDC root CA thumbprint
  # (If GitHub rotates certs in the future, this may need updating.)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}