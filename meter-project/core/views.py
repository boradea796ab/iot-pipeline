from django.http import JsonResponse
from django.views.decorators.http import require_GET
from core.tasks.hello import hello_world
from core.tasks.producer import simulate_readings_task
from core.models import Reading

# Optional: only if still used locally
# from .simulator import simulate_msgs


# ---------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------
def success(data=None, message="ok", status=200):
    return JsonResponse({"status": "success", "message": message, "data": data}, status=status)

def error(message="error", status=400):
    return JsonResponse({"status": "error", "message": message}, status=status)


# ---------------------------------------------------------------------
# 1️⃣ Celery test endpoint
# ---------------------------------------------------------------------
@require_GET
def celery_test(request):
    """Quick check to ensure Celery is connected and running."""
    try:
        result = hello_world.delay(1)
        return success({"task_id": result.id, "status": "submitted"})
    except Exception as e:
        return error(str(e))


# ---------------------------------------------------------------------
# 2️⃣ Simulation trigger endpoint
# ---------------------------------------------------------------------
@require_GET
def simulate(request):
    """
    Trigger a Celery task that simulates IoT readings.
    Query params:
      meters   – number of meters (default: 1000)
      interval – reading interval in minutes (default: 30)
      days     – days of data to simulate (default: 1)
      duration – total simulation time in seconds (default: 60)
    """
    try:
        meters = int(request.GET.get("meters", 1000))
        interval = int(request.GET.get("interval", 30))
        days = int(request.GET.get("days", 1))
        duration = int(request.GET.get("duration", 60))

        if meters <= 0 or interval <= 0 or days <= 0:
            return error("meters, interval, and days must be positive integers")

        result = simulate_readings_task.delay(
            num_meters=meters,
            interval_minutes=interval,
            days=days,
            duration_s=duration,
        )

        return success(
            {"task_id": result.id, "meters": meters, "interval": interval, "days": days, "duration": duration},
            message="simulation started",
        )
    except ValueError:
        return error("Invalid query parameter type")
    except Exception as e:
        return error(str(e))


# ---------------------------------------------------------------------
# 3️⃣ Diagnostic endpoint (optional)
# ---------------------------------------------------------------------
@require_GET
def simulate_hello(request):
    """Run a simple local simulator (used for quick load tests)."""
    num_calls = int(request.GET.get("calls", 1000))
    # simulate_msgs(num_calls=num_calls)  # Uncomment if simulator still used
    return success({"calls": num_calls}, message="started")


# ---------------------------------------------------------------------
# 4️⃣ Readings query endpoint
# ---------------------------------------------------------------------
@require_GET
def readings(request, meter_id):
    """Return the latest 100 readings for a given meter."""
    try:
        meter_id = int(meter_id)
        data = list(
            Reading.objects.filter(meter_id=meter_id)
            .order_by("-timestamp")[:100]
            .values("meter_id", "timestamp", "value")
        )
        return success(data)
    except ValueError:
        return error("meter_id must be an integer")
    except Exception as e:
        return error(str(e))
