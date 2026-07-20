from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "<h1>Welcome to Python Flask!</h1><p>This is a simple Flask application running in DevBox.</p>"

@app.route("/about")
def about():
    return "<h1>About</h1><p>This is a test Flask application.</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
