'''wsgi

gunicorn --bind 0.0.0.0:8080 wsgi:app
'''
from qserve.rcompserver import app

if __name__ == "__main__":
    app.run()