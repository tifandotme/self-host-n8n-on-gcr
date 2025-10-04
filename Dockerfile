FROM docker.n8n.io/n8nio/n8n:latest

# Copy the script and ensure it has proper permissions
COPY startup.sh /
USER root
RUN chmod +x /startup.sh
RUN npm install -g @actual-app/api
USER node
EXPOSE 5678

# Use shell form to help avoid exec format issues
ENTRYPOINT ["/bin/sh", "/startup.sh"]
