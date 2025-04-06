# Use an official Node runtime as a parent image
FROM node:16-alpine

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install

# Copy the rest of the app source code
COPY . .

# Expose port 3000 for the React app
EXPOSE 3000

# Start the app (hot reloading enabled)
CMD ["npm", "start"]
