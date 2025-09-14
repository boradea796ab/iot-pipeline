from django.shortcuts import render
from django.http import JsonResponse
from core.tasks import hello_world

def celery_test(request):
    result = hello_world.delay()
    return JsonResponse({
        "task_id": result.id,
        "status": "submitted",
    })
