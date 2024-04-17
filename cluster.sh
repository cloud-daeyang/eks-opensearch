#!/bin/bash

config_file="cluster.yml"

echo "Creating EKS Cluster Configuration..."

read -p "Cluster 이름을 입력하세요: " cluster_name
echo "apiVersion: eksctl.io/v1alpha5" > $config_file
echo "kind: ClusterConfig" >> $config_file
echo "" >> $config_file
echo "metadata:" >> $config_file
echo "  name: $cluster_name" >> $config_file
echo "  region: ap-northeast-2" >> $config_file
echo "  version: \"1.29\"" >> $config_file
echo "" >> $config_file
echo "cloudWatch:" >> $config_file
echo "  clusterLogging:" >> $config_file
echo "    enableTypes: [\"*\"]" >> $config_file
echo "" >> $config_file
echo "vpc:" >> $config_file

read -p "VPC 이름 입력하세요: " vpc_name
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$vpc_name" --query 'Vpcs[0].VpcId' --output text)
echo "  id: $vpc_id" >> $config_file
echo "  subnets:" >> $config_file
echo "    public:" >> $config_file

read -p '본인 계정에 Public 서브넷의 개수: ' public
public_subnet_ids=()
for (( i=1; i<=public; i++ )); do
    read -p "Public 서브넷 $i 의 이름을 입력하세요: " pub_subnet_name
    pub_subnet_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$pub_subnet_name" --query 'Subnets[0].SubnetId' --output text)
    public_subnet_ids+=("$pub_subnet_id")
    echo "      $pub_subnet_name: { id: $pub_subnet_id }" >> $config_file
done

echo "    private:" >> $config_file
read -p '본인 계정에 Private 서브넷의 개수: ' private
private_subnet_ids=()
for (( i=1; i<=private; i++ )); do
    read -p "Private 서브넷 $i 의 이름을 입력하세요: " priv_subnet_name
    priv_subnet_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$priv_subnet_name" --query 'Subnets[0].SubnetId' --output text)
    private_subnet_ids+=("$priv_subnet_id")
    echo "      $priv_subnet_name: { id: $priv_subnet_id }" >> $config_file
done

cat <<EOF >> $config_file
managedNodeGroups:
  - name: skills-app
    instanceType: c5.large
    labels: { skills: app }
    tags: { skills: app }
    minSize: 2
    maxSize: 20
    desiredCapacity: 2
    privateNetworking: true
    subnets:
      - ${private_subnet_ids[0]}
      - ${private_subnet_ids[1]}
      - ${private_subnet_ids[2]}
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        awsLoadBalancerController: true
        cloudWatch: true

  - name: skills-addon
    instanceType: c5.large
    labels: { skills: addon }
    tags: { skills: addon }
    minSize: 2
    maxSize: 20
    desiredCapacity: 2
    privateNetworking: true
    subnets:
      - ${private_subnet_ids[0]}
      - ${private_subnet_ids[1]}
      - ${private_subnet_ids[2]}
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        awsLoadBalancerController: true
        cloudWatch: true
EOF

echo "Configuration file $config_file created."
echo "Review the configuration file before proceeding."

# Ask user confirmation before creating cluster
read -p "Do you want to create the cluster now? (yes/no): " response
if [[ "$response" == "yes" ]]; then
    if ! command -v eksctl &> /dev/null; then
        ARCH=amd64
        PLATFORM=$(uname -s)_$ARCH
        curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
        tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
        sudo mv /tmp/eksctl /usr/local/bin
        echo "eksctl installed!"
    fi
    eksctl create cluster -f $config_file
    echo "Cluster creation initiated."
else
    echo "Cluster creation aborted by the user."
fi