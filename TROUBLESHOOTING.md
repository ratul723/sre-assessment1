1. # Slow home endpoint & wrong /healthz status

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
