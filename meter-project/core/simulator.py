import random, datetime
from .tasks import ingest_reading

def simulate_readings(num_meters=1000, interval_minutes=30, days=1):
    now = datetime.datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    readings_per_meter = int((24*60*days)/interval_minutes)
    
    for meter_id in range(1, num_meters+1):
        for i in range(readings_per_meter):
            ts = now - datetime.timedelta(minutes=i*interval_minutes)
            value = round(random.uniform(0.1, 2.0), 3)
            ingest_reading.delay(meter_id, ts.isoformat(), value)
