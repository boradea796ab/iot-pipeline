from .tasks import hello_world

def simulate_msgs(num_calls=1000):
    for i in range(num_calls):
        hello_world.delay(i)