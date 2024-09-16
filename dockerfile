# Use a lightweight base image
FROM alpine:latest

# Install necessary packages, if any
RUN apk add --no-cache bash

# Set the working directory
WORKDIR /scripts

# Copy your shell scripts into the container
COPY . .

# Make the shell scripts executable
RUN chmod +x *.sh

# Specify the script to run when the container starts
CMD ["bash", "-c", "./script1.sh && ./script2.sh"]
