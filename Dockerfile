FROM node:16-alpine

WORKDIR /usr/src/app

# Copy package.json and package-lock.json first to optimize Docker cache
COPY package*.json ./

# Install backend dependencies
RUN npm install

# Copy all the remaining backend code
COPY . .

# Expose port 5000 for the Node.js API
EXPOSE 5000

# Start the server
CMD ["npm", "start"]
