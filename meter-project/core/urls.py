from django.urls import path
from . import views

urlpatterns = [
    path("celery-test/", views.celery_test),
    path("simulate", views.simulate, name="simulate"),
]
