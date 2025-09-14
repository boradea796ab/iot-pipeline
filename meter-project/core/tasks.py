from celery import shared_task

@shared_task
def hello_world():
    return "Hello from Celery!"
