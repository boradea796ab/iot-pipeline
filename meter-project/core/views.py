from django.shortcuts import render
from django.http import JsonResponse
from core.tasks import hello_world
from .simulator import simulate_readings, simulate_msgs
from .models import Reading

def celery_test(request):
    result = hello_world.delay()
    return JsonResponse({
        "task_id": result.id,
        "status": "submitted",
    })


def simulate(request):
    meters = int(request.GET.get("meters", 1000))
    interval = int(request.GET.get("interval", 30))
    days = int(request.GET.get("days", 1))
    
    simulate_readings(num_meters=meters, interval_minutes=interval, days=days)
    return JsonResponse({"status": "started", "meters": meters, "interval": interval})

def simulate_hello(request):
    num_calls = int(request.GET.get("calls", 1000))
    simulate_msgs(num_calls=num_calls)
    return JsonResponse({"status": "started", "calls": num_calls})


def readings(request, meter_id):
    data = list(
        Reading.objects.filter(meter_id=meter_id)
        .order_by("-timestamp")[:100]
        .values()
    )
    return JsonResponse(data, safe=False)
