from django.urls import path
from . import views

urlpatterns = [
    path("celery-test/", views.celery_test),
    path("simulate", views.simulate, name="simulate"),
    path("simulate_hello", views.simulate_hello, name="simulate_hello"),
]
