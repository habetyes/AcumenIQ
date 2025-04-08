# Stage 1: Base - Install dependencies and copy source
FROM node:16 AS base
WORKDIR /app
# Copy package manifest and install dependencies
COPY package*.json ./
RUN npm install
# Copy the rest of your application source
COPY . .

# Stage 2: Development - use the base image and run the dev server
FROM base AS development
ENV NODE_ENV=development
EXPOSE 3000
# In development we mount volumes from the host so a rebuild isn’t necessary.
CMD ["npm", "start"]

# Stage 3: Build - create production assets
FROM base AS build
# Pass in environment variables to be embedded into the build
ARG REACT_APP_SUPABASE_URL
ARG REACT_APP_SUPABASE_ANON_KEY
ENV REACT_APP_SUPABASE_URL=$REACT_APP_SUPABASE_URL
ENV REACT_APP_SUPABASE_ANON_KEY=$REACT_APP_SUPABASE_ANON_KEY
# Build the React app — output will be in the /app/build directory
RUN npm run build

# Stage 4: Production - serve static files with Nginx
FROM nginx:alpine AS production
# Optionally, if you have a custom nginx configuration you could uncomment the line below:
# COPY nginx.conf /etc/nginx/nginx.conf
# Copy the built static files from the 'build' stage to Nginx's default directory
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
