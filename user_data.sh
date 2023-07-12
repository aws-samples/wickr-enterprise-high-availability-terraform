#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

yum update -y
curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
yum install jq -y
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.13/2023-05-11/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
kubectl version --short --client
curl https://kots.io/install/1.94.2 | sudo bash
kubectl-kots version
curl -sLO https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz
tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && rm eksctl_Linux_amd64.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
cat > /usr/local/bin/configure-cluster.sh << __EOF__
#!/bin/bash
clear
EKS_NAME=wickr-ha
echo
echo
read -p "What region is your cluster deployed to? i.e us-east-1: " REGION
echo -e "NOTE: If any of the following commands fail, check you have assumed an Administrative role in the CLI by running: aws sts get-caller-identity"
sleep 1
ADMINARN=\$(aws --region \$REGION iam get-role --role-name WickrEKSAdminRole | jq .Role.Arn | tr -d '"')
echo -e "Applying WickrEKSAdminRole to the EKS cluster config"
eksctl create iamidentitymapping \
    --cluster \$EKS_NAME \
    --region \$REGION \
    --arn \$ADMINARN \
    --group system:masters \
    --no-duplicate-arns \
    --username WickrEKSAdminRole
echo -e "Updating the EKS cluster config...."
aws eks update-kubeconfig --name \$EKS_NAME --region \$REGION
echo -e "....done"
echo -e "Adding storage drivers to the cluster..."
eksctl utils associate-iam-oidc-provider --cluster wickr-ha --approve --region \$REGION
eksctl create iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster wickr-ha --region \$REGION --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve --role-only --role-name AmazonEKS_EBS_CSI_DriverRole
CSIROLE=\$(aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole | jq .Role.Arn | tr -d '"')
eksctl create addon --name aws-ebs-csi-driver --cluster wickr-ha --region \$REGION --service-account-role-arn \$CSIROLE --force
echo -e "...done!"
echo
echo -e "Now run the following command, replacing LICENCE.YAML with your licence file: "
echo
echo -e "  kubectl kots install enterprise-ha --namespace wickr --ensure-rbac --license-file LICENCE.YAML"
echo
__EOF__
chmod +x /usr/local/bin/configure-cluster.sh