import Foundation

public struct SampleYAMLItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let fileName: String
    public let content: String
}

public enum SampleYAML {
    public static let samples: [SampleYAMLItem] = [
        SampleYAMLItem(
            title: "Kubernetes Deployment & Service",
            fileName: "deployment.yaml",
            content: """
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: web-app-deployment
              namespace: production
              labels:
                app.kubernetes.io/name: web-app
                app.kubernetes.io/version: 2.4.0
            spec:
              replicas: 3
              strategy:
                type: RollingUpdate
                rollingUpdate:
                  maxSurge: 1
                  maxUnavailable: 0
              selector:
                matchLabels:
                  app: web-app
              template:
                metadata:
                  labels:
                    app: web-app
                spec:
                  containers:
                  - name: web
                    image: nginx:1.25.3-alpine
                    ports:
                    - name: http
                      containerPort: 80
                    env:
                    - name: ENVIRONMENT
                      value: "production"
                    - name: PORT
                      value: "8080"
                    resources:
                      limits:
                        cpu: "500m"
                        memory: "256Mi"
                      requests:
                        cpu: "100m"
                        memory: "64Mi"
                    readinessProbe:
                      httpGet:
                        path: /healthz
                        port: 80
                      initialDelaySeconds: 5
                      periodSeconds: 10
            ---
            apiVersion: v1
            kind: Service
            metadata:
              name: web-app-service
              namespace: production
            spec:
              type: LoadBalancer
              selector:
                app: web-app
              ports:
              - port: 80
                targetPort: 80
                protocol: TCP
            """
        ),
        SampleYAMLItem(
            title: "Docker Compose",
            fileName: "docker-compose.yml",
            content: """
            version: '3.8'

            services:
              api:
                build:
                  context: .
                  dockerfile: Dockerfile
                ports:
                  - "8080:8080"
                environment:
                  - NODE_ENV=production
                  - DB_HOST=postgres
                  - DB_PORT=5432
                  - DB_NAME=app_db
                  - DB_USER=postgres
                  - DB_PASSWORD=example_db_password
                depends_on:
                  postgres:
                    condition: service_healthy
                  redis:
                    condition: service_started
                restart: always

              postgres:
                image: postgres:16-alpine
                environment:
                  POSTGRES_DB: app_db
                  POSTGRES_PASSWORD: example_db_password
                volumes:
                  - pgdata:/var/lib/postgresql/data
                healthcheck:
                  test: ["CMD-SHELL", "pg_isready -U postgres"]
                  interval: 5s
                  timeout: 5s
                  retries: 5

              redis:
                image: redis:7.2-alpine
                ports:
                  - "6379:6379"

            volumes:
              pgdata:
                driver: local
            """
        ),
        SampleYAMLItem(
            title: "Anchors & Complex Types",
            fileName: "config-anchors.yaml",
            content: """
            # Common environment configuration using anchors
            default_config: &defaults
              timeout: 30
              retry_attempts: 3
              logging:
                level: "INFO"
                format: "json"
              security:
                ssl_enabled: true
                verify_peer: true

            development:
              <<: *defaults
              host: "localhost"
              port: 3000
              debug: true
              logging:
                level: "DEBUG"

            staging:
              <<: *defaults
              host: "staging.api.example.com"
              port: 443
              debug: false

            production:
              <<: *defaults
              host: "api.example.com"
              port: 443
              timeout: 60
              debug: false
            """
        ),
        SampleYAMLItem(
            title: "YAML with Syntax Error",
            fileName: "error-sample.yaml",
            content: """
            server:
              host: localhost
              port: 8080
            \t# Error: Tab character used for indentation below!
            \tchild_service: broken
              timeout: 50
              duplicate_key: first
              duplicate_key: second
            """
        )
    ]
}
