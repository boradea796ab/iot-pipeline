from django.db import models

class Reading(models.Model):
    meter_id = models.IntegerField()
    timestamp = models.DateTimeField()
    value = models.FloatField()

    class Meta:
        indexes = [
            models.Index(fields=["meter_id", "timestamp"]),
        ]
