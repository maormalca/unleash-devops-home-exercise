
# Use a multi-stage build to separate the compilation environment from the runtime environment.

# BUILD STAGE

FROM node:20-alpine AS builder

# Set the working directory inside the container image
WORKDIR /app

# Copy dependency files 
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies 
RUN npm install

# Copy all source code files
COPY . .

# Run the TypeScript compilation step
RUN npm run build


# RUNTIME STAGE

FROM node:20-alpine AS runner

# working directory
WORKDIR /app

# Copy runtime node_modules from the builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy the compiled JavaScript code from the 'dist' directory of the builder stage
COPY --from=builder /app/dist ./dist

# Expose listen default port
EXPOSE 3000

#run the application
CMD ["node", "dist/index.js"]