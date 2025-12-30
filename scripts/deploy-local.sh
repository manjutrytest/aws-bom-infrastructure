#!/bin/bash

# Local deployment script for BOM-driven infrastructure
# This script allows local testing and deployment without GitHub Actions

set -e

# Configuration
AWS_REGION="eu-north-1"
AWS_ACCOUNT_ID="588681235095"
ROLE_NAME="GitHubActionsBOMCloudFormationRole"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --bom-file FILE     Path to BOM CSV file (default: bom/customer-bom.csv)"
    echo "  -e, --environment ENV   Environment name (default: production)"
    echo "  -d, --dry-run          Create change sets only, don't execute"
    echo "  -v, --validate-only    Validate BOM file only"
    echo "  -r, --region REGION    AWS region (default: eu-north-1)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --bom-file bom/staging-bom.csv --environment staging"
    echo "  $0 --dry-run --validate-only"
    echo "  $0 --bom-file bom/customer-bom.csv --environment production"
}

# Default values
BOM_FILE="bom/customer-bom.csv"
ENVIRONMENT="production"
DRY_RUN=false
VALIDATE_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--bom-file)
            BOM_FILE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check if BOM file exists
    if [[ ! -f "$BOM_FILE" ]]; then
        print_error "BOM file not found: $BOM_FILE"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to validate BOM file
validate_bom() {
    print_status "Validating BOM file: $BOM_FILE"
    
    if python3 scripts/parse-bom.py "$BOM_FILE" --validate-only; then
        print_success "BOM validation passed"
        return 0
    else
        print_error "BOM validation failed"
        return 1
    fi
}

# Function to generate parameters
generate_parameters() {
    print_status "Generating CloudFormation parameters..."
    
    # Create parameters directory
    mkdir -p parameters
    
    # Generate parameters
    if python3 scripts/parse-bom.py "$BOM_FILE" --output-dir parameters; then
        print_success "Parameters generated successfully"
        
        # Show generated files
        print_status "Generated parameter files:"
        ls -la parameters/
    else
        print_error "Failed to generate parameters"
        return 1
    fi
}

# Function to validate CloudFormation templates
validate_templates() {
    print_status "Validating CloudFormation templates..."
    
    local templates=(
        "cloudformation/network-stack.yaml"
        "cloudformation/compute-stack.yaml"
        "cloudformation/storage-stack.yaml"
        "cloudformation/database-stack.yaml"
    )
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            print_status "Validating $template..."
            if aws cloudformation validate-template --template-body file://"$template" --region "$AWS_REGION" > /dev/null; then
                print_success "$template is valid"
            else
                print_error "$template validation failed"
                return 1
            fi
        fi
    done
}

# Function to create change sets
create_change_sets() {
    print_status "Creating CloudFormation change sets..."
    
    # Read deployment manifest
    if [[ ! -f "parameters/deployment-manifest.json" ]]; then
        print_error "Deployment manifest not found. Run parameter generation first."
        return 1
    fi
    
    # Get deployment order
    local stacks=($(jq -r '.deployment_order[]' parameters/deployment-manifest.json))
    
    for stack in "${stacks[@]}"; do
        local stack_name="${stack}-${ENVIRONMENT}"
        local template_file="cloudformation/${stack}.yaml"
        local parameters_file="parameters/${stack}-parameters.json"
        local changeset_name="changeset-$(date +%Y%m%d-%H%M%S)"
        
        print_status "Creating change set for stack: $stack_name"
        
        # Check if files exist
        if [[ ! -f "$template_file" ]]; then
            print_warning "Template file not found: $template_file, skipping..."
            continue
        fi
        
        if [[ ! -f "$parameters_file" ]]; then
            print_warning "Parameters file not found: $parameters_file, skipping..."
            continue
        fi
        
        # Determine change set type
        local changeset_type="CREATE"
        if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" &> /dev/null; then
            changeset_type="UPDATE"
            print_status "Stack exists, creating UPDATE change set"
        else
            print_status "Stack does not exist, creating CREATE change set"
        fi
        
        # Create change set
        if aws cloudformation create-change-set \
            --stack-name "$stack_name" \
            --template-body file://"$template_file" \
            --parameters file://"$parameters_file" \
            --change-set-name "$changeset_name" \
            --change-set-type "$changeset_type" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$AWS_REGION" \
            --tags \
                Key=Project,Value=BOM-Infrastructure \
                Key=Environment,Value="$ENVIRONMENT" \
                Key=DeployedBy,Value=LocalScript \
                Key=Timestamp,Value="$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /dev/null; then
            
            print_success "Change set created: $changeset_name"
            
            # Wait for change set creation
            print_status "Waiting for change set creation to complete..."
            if aws cloudformation wait change-set-create-complete \
                --stack-name "$stack_name" \
                --change-set-name "$changeset_name" \
                --region "$AWS_REGION"; then
                
                # Show change set details
                print_status "Change set details for $stack_name:"
                aws cloudformation describe-change-set \
                    --stack-name "$stack_name" \
                    --change-set-name "$changeset_name" \
                    --region "$AWS_REGION" \
                    --query 'Changes[].{Action:Action,ResourceType:ResourceChange.ResourceType,LogicalId:ResourceChange.LogicalResourceId,Replacement:ResourceChange.Replacement}' \
                    --output table
            else
                print_error "Change set creation failed for $stack_name"
                return 1
            fi
        else
            print_error "Failed to create change set for $stack_name"
            return 1
        fi
    done
}

# Function to execute change sets
execute_change_sets() {
    print_status "Executing CloudFormation change sets..."
    
    # Read deployment manifest
    local stacks=($(jq -r '.deployment_order[]' parameters/deployment-manifest.json))
    
    for stack in "${stacks[@]}"; do
        local stack_name="${stack}-${ENVIRONMENT}"
        
        print_status "Executing change set for stack: $stack_name"
        
        # Find the latest change set
        local changeset_name=$(aws cloudformation list-change-sets \
            --stack-name "$stack_name" \
            --region "$AWS_REGION" \
            --query 'Summaries[0].ChangeSetName' \
            --output text)
        
        if [[ "$changeset_name" == "None" ]] || [[ -z "$changeset_name" ]]; then
            print_warning "No change set found for stack: $stack_name, skipping..."
            continue
        fi
        
        # Execute change set
        if aws cloudformation execute-change-set \
            --stack-name "$stack_name" \
            --change-set-name "$changeset_name" \
            --region "$AWS_REGION" > /dev/null; then
            
            print_success "Change set execution started for $stack_name"
            
            # Wait for stack operation to complete
            print_status "Waiting for stack operation to complete..."
            
            # Determine wait condition
            local changeset_type=$(aws cloudformation describe-change-set \
                --stack-name "$stack_name" \
                --change-set-name "$changeset_name" \
                --region "$AWS_REGION" \
                --query 'ChangeSetType' \
                --output text)
            
            if [[ "$changeset_type" == "CREATE" ]]; then
                if aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$AWS_REGION"; then
                    print_success "Stack created successfully: $stack_name"
                else
                    print_error "Stack creation failed: $stack_name"
                    return 1
                fi
            else
                if aws cloudformation wait stack-update-complete --stack-name "$stack_name" --region "$AWS_REGION"; then
                    print_success "Stack updated successfully: $stack_name"
                else
                    print_error "Stack update failed: $stack_name"
                    return 1
                fi
            fi
            
            # Show stack outputs
            print_status "Stack outputs for $stack_name:"
            aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --region "$AWS_REGION" \
                --query 'Stacks[0].Outputs' \
                --output table
        else
            print_error "Failed to execute change set for $stack_name"
            return 1
        fi
    done
}

# Function to show deployment summary
show_summary() {
    print_status "Deployment Summary"
    echo "===================="
    echo "BOM File: $BOM_FILE"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Dry Run: $DRY_RUN"
    echo "Validate Only: $VALIDATE_ONLY"
    echo ""
    
    if [[ -f "parameters/deployment-manifest.json" ]]; then
        echo "Stacks to deploy:"
        jq -r '.deployment_order[]' parameters/deployment-manifest.json | while read stack; do
            echo "  - $stack"
        done
        echo ""
    fi
    
    # Show current AWS identity
    echo "AWS Identity:"
    aws sts get-caller-identity --output table
}

# Main execution
main() {
    print_status "Starting BOM-driven infrastructure deployment"
    print_status "=============================================="
    
    # Show summary
    show_summary
    
    # Check prerequisites
    check_prerequisites
    
    # Validate BOM
    if ! validate_bom; then
        exit 1
    fi
    
    # If validate-only mode, exit here
    if [[ "$VALIDATE_ONLY" == true ]]; then
        print_success "Validation completed successfully"
        exit 0
    fi
    
    # Generate parameters
    if ! generate_parameters; then
        exit 1
    fi
    
    # Validate templates
    if ! validate_templates; then
        exit 1
    fi
    
    # Create change sets
    if ! create_change_sets; then
        exit 1
    fi
    
    # If dry-run mode, exit here
    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed successfully. Change sets created but not executed."
        print_status "To execute the change sets, run without --dry-run flag"
        exit 0
    fi
    
    # Ask for confirmation before executing
    echo ""
    print_warning "This will deploy infrastructure to AWS Account: $AWS_ACCOUNT_ID"
    print_warning "Environment: $ENVIRONMENT"
    print_warning "Region: $AWS_REGION"
    echo ""
    read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
    
    # Execute change sets
    if ! execute_change_sets; then
        exit 1
    fi
    
    print_success "Deployment completed successfully!"
    print_status "Check the AWS CloudFormation console for detailed stack information"
}

# Run main function
main "$@"