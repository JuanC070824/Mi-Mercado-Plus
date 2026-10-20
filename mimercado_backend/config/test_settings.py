import os
os.environ.setdefault('DJANGO_SECRET_KEY','solo-suite-de-pruebas-no-usar-en-servidor')
from .settings import *
DATABASES={'default':{'ENGINE':'django.db.backends.sqlite3','NAME':':memory:'}}
MVP_SQLITE_TESTS=True
PAYMENT_MODE='mock'
MOCK_YAPE_CODE='123456'
PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher']  # solo tests
TEST_RUNNER='mvp_back.test_runner.MvpTestRunner'
REST_FRAMEWORK={**REST_FRAMEWORK,'DEFAULT_THROTTLE_RATES':{'login':'10000/min','registro':'10000/min','dni':'10000/min','pago':'10000/min'}}
ALLOWED_HOSTS=['testserver','localhost','127.0.0.1']
