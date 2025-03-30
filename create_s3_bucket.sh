#!/bin/bash
# ------------------------------------------------------------------------------
# author:      nekwebdev
# company:     monkeylab  
# license:     GPLv3
# description: creates an s3 bucket and dynamodb table for terraform remote state.
#              manages the infrastructure deployment using terraform in docker
#              containers for clean dependency management.
# ------------------------------------------------------------------------------

# color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # no color

# helper function for colored output
echo_color() {
  echo -e "${1}${2}${NC}"
}

# fancy header function
print_header() {
  local text="$1"
  local width=70
  local delimiter="━"
  local line=$(printf "%${width}s" | tr ' ' "$delimiter")
  
  echo ""
  echo_color "$CYAN" "$line"
  echo_color "$CYAN$BOLD" "  $text"
  echo_color "$CYAN" "$line"
}

# error handling function
handle_error() {
  echo_color "$RED" "❌ ERROR: $1"
  exit 1
}

# set the profile to use as a parameter (default, staging, production)
PROFILE=${1:-"default"}

print_header "TERRAFORM REMOTE STATE SETUP"
echo_color "$YELLOW" "reading configuration from backend/aws/bucket-config..."

# check if configuration file exists
[[ ! -f backend/aws/bucket-config ]] && handle_error "configuration file backend/aws/bucket-config not found"
[[ ! -f backend/aws/credentials ]] && handle_error "credentials file backend/aws/credentials not found"

# check if the provided profile exists in the config file
if [ "$PROFILE" != "default" ]; then
  PROFILE_EXISTS=$(grep -c "\[profiles $PROFILE\]" backend/aws/bucket-config)
  [[ $PROFILE_EXISTS -eq 0 ]] && handle_error "profile '$PROFILE' not found in configuration file"
else
  DEFAULT_EXISTS=$(grep -c "\[default\]" backend/aws/bucket-config)
  [[ $DEFAULT_EXISTS -eq 0 ]] && handle_error "default profile not found in configuration file"
fi

# parse the config file to extract variables
if [ "$PROFILE" = "default" ]; then
  SECTION="default"
else
  SECTION="profiles $PROFILE"
fi

# extract values from the config file
AWS_REGION=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "region" | head -1 | cut -d "=" -f 2 | tr -d ' ')
BUCKET_NAME=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "bucket" | head -1 | cut -d "=" -f 2 | tr -d ' ')
DYNAMODB_TABLE=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "dynamodb" | head -1 | cut -d "=" -f 2 | tr -d ' ')
PROJECT=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "project" | head -1 | cut -d "=" -f 2 | tr -d ' ')

# verify that all required values are set
[[ -z "$AWS_REGION" ]] && handle_error "aws region not found in config"
[[ -z "$BUCKET_NAME" ]] && handle_error "bucket name not found in config"
[[ -z "$DYNAMODB_TABLE" ]] && handle_error "dynamodb table not found in config"

# for debugging
echo_color "$GREEN" "✓ configuration loaded successfully"
echo_color "$GREEN" "  • profile:        $PROFILE"
echo_color "$GREEN" "  • region:         $AWS_REGION"
echo_color "$GREEN" "  • bucket:         $BUCKET_NAME"
echo_color "$GREEN" "  • dynamodb table: $DYNAMODB_TABLE"

print_header "TERRAFORM INIT"
echo_color "$YELLOW" "starting terraform container..."

# run the terraform docker container
docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$(pwd)/s3bucket":/tmp/workspace \
  -w /tmp/workspace \
  -e HOME=/tmp \
  hashicorp/terraform:latest init \
  -input=false || handle_error "terraform init failed"

echo_color "$GREEN" "✓ terraform init complete"

print_header "TERRAFORM PLAN"
echo_color "$YELLOW" "planning s3 bucket and dynamodb table creation..."

docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$(pwd)/s3bucket":/tmp/workspace \
  -v "$(pwd)/backend/aws/credentials":/tmp/workspace/credentials \
  -w /tmp/workspace \
  -e HOME=/tmp \
  hashicorp/terraform:latest plan \
  -input=false \
  -var "aws_region=$AWS_REGION" \
  -var "aws_profile=$PROFILE" \
  -var "aws_state_bucket_name=$BUCKET_NAME" \
  -var "aws_dynamodb_table_name=$DYNAMODB_TABLE" \
  -var "aws_common_tags={\"Environment\":\"$PROFILE\",\"ManagedBy\":\"Terraform\",\"Project\":\"$PROJECT\"}" \
  -out=plan.tfplan || handle_error "terraform plan failed"

echo_color "$GREEN" "✓ terraform plan complete"

# Ask for confirmation before applying
echo_color "$YELLOW" "Do you want to apply this plan? Only 'yes' will be accepted to approve."
read -p "Enter a value: " CONFIRM
# Convert to lowercase for case-insensitive comparison
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [ "$CONFIRM_LOWER" != "yes" ]; then
  echo_color "$RED" "Apply cancelled. Exiting..."
  exit 0
fi

print_header "TERRAFORM APPLY"
echo_color "$YELLOW" "creating s3 bucket and dynamodb table..."

docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$(pwd)/s3bucket":/tmp/workspace \
  -v "$(pwd)/backend/aws/credentials":/tmp/workspace/credentials \
  -w /tmp/workspace \
  -e HOME=/tmp \
  hashicorp/terraform:latest apply plan.tfplan || handle_error "terraform apply failed"

echo ""
echo_color "$GREEN" "✓ terraform apply complete"

print_header "SETUP COMPLETE"
echo_color "$GREEN" "s3 bucket and dynamodb table successfully created"
echo_color "$YELLOW" "you can now use these resources for terraform remote state"

# add a fancy recap section
print_header "DEPLOYMENT SUMMARY"
echo_color "$CYAN" "┌─────────────────────────────────────────────────────────────┐"
echo_color "$CYAN" "│                  TERRAFORM STATE RESOURCES                  │"
echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
echo_color "$CYAN" "│ ${BOLD}PROFILE${NC}       ${CYAN}│ ${GREEN}${PROFILE}${CYAN}"
echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
echo_color "$CYAN" "│ ${BOLD}REGION${NC}        ${CYAN}│ ${GREEN}${AWS_REGION}${CYAN}"
echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
echo_color "$CYAN" "│ ${BOLD}S3 BUCKET${NC}     ${CYAN}│ ${GREEN}${BUCKET_NAME}${CYAN}"
echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
echo_color "$CYAN" "│ ${BOLD}DYNAMODB${NC}      ${CYAN}│ ${GREEN}${DYNAMODB_TABLE}${CYAN}"
echo_color "$CYAN" "└─────────────────────────────────────────────────────────────┘"
echo ""
