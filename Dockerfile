# Use a base image with Perl
FROM perl:5.36-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    smartmontools \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create nagios user and add to sudoers
RUN useradd -m nagios \
    && echo "nagios ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" >> /etc/sudoers

# Copy the check_smart.pl script
COPY check_smart.pl /usr/lib/nagios/plugins/check_smart.pl

# Make the script executable
RUN mkdir -p /usr/lib/nagios/plugins \
    && chmod +x /usr/lib/nagios/plugins/check_smart.pl

# Switch to nagios user
USER nagios

# Set working directory
WORKDIR /usr/lib/nagios/plugins

# Default command that shows help
CMD ["./check_smart.pl", "--help"]
