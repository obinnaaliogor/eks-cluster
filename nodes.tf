resource "aws_iam_role" "nodes" {
  name               = "eks-node-group-nodes"
  assume_role_policy = data.aws_iam_policy_document.nodes.json
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

#I added this policy because my StatefulSet pod requesting PV was in pending mode due to this policy "nodes-Amazon_EBS_CSI_Driver" that
# will allow eks-node-group to create PV was not added. Note eks comes with a dynamic storage class and therefore should
#automatically provision as PV for a pod deployed with PVC.
#adding this and associating it to the node group and also deploying the ebs driver shown below solved the issue.
## Deploy EBS CSI Driver
#kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
# Verify ebs-csi pods running
#kubectl get pods -n kube-system

resource "aws_iam_role_policy_attachment" "nodes-Amazon_EBS_CSI_Driver" {
  policy_arn = "arn:aws:iam::612500737416:policy/Amazon_EBS_CSI_Driver"
  role       = aws_iam_role.nodes.name
}


resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "private-nodes"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
      #aws_subnet.public[0].id,aws_subnet.public[1].id,
      aws_subnet.private[0].id, aws_subnet.private[1].id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t2.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  tags = {
    "k8s.io/cluster-autoscaler/demo"    = "owned"
    "k8s.io/cluster-autoscaler/enabled" = true
  }
  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
  ]
}
