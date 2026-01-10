# Production Environment - AWS EKS Deployment

This directory contains ArgoCD Applications configured for **production AWS EKS clusters**.

## Features

- **Real DNS domain** - Route53 integration
- **Let's Encrypt TLS** - Production certificates via cert-manager
- **AWS Secrets Manager** - Production secrets with IRSA
- **High Availability** - Multi-replica deployments
- **Production resources** - Tuned CPU/memory limits

## Domain Configuration

Update `domain` in values files before deployment:

```yaml
# helm-charts/platform-ingress/values.prod.yaml
domain: platform.example.com  # Your actual domain
```

## Prerequisites

1. EKS cluster with:
   - nginx-ingress-controller (creates AWS NLB)
   - cert-manager with Let's Encrypt ClusterIssuer
   - External Secrets Operator with IRSA configured

2. AWS Infrastructure:
   - Route53 hosted zone for your domain
   - ACM certificate (optional, if using AWS ALB)
   - Secrets in AWS Secrets Manager

3. DNS Configuration:
   ```bash
   # Get NLB DNS name
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   
   # Create Route53 CNAME record:
   # platform.example.com -> <NLB-DNS-NAME>
   ```

## Deployment

```bash
# Ensure production context
kubectl config use-context arn:aws:eks:region:account:cluster/prod-cluster

# Apply production applications
kubectl apply -f apps/prod/

# Or use the App of Apps pattern
kubectl apply -f apps/prod/root-app.yaml
```

## Security Considerations

- [ ] All secrets stored in AWS Secrets Manager (never in Git)
- [ ] TLS certificates from Let's Encrypt (not self-signed)
- [ ] Network policies enforced
- [ ] Pod Security Standards applied
- [ ] Resource quotas configured
- [ ] Backup strategy for PersistentVolumes
