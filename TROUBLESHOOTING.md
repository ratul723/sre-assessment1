**1. # Slow home endpoint & wrong /healthz status**

# Steps I followed \*\*\*

- Inspect the Flask app source to find where delay and status are set.
- Reproduce the behavior locally by running the app and calling the endpoints.
- Remove the artificial delay and fix the /healthz return code.
- Re-run the app and re-test endpoints to confirm fixes.

# Commands I ran \*\*\*

# run the app locally (from project root)

`python main.py`

# from another terminal: test endpoints

`curl -i http://localhost:8080/` # expect: "Hello from SRE Test!" quickly
`curl -i http://localhost:8080/healthz` # expect: HTTP/1.1 200 and {"status":"ok"}

# What I changed (code snippets)

Removed: `time.sleep(random.randint(3,8)) from home()`

Changed: `return jsonify({"status":"ok"}), 500 → return jsonify({"status":"ok"}), 200`

# What I learned \*\*\*

- Artificial sleeps in app code directly translate into real user-visible latency and can break readiness checks.

- Health endpoints must return appropriate HTTP status codes; a mismatched body + status (e.g., "ok" with 500) will confuse orchestrators and monitoring.


----------------------------

**# 2 Dockerfile Issue -- Flask Not Installed**

### Step-by-Step Process Followed

1.  Observed that `Flask` was not installed inside the container even
    though it was listed in `requirements.txt`.
2.  Checked the Dockerfile and noticed that `requirements.txt` was
    copied to the wrong path.
3.  Verified that the working directory inside the container is `/app`,
    but the Dockerfile copied the file to `/`.
4.  Corrected the Dockerfile to copy `requirements.txt` to `/app` before
    running `pip install`.
5.  Rebuilt the image and validated that Flask installed correctly.

### Commands Run

``` bash
docker build -t sre-app .
docker run -p 8080:8080 sre-app
docker exec -it <container_id> pip list
```

### What I Learned

-   In Python official Docker images, `pip` = `pip3` and `python` =
    `python3`.
-   The order of COPY and RUN instructions in Dockerfile affects the
    build.
-   Requirements must be copied **before** running `pip install`.
-   The working directory (`WORKDIR`) determines file paths inside the
    container.

-------------------------

**# 3. Kubernetes Issue -- Readiness Probe Failures & Service Slowness**

### Step-by-Step Process Followed

1.  Observed repeated readiness probe failures in pods.
2.  Checked pod logs and noticed delays in the `/healthz` response.
3.  Verified deployment configuration and identified increased latency
    caused by simulated delays.
4.  Checked service response times using `kubectl port-forward` and
    curl.
5.  Updated readinessProbe configuration and rebuilt the Docker image
    after fixing the root cause.
6.  Redeployed and validated stable pod readiness and improved
    performance.

### Commands Run

``` bash
kubectl get pods
kubectl describe pod <pod_name>
kubectl logs <pod_name>
kubectl port-forward <pod_name> 8080:8080
curl http://localhost:8080/healthz
kubectl apply -f deployment.yaml
```

### What I Learned

-   Readiness probes fail when the application takes longer than the
    probe timeout.
-   Even minor delays in application logic can break Kubernetes health
    checks.
-   Slow services affect the load balancer, making traffic routing
    unstable.
-   Proper probe configuration and optimized app logic are crucial for
    production stability.


**# 4. Debug logs.txt**

***1. What caused the readiness probe failures?

The readiness probe failed because the container was exposing and running the application on port 8080, but the Kubernetes configuration was checking the /healthz endpoint on port 80.
This mismatch caused Kubernetes to assume the application was not ready, even though it was running correctly.

# Additionally:

- The /healthz endpoint originally returned HTTP 500 instead of 200, causing probe failures.
- The app startup delay (3–8 seconds) also caused probes to fail before the app became ready.

------------------------------------------------

***2. Why is the service slow?

The service was slow because the home ("/") endpoint intentionally introduced a random sleep delay:

`time.sleep(random.randint(3, 8))`

This meant every request took 3–8 seconds to respond, making the app appear slow or unresponsive from Kubernetes or a browser.

------------------------------------------------
3. What is the probable root cause?

The overall root cause combines three misconfigurations and one code issue:

A. Code issue
- The random sleep delay caused the application to feel slow and made probes more likely to fail.

B. Port mismatch
- `The application listened on 8080, but Kubernetes expected it on 80.`

C. Readiness probe misconfiguration
- Probe sent requests to the wrong port.
- Probe path /healthz returned HTTP 500 in the original code.

D. Inefficient Dockerfile

- Incorrect file copying caused inconsistent builds.
- Missing best practices resulted in slow startup and deployment failures.

All these combined to cause:
- readiness failures
- slow service response
- application not routing properly

------------------------------------------------

4. What permanent fix would resolve it?
A. Fix the application code

✔ Remove artificial sleep delay or reduce it
✔ Change /healthz to return 200 OK

B. Fix the readiness probe
Ensure probe matches the app's actual port:
========
readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
=======
C. Fix the Kubernetes Service

Match targetPort with container port:
***
ports:
- port: 80
  targetPort: 8080
***
D. Fix the Dockerfile (permanent improvement)

- Copy requirements.txt first
- Optimize layers
- Use correct working directory
- Install dependencies cleanly

E. Add proper health checks

Add both readiness and liveness probes so:
- readiness → controls traffic
- liveness → restarts crashed/hung containers
