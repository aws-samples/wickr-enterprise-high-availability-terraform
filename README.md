# Wickr Enterprise High-Availability Terraform

## Description
This Terraform module builds a Wickr Enterprise High Availability deployment across three Availability Zones and is designed to be as automated as possible.
The deployment will take ~20mins and includes the following resources:

- 1 x Amazon Virtual Private Cloud (Amazon VPC)
- 3 x Public and 3 x Private Subnets, with 3 x NAT Gateways spanning 3 Availability Zones in the given region
- An Amazon Simple Storage Service (Amazon S3) bucket for Wickr objects, encrypted with server-side encryption with Amazon S3 managed keys (SSE-S3) and access logging enabled into another Amazon S3 bucket
- An Amazon Elastic Compute Cloud (Amazon EC2) instance running Amazon Linux 2 with necessary tools pre-installed, to be used as a jump-box for cluster administration via AWS Systems Manager Session Manager
- An Amazon Elastic Kubernetes Service (Amazon EKS) cluster running EKS version 1.23
- An Amazon Relational Database Service (Amazon RDS) cluster with three instances running Amazon Aurora for MySQL, encrypted with an AWS Key Management Service (KMS) Customer Managed Key (CMK)
- A randomly generated admin user password for Amazon Aurora for MySQL, stored in AWS Secrets Manager, encrypted with another AWS KMS CMK

Once the infrastructure has been provisioned by Terraform, a script must be run from the jump-box to set up the Wickr Enterprise cluster. Details are below.

## Architecture
![architecture](/images/architecture.png?raw=true)

## Prerequisities
Throughout, 'your AWS account' refers to the AWS account where you wish to deploy Wickr Enterprise. All resources must be in the same AWS region.

We assume you wish to store your Terraform state file in an Amazon S3 bucket in your AWS account, with a DynamoDB table for state locking,
as described [here](https://developer.hashicorp.com/terraform/language/settings/backends/s3).
For alternative methods of handling the state file, you will need to update the `terraform {}` block inside `main.tf` in accordance with the Terraform documentation.

You will need the following:
- A valid Wickr Enterprise HA licence key (`.yaml` format)
- An S3 bucket in your AWS account for the Terraform state file (Bucket Versioning is strongly recommended)
- A DynamoDB table in your AWS account (with partition key `LockID` of type `String`) for the Terraform state lock
- An existing Amazon EC2 KeyPair in your AWS Account, 
where the private key is available on your local machine for SSH authentication into the jump-box. Instructions can be found [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
- An administrative IAM user or role with credentials for the AWS CLI that you are willing and able to use both locally and within the jump-box
- The AWS Systems Manager Session Manager plugin [installed](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) and [configured](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html#ssh-connections-enable) on your local machine (this will be used to SSH into the jump-box)

## Deployment Guide
1. Inside the root of this project, create a file `s3.tfbackend` with the following contents
(update `YOUR_BUCKET_NAME`, `YOUR_REGION` and `YOUR_TABLE_NAME`):
```bash
bucket = "YOUR_BUCKET_NAME"
key    = "terraform/states/wickr-ent-ha.tfstate"
region = "YOUR_REGION"
dynamodb_table = "YOUR_TABLE_NAME"
```
2. Inside the root of this project, create a file ending in `.auto.tfvars` that contains the lines
```bash
public_ingress_cidr = "YOUR_CHOSEN_CIDR_RANGE"
ssh_key_name = "YOUR_SSH_KEY_NAME"
```
where `YOUR_CHOSEN_CIDR_RANGE` is the CIDR range from which your Wickr Enterprise deployment will be accessible over the Internet
(it is suggested that you set this to be your own public IP address, followed by `/32`, for test deployments,
whereas production deployments must set this to be `0.0.0.0/0`)
and `YOUR_SSH_KEY_NAME` is the name of your Amazon EC2 KeyPair that will be used to access the jump-box EC2 instance.


3. With AWS credentials configured for your intended deployment environment, run 
`terraform init -backend-config=s3.tfbackend`
to initialise Terraform, then
`terraform apply`
to see which resources will be created, followed by `yes` (when prompted, if you're happy with the plan) to create those resources.
The `apply` operation typically takes around 20 minutes.

4. Note the instance ID of the jump-box from the `Outputs:` printed at the end of the `apply` operation.
Use this instance ID and your SSH key to copy your Wickr Enterprise licence key on to the jump-box
(N.B. **The trailing `:` in the following command is needed**
you will need to first make sure the permissions on your SSH private key are not too open,
i.e. you may need to run `chmod 600 YOUR_PRIVATE_KEY`,
and for any Session Manager connections like this one and the next step, you must ensure your AWS CLI credentials are still valid):
```bash
scp -i YOUR_PRIVATE_KEY YOUR_LOCAL_LICENSE_KEY ec2-user@[JUMP-BOX-ID]:
```

5. **SSH** using Session Manager into the EC2 jump-box
```bash
ssh -i YOUR_PRIVATE_KEY ec2-user@JUMP-BOX-ID
```

6. **Very Important!** 
Within the EC2 jump-box, **temporarily assume the same administrative AWS CLI user/role as in Step 1**. Instructions can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html). 
The simplest method is just to paste temporary credentials into the CLI as environment variables.
Otherwise, if you are using the EC2 instance profile created by this Cloudformation template to assume your Admin IAM role, you will need to include the EC2 instance profile in the trust policy of your Admin IAM role and then export the temporary credentials as environment variables (note, a CLI _named profile_ will not work in Step 5) via the following bash command
(replace `YOUR_ACCOUNT` and `YOUR_ROLENAME`):
```bash
OUT=$(aws sts assume-role --role-arn arn:aws:iam::<YOUR_ACCOUNT>:role/<YOUR_ROLENAME> --role-session-name jump-box);\
export AWS_ACCESS_KEY_ID=$(echo $OUT | jq -r '.Credentials''.AccessKeyId');\
export AWS_SECRET_ACCESS_KEY=$(echo $OUT | jq -r '.Credentials''.SecretAccessKey');\
export AWS_SESSION_TOKEN=$(echo $OUT | jq -r '.Credentials''.SessionToken');
```
Run `aws sts get-caller-identity` to confirm you are in the correct role - the same role used in Step 1.

7. Once you have completed the step above, run the following command: `configure-cluster.sh`
8. Follow the on-screen prompts and allow the command to finish.
9. The Wickr cluster admin console will now deploy. You will need to create a console password during this process which you must store securely.
10. Once you have been told to access the admin console, open a **new terminal tab** and assume your Administrative role again, then run the following command,
which will set up a port forwarding session over the SSH tunnel from your local machine to the remote jump-box, where the admin console is running.
- **NOTE:** DO NOT close your current tab, it must remain open whilst the admin console is in use!

```bash
aws ssm start-session --target JUMP-BOX-ID --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["8800"], "localPortNumber":["8800"]}'
```
11. Click on [this link](http://localhost:8800) to access the admin console via the tunnel.

## Configure Wickr Enterprise HA

1. You will need to fill in the following configuration fields in the Wickr Admin console:

* **Hostname** - Enter the endpoint for the Wickr client to connect to. This will be the hostname that your Wickr clients will connect to, as well as the Network Administrative console address.
* **Enable Global Federation** - Leave unchecked unless you have been advised to enable this feature.
* **Certificate Type** - Select to use an [Amazon Certificate Manager](https://console.aws.amazon.com/acm) (ACM) certificate or a self-signed certificate. 
If you opt to use ACM, you need to create the certificate using ACM in the AWS Console and use the **ARN - not the ID -** as the value. 
* **Set a Pinned Certificate** - If using ACM, you will need to supply the certificate Amazon Root CA in .pem format. You can get this from [here](https://www.amazontrust.com/repository/AmazonRootCA1.pem). Create a file from this (including the BEGIN and END statements!) and name it AmazonRootCA.pem
* **Database** - You can find the Database Hostname in the Terraform outputs, and the admin username and password in [AWS Secrets Manager](https://console.aws.amazon.com/secretsmanager/). Leave the other database fields empty as they will assume the defaults. 
* **S3** - You can find the bucket name in the Terraform outputs, and the region will be the region you have deployed into.

2. When finished, select **‘Continue’** at the bottom of the window. The console will run some preflight checks to ensure your cluster will meet the minimum requirements. One of the checks that reads from S3 may not pass right away, as it can take some time to connect. **NOTE:** If this happens, wait a minute, navigate to ‘Application’ on the top left of the page and select ‘Checks passed with warnings’ on the dashboard. Then select **‘Re-run’** - the check should pass now. 
3. Return to the Wickr dashboard tab, which should now show as deploying. Wickr will now deploy to the cluster. This will take ~15 mins. 
4. (Recommended) The deployment will have deployed a Network Load Balancer in your AWS account for you as part of the build, and associated your ACM certificate with it if you provided one. You will need to point your DNS entry to that NLB A-record.
5. You can now navigate to `https://[wickr-hostname]` to access the Wickr Network Administrative console
(once any DNS changes have been fully propagated).
The default credentials are `admin` and `Password123` and you will be asked to change them on first login.

## Post-Installation 

- The EC2 jump-box is only required when you need to reach the cluster config screen again, so this can be powered down if desired.
- [Enable private access](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html) for your Amazon EKS cluster's Kubernetes API server endpoint and limit, or completely disable, public access from the internet.

## Notes ##

1. If you need to re-deploy the cluster admin console, simply assume the WickrEKSAdmin role with the following command,
ensuring you **replace** WickrEKSAdminArn with the Arn of that role. 
You can get this from the Terraform outputs.
```bash
RAW_JSON=$(aws sts assume-role --role-arn EKSAdminArn --role-session-name eksadmin-cli --output json) && KEYID=$(echo $RAW_JSON | jq .Credentials.AccessKeyId | tr -d '"') && AKEY=$(echo $RAW_JSON | jq .Credentials.SecretAccessKey | tr -d '"') && TOKEN=$(echo $RAW_JSON | jq .Credentials.SessionToken | tr -d '"') && export AWS_ACCESS_KEY_ID="$KEYID" && export AWS_SECRET_ACCESS_KEY="$AKEY" && export AWS_SESSION_TOKEN="$TOKEN" && aws sts get-caller-identity
```
2. You should see a confirmation that you have assumed the EKSAdminRole, then run the following command.
```bash
kubectl kots admin-console --namespace wickr
```


## Tear Down
Before you can `Terraform destroy` you will need to manually delete some resources that were created by the Wickr installation process.
1. Delete the Network Load Balancer
2. Empty both the Wickr files S3 bucket and the Wickr logs S3 bucket
3. Delete the `eksctl-wickr-ha-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa` Cloudformation stack
4. With AWS credentials configured for your deployment environment, run
```bash
terraform destroy
```
to see which resources will be destroyed, followed by `yes` (when prompted, if you're happy with the plan) to destroy those resources.


## Authors and acknowledgment
This project was built by Ryan Stanley (rwstan@amazon.com) 
but based entirely on Charles Chowdhury-Hanscombe (charlcch@amazon.co.uk)'s prior work using CloudFormation:
https://github.com/aws-samples/wickr-enterprise-high-availability-cloudformation


## Project status
June 2023: not under active development - may not continue to work as Wickr Enterprise evolves.

## Security
See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License
This library is licensed under the MIT-0 License. See the LICENSE file.