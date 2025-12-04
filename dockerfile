# Multi-Stage Docker Build for Node.js TypeScript Application
# Stage 1: Build - Compile TypeScript to JavaScript
# Stage 2: Runtime - Run compiled code with minimal dependencies


# Build Stage - Compile TypeScript
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies 
RUN npm install

# Copy source code and compile
COPY . .
RUN npm run build

# Runtime Stage - Minimal production image
FROM node:20-alpine AS runner

WORKDIR /app

# Copy dependencies and compiled code from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

# Applistens on port 3000
EXPOSE 3000

# Run the compiled JavaScript
CMD ["node", "dist/index.js"]
