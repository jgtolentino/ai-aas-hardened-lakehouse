# Scout Architecture System Setup Guide

## Prerequisites

1. **Figma Access**
   - Figma account with edit access to Scout Architecture file
   - Personal access token from Figma account settings

2. **AWS Account** (if using S3 lakehouse)
   - AWS CLI configured
   - Terraform installed (>= 1.6.0)
   - Permissions to create S3 buckets and IAM policies

3. **GitHub Repository** 
   - Admin access to set secrets
   - GitHub Actions enabled

## Step 1: Figma Setup

### Create Architecture File
1. Create new Figma file named "Scout – Architecture v1.0"
2. Create pages following the structure in `ARCHITECTURE_GUIDE.md`:
   ```
   00 Legend & Tokens
   01 System Context  
   02 Product Architecture / Containers
   03 Runtime / Sequences
   04 Dataflow – Online
   05 Dataflow – Batch
   06 Security & IAM
   07 Observability & SLOs
   08 Deploy Topologies
   09 DR / Backup / Recovery
   10 Landing Zone Guardrails
   11 Integration Runtimes
   12 Promotion and Exfil Controls
   13 Lakehouse S3
   14 Change Log
   ```

3. Create frames with exact names:
   - `01_System_Context`
   - `02_Containers` 
   - `03_Runtime`
   - `04_Dataflow_Online`
   - `05_Dataflow_Batch`
   - `06_Security`
   - `07_Observability`
   - `08_Topologies`
   - `09_DR`
   - `10_Landing_Zone_Guardrails`
   - `11_Integration_Runtimes`
   - `12_Promotion_and_Exfil_Controls`
   - `13_Lakehouse_S3`

4. Set all frames to 1920×1080 size

### Generate Figma Token
1. Go to Figma → Settings → Personal Access Tokens
2. Create token named "Scout Architecture Export"
3. Save token securely

### Get File Key
1. Open your Figma file
2. Copy file key from URL: `figma.com/file/{FILE_KEY}/Scout-Architecture`

## Step 2: GitHub Configuration

### Set Repository Secrets
```bash
# In your GitHub repository settings → Secrets and variables → Actions
# Add the following secrets:

FIGMA_TOKEN=figd_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
FIGMA_FILE_KEY=XXXXXXXXXXXXXXXXXXXXXXXX
```

### Update Diagram Manifest
```bash
# Edit docs/architecture/diagram-manifest.json
# Replace __figma_file_key__ with your actual file key
{
  "fileKey": "your_actual_figma_file_key_here",
  ...
}
```

## Step 3: S3 Lakehouse Setup (Optional)

### Deploy Infrastructure
```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/data-lake/terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var region=us-east-1 -var bucket_name=scout-lakehouse-prod

# Apply (creates S3 bucket with medallion structure)
terraform apply -var region=us-east-1 -var bucket_name=scout-lakehouse-prod
```

### Create IAM Policies
```bash
# Set your bucket name
export LAKE_BUCKET=scout-lakehouse-prod

# Generate IAM policy files
./scripts/data-lake/render-policies.sh

# Create IAM roles in AWS Console and attach rendered policies:
# - scout-ingest-role → ingest-policy.json
# - scout-transform-role → transform-policy.json  
# - scout-consumer-role → consumer-policy.json
# - scout-ml-role → ml-policy.json
```

### Bootstrap S3 Structure
```bash
export AWS_REGION=us-east-1
export LAKE_BUCKET=scout-lakehouse-prod

# Create prefix placeholders
./scripts/data-lake/bootstrap-prefixes.sh
```

## Step 4: Test Diagram Export

### Local Test
```bash
# Export diagrams locally to test
export FIGMA_TOKEN="figd_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export FIGMA_FILE_KEY="XXXXXXXXXXXXXXXXXXXXXXXX"

node scripts/diagrams/figma-export.mjs
```

### Verify Export
```bash
# Check that diagrams were exported
ls -la docs/architecture/diagrams/

# Should see files like:
# 01_System_Context.png
# 01_System_Context.svg
# 02_Containers.png
# etc.
```

## Step 5: Test CI/CD Pipeline

### Trigger Workflow
```bash
# Make a change to trigger the workflow
echo "# Test change" >> docs/architecture/README.md
git add .
git commit -m "test: trigger diagram export workflow"
git push origin main
```

### Verify Workflow
1. Check GitHub Actions tab
2. Verify "diagrams-export" workflow runs
3. Check that diagrams are committed automatically

## Step 6: Start Using the System

### Creating ADRs
```bash
# Copy template for new ADR
cp docs/architecture/adr/0000-template.md docs/architecture/adr/0001-adopt-s3-lakehouse.md

# Fill in the template with your decision details
# Make sure to cover all Well-Architected pillars
```

### Updating Diagrams
1. Edit diagrams in Figma
2. Push any change to `docs/architecture/` or `scripts/diagrams/`
3. GitHub Actions will auto-export updated diagrams
4. Include Figma link and pillar checklist in PR description

### PR Template
```markdown
## Architecture Change

### Figma Links
- [Edited Frames](https://figma.com/file/your-file-key)

### Well-Architected Checklist
- [ ] **Reliability**: Documented failure domains and DR impact
- [ ] **Security**: Updated trust zones and access controls  
- [ ] **Cost**: Analyzed resource and operational cost impact
- [ ] **Operations**: Updated deployment and monitoring procedures
- [ ] **Performance**: Validated SLO impact and bottlenecks
- [ ] **Sustainability**: Considered environmental efficiency

### Landing Zone Impact
- [ ] Environment separation maintained
- [ ] Policy as code updated
- [ ] Integration controls reviewed

### Diagram Export
- [ ] Ran local export to verify changes
- [ ] All referenced frames exported successfully
```

## Troubleshooting

### Figma Export Issues
```bash
# Check token and file key
echo $FIGMA_TOKEN | cut -c1-10
echo $FIGMA_FILE_KEY

# Test API access
curl -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/$FIGMA_FILE_KEY" | jq .name
```

### S3 Access Issues  
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test bucket access
aws s3 ls s3://$LAKE_BUCKET/

# Check IAM policy simulation
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/scout-ingest-role \
  --action-names s3:PutObject \
  --resource-arns "arn:aws:s3:::$LAKE_BUCKET/bronze/test.parquet"
```

### GitHub Actions Issues
```bash
# Check workflow logs in GitHub UI
# Verify secrets are set correctly  
# Ensure main branch protection doesn't block bot commits
```

## Best Practices

1. **Keep Diagrams Current**: Update diagrams with every architectural change
2. **Use PR Checklist**: Always complete Well-Architected assessment  
3. **Version Control**: Tag major architecture versions in both Git and Figma
4. **Regular Reviews**: Schedule quarterly architecture review sessions
5. **Document Decisions**: Create ADRs for all significant architectural decisions

## Support

For issues with this system:
1. Check existing GitHub Issues
2. Review Figma API documentation
3. Consult AWS/Terraform documentation for infrastructure issues
4. Create new issue with full error logs and reproduction steps