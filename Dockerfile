FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Install all the dependencies  
COPY app/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy application code here
COPY app/ .

# Match Flask port 
EXPOSE 8080

CMD ["python", "main.py"]


