# Problem 1 report: Application fix

1.  # Summary

A Flask-based SRE test application experienced slow response times on the root (/) endpoint and returned an incorrect HTTP status code on the `/healthz` endpoint. Additionally, the Dockerfile used to containerize the application failed to build successfully and produced an unnecessarily large image. These issues affected reliability, observability, and deployment efficiency.

2.  # Impact

✔ Users experienced `3–8 second delays` when accessing the home page.
✔ Health checks were `returning HTTP 500`, causing:

- Failures in container orchestration health probes
- Premature restarts
- Deployment instability

✔ Docker image build failures blocked CI/CD pipeline.
✔ Inefficient Docker builds increased: - Build time - Storage usage - Deployment latency

3.  # Root Cause

✔ The home() function included an intentional time.sleep() delay (3–8 seconds), causing unnecessary latency.

✔ The `/healthz endpoint returned 500 instead of 200`, marking the app as unhealthy.

✔ The Dockerfile:

- Used incorrect COPY structure
- Installed requirements after copying all files
- Exposed the wrong port (80 instead of the app’s 8080)
- Lacked .dockerignore, leading to large builds
- Missed build optimizations

4.  # What I Fixed

✔ `Application Fixes`

- Removed artificial delay in home() endpoint.
- Corrected /healthz endpoint to return 200 OK.

✔ `Docker Fixes`

- Rewrote Dockerfile using multi-stage builds.
- Added .dockerignore to optimize build context.
- Corrected port exposure from 80 to 8080.
- Improved layer caching and reduced final image size significantly.
- Created a production-grade docker-compose.yml.
- Added a full CI/CD pipeline using GitHub Actions for automated builds and pushes.

5. # Preventive Actions

- Add automated tests to validate response codes and latency.
- Implement health-check & readiness-check validation in CI.
- Add linting and static code analysis to avoid future logic issues.
- Monitor latency using Prometheus + Grafana dashboards.
- Enable Docker image scanning (Trivy/GH Security) in the CI pipeline.
- Add code review steps before merging into main branch.
- Enable automated test environments to catch anomalies earlier.

#

#

# ---------------------------------------

#

#

# Problem-2: DDockerfile Build Failure & Application Runtime Issues

1. # Summary

The application Dockerfile failed to build and produced an inefficient container image due to misconfigured COPY statements, incorrect directory structure, and missing best practices. These issues prevented the application from running properly inside the container and caused delays in deployment.

2. # Impact

- The Docker image could not be built successfully, blocking all deployments.
- The application failed to start inside the container because files were not copied correctly.
- Build times increased due to inefficient layering and missing cache optimization.
- CI/CD pipeline experienced repeated failures.
- Developer productivity was reduced while debugging the build process.

3. # Root Cause

✔ Incorrect COPY Instructions
The previous Dockerfile attempted to copy code using:
`[ COPY app . ]`
The app/ directory structure did not match expectations during build, resulting in “file not found” errors and incomplete runtime files.

✔ `requirements.txt Not Copied` Before pip Install
Dependencies were installed after copying the entire codebase, causing:

- pip install to re-run unnecessarily
- build caching to break
- slower build times

✔ Missing Best Practice Optimizations

- No use of `--no-cache-dir`, causing larger image size.
- No clear working directory, leading to inconsistent file paths.
- Exposed port did not match the application’s actual runtime port.

✔ No Separation Between App Code and Dependency Stages

All code and dependencies were installed in the same layer, `reducing efficiency and repeatability`.

4. # What I Fixed
   ✔ Set a Clear Working Directory

`WORKDIR /app`

Ensures consistent file paths and predictable behavior.

✔ Corrected Dependency Installation Step
`COPY app/requirements.txt .`
`RUN pip install --no-cache-dir -r requirements.txt`

This allows Docker to cache dependency installation properly.

✔ Corrected Application Code Copy Operation
`COPY app/ .`

Ensured the entire codebase is present inside the container.

✔ Matched the Application Port

Updated:
`EXPOSE 8080`
to align with Flask or user-defined port.

✔ Improved Image Efficiency

- Added --no-cache-dir

- Reduced unnecessary build layers

- Organized Dockerfile into logical steps

- The final Dockerfile is now clean, repeatable, efficient, and production-ready.

5. # Preventive Actions
   `Short-term Actions`

- Use Docker build linter tools (Hadolint) to automatically detect mistakes.

- Add .dockerignore to exclude unnecessary files:

  venv/
  **pycache**/
  .git/
  logs

`Long-term Actions`

- Implement a standardized Dockerfile template for Python applications.
- Introduce CI checks that verify:
  - correct directory paths
  - required files exist before build
  - security scanning
- Use multi-stage Docker builds for production optimization.
- Document container build methodology in team handbook.

#

#

# ---------------------------------------

#

#

# Problem-3: Kubernetes Deployment Failure

1. # Summary

A Kubernetes Deployment for the sre-app application failed to become Ready due to misconfigured probe settings and missing/incorrect container configuration parameters. As a result, the pods remained in CrashLoopBackOff / NotReady state and the service could not route traffic to backend pods.

2. # Impact

- Application pods failed readiness checks and never transitioned to Ready state.
- Service endpoints list remained empty, causing application downtime.
- Deployment rollout stalled, preventing updates and auto-scaling actions.
- Users experienced failed connections and inaccessible application endpoints.

3. # Root Cause

The root cause was a combination of configuration issues in the Kubernetes Deployment manifest:

- Incorrect readinessProbe path

  - The probe used `path: /healthz`, which did not exist or was incorrectly spelled (/health).
  - `Readiness p-robe continuously failed`, preventing the pod from becoming ready.

- Missing/incorrect indentation under containers:
  - `YAML indentation inconsistencies` caused parsing issues during kubectl apply.
- Container image tag “latest”
  - Led to unpredictable behavior due to non-deterministic image version.
- No livenessProbe configured
  - Application failures couldn’t be auto-recovered.

4. # What I Fixed

✔ Corrected readinessProbe

- Updated the probe to the proper health endpoint exposed by the application.

✔ Fixed YAML indentation & structure

- Ensured that `containers:`, `ports:`, and `readinessProbe:` were properly aligned.

✔ Replaced `latest` tag with a versioned image

- Improved deterministic builds and rollouts.

✔ Added a livenessProbe `Bonus`

- Allowed auto-restart of unhealthy containers to maintain uptime.

✔ Verified deployment with kubectl commands

- `kubectl apply -f deployment.yaml`
- `kubectl describe deployment sre-app`
- `kubectl get pods -w`
- Ensured pods transitioned to Running and Ready states.

5. # Preventive Actions
   `Short-term`

- Implement YAML schema validation using tools like:

  - `kubectl apply --dry-run=client -f file.yaml`
  - `kubeval`
  - VSCode Kubernetes extension

- Enforce health endpoint consistency across services.

`Long-term`

- Adopt GitOps `(ArgoCD / FluxCD)` to ensure configuration correctness.

- Enforce version-pinned container images in CI/CD pipeline.

- Implement automated Kubernetes manifest linting using:

  - kube-linter

  - Datree

- Add monitoring & alerting for failing probes `using Prometheus + Alertmanager`.
