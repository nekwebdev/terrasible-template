#!/bin/bash
# ------------------------------------------------------------------------------
# author:      nekwebdev
# company:     monkeylab  
# license:     GPLv3
# description: initializes terraform backend (s3, terraform cloud, or http) and configures
#              a containerized environment for terraform and ansible operations.
# ------------------------------------------------------------------------------

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper function for colored output
echo_color() {
  echo -e "${1}${2}${NC}"
}

# Fancy header function
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

# Error handling function
handle_error() {
  echo_color "$RED" "❌ ERROR: $1"
  exit 1
}

# set the backend to use for terraform state, s3, terraform, http.
BACKEND=${1:-"s3"}

# set the profile to use for terraform state, default, staging, production.
PROFILE=${2:-"default"}

# check if docker and docker compose are installed
if ! command -v docker &> /dev/null && ! command -v docker-compose &> /dev/null; then
    handle_error "Docker and Docker Compose are not installed. Visit https://docs.docker.com/engine/install/"
fi

print_header "TERRAFORM $BACKEND BACKEND SETUP"

if [ "$BACKEND" = "terraform" ]; then
  echo_color "$YELLOW" "terraform.io login..."

  # run terraform login in container and save credentials
  if [ ! -f ".terraform.d/credentials.tfrc.json" ]; then
      mkdir -p .terraform.d
      docker run --rm -it \
        -u $(id -u):$(id -g) \
        -v "$(pwd)/.terraform.d:/tmp/.terraform.d" \
        -e HOME=/tmp \
        hashicorp/terraform:latest login || handle_error "terraform.io login failed"

      if [ -f ".terraform.d/credentials.tfrc.json" ]; then
          echo_color "$GREEN" "✓ terraform.io login complete"
      else
          handle_error "terraform.io login failed"
      fi
  else
      echo_color "$GREEN" "✓ terraform.io login complete"
  fi

  echo_color "$YELLOW" "reading configuration from backend/terraformio/config..."
  
  # check if configuration file exists
  [[ ! -f backend/terraformio/config ]] && handle_error "configuration file backend/terraformio/config not found"
  
  # extract values from the config file
  source backend/terraformio/config

  # verify that all required values are set
  [[ -z "$TERRAFORM_HOST" ]] && handle_error "terraform host not found in config"
  [[ -z "$TERRAFORM_ORGANIZATION" ]] && handle_error "terraform organization not found in config"
  [[ -z "$TERRAFORM_WORKSPACE" ]] && handle_error "terraform workspace not found in config"
  
  echo_color "$GREEN" "✓ configuration loaded successfully"
  echo_color "$GREEN" "  • host: $TERRAFORM_HOST"
  echo_color "$GREEN" "  • organization: $TERRAFORM_ORGANIZATION"
  echo_color "$GREEN" "  • workspace: $TERRAFORM_WORKSPACE"

  print_header "TERRAFORM TERRAFORM.IO BACKEND INIT"
  echo_color "$YELLOW" "starting terraform container..."
  
  # run terraform init in container
  docker run --rm -it \
    -u $(id -u):$(id -g) \
    -v "$(pwd)/.terraform.d:/tmp/.terraform.d" \
    -v "$(pwd)":/tmp/workspace \
    -w /tmp/workspace \
    -e HOME=/tmp \
    -e TF_CLI_CONFIG_FILE=/tmp/.terraform.d/credentials.tfrc.json \
    hashicorp/terraform:latest init \
    -input=false \
    -backend=true \
    -backend-config="hostname=$TERRAFORM_HOST" \
    -backend-config="organization=$TERRAFORM_ORGANIZATION" \
    -backend-config="workspaces { name = $TERRAFORM_WORKSPACE }" || handle_error "terraform init failed"

  echo_color "$GREEN" "✓ terraform init complete"

  print_header "CREATING TERRAFORM ALIAS"
  echo_color "$YELLOW" "creating terraform alias file..."
  # create terraform alias file
  cat > aliases << 'EOF'
# source aliases or add these to your ~/.bashrc or ~/.zshrc
alias terraform='docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$(pwd)/.terraform.d:/tmp/.terraform.d" \
  -v "$(pwd)":/tmp/workspace \
  -w /tmp/workspace \
  -e HOME=/tmp \
  -e TF_CLI_CONFIG_FILE=/tmp/.terraform.d/credentials.tfrc.json \
  hashicorp/terraform:latest'
EOF

  echo_color "$GREEN" "✓ terraform alias file created"
  echo_color "$GREEN" "✓ terraform environment setup complete"

elif [ "$BACKEND" = "s3" ]; then
  echo_color "$YELLOW" "reading configuration from backend/aws/bucket-config..."
  
  # Check if configuration file exists
  [[ ! -f backend/aws/bucket-config ]] && handle_error "configuration file backend/aws/bucket-config not found"
  
  # Parse the config file to extract variables
  if [ "$PROFILE" = "default" ]; then
    SECTION="default"
  else
    SECTION="profiles $PROFILE"
    
    # Check if the provided profile exists
    PROFILE_EXISTS=$(grep -c "\[profiles $PROFILE\]" backend/aws/bucket-config)
    [[ $PROFILE_EXISTS -eq 0 ]] && handle_error "profile '$PROFILE' not found in configuration file"
  fi

  # Extract values from the config file
  AWS_REGION=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "region" | head -1 | cut -d "=" -f 2 | tr -d ' ')
  BUCKET_NAME=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "bucket" | head -1 | cut -d "=" -f 2 | tr -d ' ')
  STATE_KEY=$(sed -n "/\[$SECTION\]/,/\[/p" backend/aws/bucket-config | grep "key" | head -1 | cut -d "=" -f 2 | tr -d ' ')
  
  # Verify that all required values are set
  [[ -z "$AWS_REGION" ]] && handle_error "aws region not found in config"
  [[ -z "$BUCKET_NAME" ]] && handle_error "bucket name not found in config"
  [[ -z "$STATE_KEY" ]] && handle_error "state key not found in config"
  
  echo_color "$GREEN" "✓ configuration loaded successfully"
  echo_color "$GREEN" "  • profile: $PROFILE"
  echo_color "$GREEN" "  • region:  $AWS_REGION"
  echo_color "$GREEN" "  • bucket:  $BUCKET_NAME"
  echo_color "$GREEN" "  • key:     $STATE_KEY"

  print_header "TERRAFORM S3 BACKEND INIT"
  echo_color "$YELLOW" "starting terraform container..."

  # run terraform init in container
  docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$(pwd)":/tmp/workspace \
  -w /tmp/workspace \
  -e HOME=/tmp \
  -e AWS_REGION="$AWS_REGION" \
  hashicorp/terraform:latest init \
  -input=false \
  -backend=true \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=$STATE_KEY" \
  -backend-config="profile=$PROFILE" || handle_error "terraform init failed"

  echo_color "$GREEN" "✓ terraform init complete"

  print_header "CREATING TERRAFORM ALIAS"
  echo_color "$YELLOW" "creating terraform alias file..."
  # create terraform alias file
  cat > aliases << EOF
# source aliases or add these to your ~/.bashrc or ~/.zshrc
alias terraform='docker run --rm -it \\
  -u \$(id -u):\$(id -g) \\
  -v "\$(pwd)":/tmp/workspace \\
  -w /tmp/workspace \\
  -e HOME=/tmp \\
  -e AWS_REGION="${AWS_REGION}" \\
  hashicorp/terraform:latest'
EOF

  echo_color "$GREEN" "✓ terraform alias added to aliases file"

elif [ "$BACKEND" = "http" ]; then
  echo_color "$YELLOW" "reading configuration from backend/tfstate/config..."
  
  # check if configuration file exists
  [[ ! -f backend/tfstate/config ]] && handle_error "configuration file backend/tfstate/config not found"
  
  # extract values from the config file
  source backend/tfstate/config

  # verify that all required values are set
  [[ -z "$USERNAME" ]] && handle_error "username not found in config"
  
  echo_color "$GREEN" "✓ configuration loaded successfully"
  echo_color "$GREEN" "  • username: $USERNAME"

  print_header "TERRAFORM HTTP BACKEND INIT"
  echo_color "$YELLOW" "starting terraform container..."
  
  # run terraform init in container
  docker run --rm -it \
    -u $(id -u):$(id -g) \
    -v "$(pwd)":/tmp/workspace \
    -w /tmp/workspace \
    -e HOME=/tmp \
    hashicorp/terraform:latest init \
    -input=false \
    -backend=true \
    -backend-config="username=$USERNAME" || handle_error "terraform init failed"

  echo_color "$GREEN" "✓ terraform init complete"

  print_header "CREATING TERRAFORM ALIAS"
  echo_color "$YELLOW" "creating terraform alias file..."
  # create terraform alias file
  cat > aliases << 'EOF'
# source aliases or add these to your ~/.bashrc or ~/.zshrc
alias terraform='docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$(pwd)":/tmp/workspace \
  -w /tmp/workspace \
  -e HOME=/tmp \
  hashicorp/terraform:latest'
EOF

  echo_color "$GREEN" "✓ terraform alias file created"

else
  handle_error "Invalid backend: $BACKEND"
fi

# setup local ansible environment
print_header "ANSIBLE ENVIRONMENT SETUP"

# create ansible docker image if it doesn't exist
if ! docker images ansible-runner | grep -q ansible-runner; then
    echo_color "$YELLOW" "creating ansible-runner docker image..."
    docker build -t ansible-runner -f ansible/Dockerfile ansible || handle_error "ansible docker image creation failed"
    echo_color "$GREEN" "✓ ansible docker image created"
else
    echo_color "$GREEN" "✓ ansible docker image already exists"
fi

print_header "CREATING ANSIBLE ALIAS"
echo_color "$YELLOW" "adding ansible aliases to aliases file..."
# append ansible aliases to aliases file
cat >> aliases << 'EOF'

alias ansible-playbook='docker run --rm \
  -u $(id -u):$(id -g) \
  -v "$(pwd)":/ansible \
  -v $SSH_AUTH_SOCK:/ssh-agent \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -e ANSIBLE_CONFIG=/ansible/ansible.cfg \
  -e ANSIBLE_FORCE_COLOR=1 \
  -e HOME=/tmp \
  ansible-runner'

alias ansible='docker run --rm \
  -u $(id -u):$(id -g) \
  -v "$(pwd)":/ansible \
  -v $SSH_AUTH_SOCK:/ssh-agent \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -e ANSIBLE_CONFIG=/ansible/ansible.cfg \
  -e ANSIBLE_FORCE_COLOR=1 \
  -e HOME=/tmp \
  --entrypoint ansible \
  ansible-runner'

alias ansible-lint='docker run --rm \
  -u $(id -u):$(id -g) \
  -v "$(pwd)":/ansible \
  -v $SSH_AUTH_SOCK:/ssh-agent \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -e ANSIBLE_CONFIG=/ansible/ansible.cfg \
  -e ANSIBLE_FORCE_COLOR=1 \
  -e HOME=/tmp \
  --entrypoint ansible-lint \
  ansible-runner'
EOF

echo_color "$GREEN" "✓ ansible alias added to aliases file"

# Add a fancy recap section
print_header "SETUP SUMMARY"
echo_color "$CYAN" "┌─────────────────────────────────────────────────────────────┐"
echo_color "$CYAN" "│                INFRASTRUCTURE SETUP COMPLETE                │"
echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
echo_color "$CYAN" "│ ${BOLD}BACKEND${NC}       ${CYAN}│ ${GREEN}${BACKEND}${CYAN}"
if [ "$BACKEND" = "s3" ]; then
  echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
  echo_color "$CYAN" "│ ${BOLD}PROFILE${NC}       ${CYAN}│ ${GREEN}${PROFILE}${CYAN}"
  echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
  echo_color "$CYAN" "│ ${BOLD}REGION${NC}        ${CYAN}│ ${GREEN}${AWS_REGION}${CYAN}"
  echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
  echo_color "$CYAN" "│ ${BOLD}S3 BUCKET${NC}     ${CYAN}│ ${GREEN}${BUCKET_NAME}${CYAN}"
  echo_color "$CYAN" "├─────────────────────────────────────────────────────────────┤"
  echo_color "$CYAN" "│ ${BOLD}STATE KEY${NC}     ${CYAN}│ ${GREEN}${STATE_KEY}${CYAN}"
fi
echo_color "$CYAN" "└─────────────────────────────────────────────────────────────┘"
echo ""
echo_color "$GREEN" "${BOLD}Project comes with dockerized terraform and ansible using custom aliases."
echo ""
echo_color "$GREEN" "${BOLD}Add ./aliases to your ~/.bashrc or ~/.zshrc"
echo ""
echo_color "$GREEN" "${BOLD}Run command: source aliases"
