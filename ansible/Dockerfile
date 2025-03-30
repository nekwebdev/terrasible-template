FROM python:3.11-slim

# Install required dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ssh-client \
    sshpass \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible
RUN pip install --no-cache-dir ansible ansible-lint jmespath

# Create a non-root user to run Ansible
RUN useradd -m ansible
# Setup SSH directory with proper permissions
RUN mkdir -p /home/ansible/.ssh && \
    chmod 700 /home/ansible/.ssh && \
    chown -R ansible:ansible /home/ansible/.ssh
USER ansible
WORKDIR /ansible

# Set entrypoint to ansible-playbook
ENTRYPOINT ["ansible-playbook"]

# docker build -t ansible-runner -f ansible.dockerfile .
# Add these to your ~/.bashrc or ~/.zshrc
# alias ansible-playbook='docker run --rm -v "$(pwd)":/ansible -v ~/.ssh:/home/ansible/.ssh:ro -e ANSIBLE_CONFIG=/ansible/ansible.cfg ansible-runner'
# alias ansible='docker run --rm -v "$(pwd)":/ansible -v ~/.ssh:/home/ansible/.ssh:ro -e ANSIBLE_CONFIG=/ansible/ansible.cfg --entrypoint ansible ansible-runner'
# alias ansible-lint='docker run --rm -v "$(pwd)":/ansible -v ~/.ssh:/home/ansible/.ssh:ro -e ANSIBLE_CONFIG=/ansible/ansible.cfg --entrypoint ansible-lint ansible-runner'