$DockerfileContent = @'
# Use the official Nginx image as the base image
FROM nginx:latest

# Set working directory
WORKDIR /tmp

# Install required packages
RUN apt-get update && \
    apt-get install -y wget unzip && \
    rm -rf /var/lib/apt/lists/*

# Download and extract the HTML files
RUN wget https://github.com/startbootstrap/startbootstrap-freelancer/archive/gh-pages.zip && \
    unzip gh-pages.zip && \
    mv startbootstrap-freelancer-gh-pages/* /usr/share/nginx/html/ && \
    rm -rf /tmp/*

# Expose port 80
EXPOSE 80
'@

Write-Host "Here is the dockerfile that we will be using to build our container image" -ForegroundColor Green
Write-Host "$($DockerfileContent) " -ForegroundColor Yellow
Set-Content -Path $HOME/Dockerfile -Value $DockerfileContent


Write-Host "Created dockerfile" -ForegroundColor Green

Write-Warning "Ensure that you install Azure CLI locally or switch to Cloud Shell before building the container image " 


