# Kubernetes Logging | Amazon EKS logging using Fluentbit and Amazon OpenSearch Service 

## EKS 클러스터 생성

```
# Cluster 생성
chmod +x ./cluster.sh
bash cluster.sh
eksctl create cluster -f cluster.yml

# Cluster 연결
aws eks update-kubeconfig --name skills-cluster

# Cluster 연결 확인
kubectl get nodes
```

## IRSA for FluentBit

```
# IAM 사용 활성화
eksctl utils associate-iam-oidc-provider --cluster skills-cluster --approve

# FluentBit 권한 생성
aws iam create-policy --policy-name fluentbit-policy --policy-document file://fluentbit.json

# Service Account 생성
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
eksctl create iamserviceaccount \
--name fluent-bit \
--cluster skills-cluster \
--attach-policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/fluentbit-policy" \
--approve \
--override-existing-serviceaccounts

```
## OpenSearch Serivce 생성

```
sed -i "s/<ACCOUNT_ID>/${ACCOUNT_ID}/g" ./domain.json
sed -i "s/<DOMAIN_NAME>/[도메인 이름]/g" ./domain.json
sed -i "s/<VERSION>/[버전]/g" ./domain.json
sed -i "s/<USERNAME>/[사용자 이름]/g" ./domain.json
sed -i "s/<PASSWORD>/[사용자 비밀번호]/g" ./domain.json

aws opensearch create-domain --cli-input-json  file://domain.json
aws opensearch describe-domain --domain-name [도메인 이름]
```

## ElastiSearch 연동 시키기

```
# Fluentbit의 ServiceAccount ARN 가져오기
eksctl get iamserviceaccount --cluster skills-cluster -o json

# ElastiSearch 연동
curl -sS -u "oseks:MysuperSct_Ek1$" -X PATCH <도메인 엔드포인트>/_opendistro/_security/api/rolesmapping/all_access?pretty -H 'Content-Type: application/json' -d '[{"op": "add", "path": "/backend_roles", "value": ["'<Fluentbit ServiceAccount ARN>'"]}]'
```